<#
  SisCMJ - levantamento do servidor antes da instalacao (SO LEITURA: nao muda nada)
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (28/11/2026) - Criacao (etapa P28a), no lugar do questionario do tecnico.
  v1.1 (28/11/2026) - Ensaio no notebook: suspensao lida pelo valor (Windows em portugues),
                      DHCP so nas placas ligadas (com gateway), listas de programas e
                      tarefas so com o que interessa.
  Roda pelo levantamento_servidor.cmd, COMO ADMINISTRADOR (BitLocker e SQL pedem).
  Grava levantamento_<computador>_<data>.txt na mesma pasta: mandar o arquivo para o Claude.
  Confere: Windows, energia, discos e BitLocker, rede (IP fixo, perfil Privada/Publica,
  nome achado), firewall, SQL Server e instancias, .NET 10 (Hosting Bundle), sqlcmd,
  saida HTTPS (viacep, brasilapi) e SMTP 587 (smtp.gmail.com), Google Drive,
  acesso remoto (AnyViewer/AnyDesk), antivirus, porta 5443 livre, Windows Update.
  Nenhuma senha e lida nem gravada.
  -PastaSaida: onde gravar o .txt (padrao: a pasta do script; o executor usa a saida dele).
#>
param([string]$PastaSaida = '')
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Pasta   = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($PastaSaida) { $Pasta = $PastaSaida }
$Arquivo = Join-Path $Pasta ('levantamento_' + $env:COMPUTERNAME + '_' + (Get-Date -Format 'yyyyMMdd_HHmm') + '.txt')
$Linhas  = New-Object System.Collections.Generic.List[string]
$Alertas = New-Object System.Collections.Generic.List[string]

function Escrever([string]$Texto) { $Linhas.Add($Texto); Write-Host $Texto }
function Titulo([string]$Texto) { Escrever ''; Escrever ('==== ' + $Texto + ' ====') }
function Alertar([string]$Texto) { $Alertas.Add($Texto); Escrever ('  [ATENCAO] ' + $Texto) }
function Bloco([string]$Nome, [scriptblock]$Acao) {
    Titulo $Nome
    try { & $Acao } catch { Escrever ('  (erro ao conferir: ' + $_.Exception.Message + ')') }
}

Escrever ('SisCMJ - levantamento do servidor v1.1 - ' + (Get-Date -Format 'dd/MM/yyyy HH:mm'))
Escrever ('Computador: ' + $env:COMPUTERNAME + '   Usuario: ' + $env:USERDOMAIN + '\' + $env:USERNAME)
$Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Escrever ('Rodando como administrador: ' + $Admin)
if (-not $Admin) { Alertar 'Nao esta como administrador: BitLocker e SQL podem ficar sem resposta.' }

Bloco 'Windows' {
    $So = Get-CimInstance Win32_OperatingSystem
    $Cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    Escrever ('  ' + $So.Caption + ' | versao ' + $Cv.DisplayVersion + ' | build ' + $Cv.CurrentBuild + '.' + $Cv.UBR + ' | ' + $So.OSArchitecture)
    Escrever ('  Ligado desde: ' + $So.LastBootUpTime + '   Memoria: ' + [math]::Round($So.TotalVisibleMemorySize / 1MB, 1) + ' GB')
    $Cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    Escrever ('  Processador: ' + $Cpu.Name.Trim())
    if ($So.Caption -match 'Home') { Alertar 'Windows Home: conferir (o roteiro pede Pro).' }
    $Cs = Get-CimInstance Win32_ComputerSystem
    Escrever ('  Dominio/grupo de trabalho: ' + $Cs.Domain + ' (no dominio: ' + $Cs.PartOfDomain + ')')
    $Hf = Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 1
    if ($Hf) { Escrever ('  Ultima atualizacao instalada: ' + $Hf.HotFixID + ' em ' + $Hf.InstalledOn) }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { Alertar 'Windows pede reinicio para terminar atualizacao.' }
}

Bloco 'Energia (nunca suspender nem hibernar)' {
    $Plano = (powercfg /getactivescheme) -join ' '
    Escrever ('  ' + $Plano.Trim())
    $Q = powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE
    $Hex = @($Q | Select-String ':\s*0x[0-9a-fA-F]{8}\s*$')
    if ($Hex.Count -ge 2) {
        $Seg = [Convert]::ToInt32((($Hex[$Hex.Count - 2].ToString() -split ':')[-1].Trim()), 16)
        Escrever ('  Suspender na tomada depois de: ' + $(if ($Seg -eq 0) { 'nunca' } else { [string]($Seg / 60) + ' minutos' }))
        if ($Seg -ne 0) { Alertar 'O servidor suspende sozinho: mudar para Nunca (item 2 do roteiro).' }
    } else { Escrever '  (nao consegui ler o tempo de suspensao; conferir na mao em Configuracoes > Sistema > Energia)' }
    $Hib = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name HibernateEnabled -ErrorAction SilentlyContinue
    if ($Hib) { Escrever ('  Hibernacao habilitada: ' + [bool]$Hib.HibernateEnabled) }
}

Bloco 'Discos' {
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        Escrever ('  ' + $_.DeviceID + ' "' + $_.VolumeName + '" ' + $_.FileSystem + ' | total ' + [math]::Round($_.Size / 1GB) + ' GB | livre ' + [math]::Round($_.FreeSpace / 1GB) + ' GB')
        if ($_.FreeSpace -lt 30GB) { Alertar ('Pouco espaco livre em ' + $_.DeviceID) }
    }
    Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
        Escrever ('  Disco fisico: ' + $_.FriendlyName + ' | ' + $_.MediaType + ' | ' + [math]::Round($_.Size / 1GB) + ' GB | saude ' + $_.HealthStatus)
        if ($_.HealthStatus -ne 'Healthy') { Alertar ('Disco com saude ' + $_.HealthStatus + ': ' + $_.FriendlyName) }
    }
    if (-not (Test-Path 'D:\')) { Alertar 'Nao existe D: (pasta de backup prevista D:\SisCMJ_Backup): ver a letra do HD.' }
}

Bloco 'BitLocker (chave guardada junto com a da licenca)' {
    $Vol = Get-BitLockerVolume -ErrorAction Stop
    $Vol | ForEach-Object {
        Escrever ('  ' + $_.MountPoint + ' protecao ' + $_.ProtectionStatus + ' | ' + $_.VolumeStatus + ' | ' + [string]$_.EncryptionPercentage + '%')
        if ($_.ProtectionStatus -eq 'On') { Alertar ('BitLocker ligado em ' + $_.MountPoint + ': guardar a chave de recuperacao (regra de ouro 3). A chave NAO e gravada aqui.') }
    }
}

Bloco 'Rede' {
    Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address } | ForEach-Object {
        $Ip = $_.IPv4Address | Select-Object -First 1
        $Dhcp = (Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).Dhcp
        Escrever ('  ' + $_.InterfaceAlias + ': ' + $Ip.IPAddress + '/' + $Ip.PrefixLength + ' | gateway ' + (($_.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join ',') + ' | DNS ' + (($_.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | ForEach-Object { $_.ServerAddresses }) -join ','))
        Escrever ('    DHCP: ' + $Dhcp + $(if ($Dhcp -eq 'Enabled') { ' (IP pode mudar, a menos que haja reserva no roteador)' } else { ' (IP fixo no Windows)' }))
        if ($Dhcp -eq 'Enabled' -and $_.IPv4DefaultGateway -and $Ip.IPAddress -notlike '169.254.*') { Alertar ('IP por DHCP em ' + $_.InterfaceAlias + ': fixar o IP ou confirmar reserva no roteador.') }
    }
    Get-NetConnectionProfile -ErrorAction SilentlyContinue | ForEach-Object {
        Escrever ('  Perfil: ' + $_.InterfaceAlias + ' = ' + $_.NetworkCategory + ' (rede "' + $_.Name + '")')
        if ($_.NetworkCategory -eq 'Public') { Alertar ('Rede ' + $_.InterfaceAlias + ' esta Publica: mudar para Privada.') }
    }
    $Ping = Test-Connection -ComputerName $env:COMPUTERNAME -Count 1 -ErrorAction SilentlyContinue
    Escrever ('  O proprio nome responde neste computador: ' + [bool]$Ping + ' (o teste que vale e o ping de OUTRO computador)')
}

Bloco 'Firewall' {
    Get-NetFirewallProfile | ForEach-Object { Escrever ('  ' + $_.Name + ': ligado ' + $_.Enabled + ' | entrada padrao ' + $_.DefaultInboundAction) }
    $Reg = Get-NetFirewallRule -DisplayName '*SisCMJ*' -ErrorAction SilentlyContinue
    Escrever ('  Regras SisCMJ ja existentes: ' + @($Reg).Count)
    $Uso = Get-NetTCPConnection -LocalPort 5443, 5444 -State Listen -ErrorAction SilentlyContinue
    if ($Uso) { Alertar ('Porta 5443/5444 ja em uso pelo processo ' + (($Uso | ForEach-Object { (Get-Process -Id $_.OwningProcess).ProcessName }) -join ',')) } else { Escrever '  Portas 5443 e 5444: livres' }
}

Bloco 'SQL Server' {
    $Inst = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction SilentlyContinue
    if ($Inst) {
        $Inst.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
            $Setup = Get-ItemProperty ('HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\' + $_.Value + '\Setup') -ErrorAction SilentlyContinue
            Escrever ('  Instancia ' + $_.Name + ' (ID ' + $_.Value + ') | ' + $Setup.Edition + ' | versao ' + $Setup.Version + ' | collation ' + $Setup.Collation)
        }
    } else { Escrever '  Nenhuma instancia de SQL Server instalada (instalar o 2025 Express, item 3).' }
    Get-Service -Name 'MSSQL*', 'SQLAgent*', 'SQLBrowser' -ErrorAction SilentlyContinue | ForEach-Object { Escrever ('  Servico ' + $_.Name + ': ' + $_.Status + ' / ' + $_.StartType) }
    $Ssms = Get-ChildItem 'C:\Program Files*\Microsoft SQL Server Management Studio*\*\Common7\IDE\Ssms.exe', 'C:\Program Files*\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    Escrever ('  SSMS: ' + $(if ($Ssms) { $Ssms.FullName + ' ' + $Ssms.VersionInfo.ProductVersion } else { 'nao encontrado' }))
    $Sc = Get-Command sqlcmd.exe -ErrorAction SilentlyContinue
    Escrever ('  sqlcmd: ' + $(if ($Sc) { $Sc.Source } else { 'nao encontrado' }))
    if (-not $Sc) { Alertar 'sqlcmd nao encontrado: o atualizar.cmd precisa dele (instalar ou levar em ferramentas\sqlcmd.exe).' }
}

Bloco '.NET' {
    $Dn = Get-Command dotnet.exe -ErrorAction SilentlyContinue
    if ($Dn) { (& dotnet --list-runtimes) | Where-Object { $_ -match 'AspNetCore' } | ForEach-Object { Escrever ('  ' + $_) } } else { Escrever '  dotnet nao encontrado' }
    $Hb = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
          ForEach-Object { $_.DisplayName } | Where-Object { $_ -match 'Hosting Bundle|ASP\.NET Core.*Runtime' } | Sort-Object -Unique
    $Hb | ForEach-Object { Escrever ('  Instalado: ' + $_) }
    if (-not ($Dn -and ((& dotnet --list-runtimes) -match 'AspNetCore\.App 10\.'))) { Alertar 'ASP.NET Core 10 (Hosting Bundle) ainda nao instalado (item 3).' }
}

Bloco 'Saida para a internet (HTTPS e SMTP)' {
    foreach ($Url in 'https://viacep.com.br/ws/37701000/json/', 'https://brasilapi.com.br/api/cep/v1/37701000') {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $R = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 15
            Escrever ('  ' + $Url + ' -> HTTP ' + $R.StatusCode)
        } catch {
            $Cod = & curl.exe -s -o NUL -w '%{http_code}' --max-time 15 $Url 2>$null
            if ($Cod -eq '200') { Escrever ('  ' + $Url + ' -> HTTP 200 (pelo curl.exe)') }
            else { Alertar ('Sem resposta de ' + $Url + ': ' + $_.Exception.Message) }
        }
    }
    $T = Test-NetConnection -ComputerName smtp.gmail.com -Port 587 -WarningAction SilentlyContinue
    Escrever ('  smtp.gmail.com:587 -> ' + $(if ($T.TcpTestSucceeded) { 'aberto' } else { 'BLOQUEADO' }))
    if (-not $T.TcpTestSucceeded) { Alertar 'Saida na porta 587 bloqueada: o e-mail do sistema nao sai (falar com o tecnico).' }
}

Bloco 'Google Drive (copia do backup)' {
    $Gd = Get-Process -Name 'GoogleDriveFS' -ErrorAction SilentlyContinue
    Escrever ('  Google Drive para computador rodando: ' + [bool]$Gd)
    Get-PSDrive -PSProvider FileSystem | Where-Object { (Test-Path ($_.Root + 'Meu Drive')) -or (Test-Path ($_.Root + 'My Drive')) } | ForEach-Object { Escrever ('  Unidade do Drive: ' + $_.Root) }
    $Tarefas = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notlike '\Microsoft\*' -and $_.TaskName -match 'Drive|Backup|Sync|SisCMJ|SistemaCMJ' }
    $Tarefas | ForEach-Object { Escrever ('  Tarefa agendada: ' + $_.TaskPath + $_.TaskName + ' (' + $_.State + ')') }
}

Bloco 'Acesso remoto, antivirus e outros programas' {
    $Nomes = '^(AnyViewer|AnyDesk|RustDesk|TeamViewer|Chrome Remote|Google Drive|Microsoft Access|Microsoft Office|Microsoft 365|LibreOffice|Kaspersky|Avast|AVG|ESET|Norton|McAfee|Bitdefender|Sophos|PowerChute|SMS|Ragtech|Intelbras|APC)'
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match $Nomes } | Sort-Object DisplayName -Unique | ForEach-Object { Escrever ('  ' + $_.DisplayName + ' ' + $_.DisplayVersion) }
    $Av = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
    $Av | ForEach-Object { Escrever ('  Antivirus registrado: ' + $_.displayName) }
    if (@($Av | Where-Object { $_.displayName -notmatch 'Defender' }).Count -gt 0) { Alertar 'Ha antivirus alem do Defender: excluir as pastas do banco e do backup da varredura (item 2).' }
}

Titulo 'RESUMO'
if ($Alertas.Count -eq 0) { Escrever '  Nenhum ponto de atencao encontrado.' } else { $Alertas | ForEach-Object { Escrever ('  - ' + $_) } }
Escrever ''
Escrever 'Conferir na mao (o script nao consegue): ping do nome do servidor a partir de OUTRO computador; nobreak ligado ao servidor.'

[System.IO.File]::WriteAllLines($Arquivo, $Linhas, [System.Text.UTF8Encoding]::new($true))
Write-Host ''
Write-Host ('Arquivo gravado: ' + $Arquivo)

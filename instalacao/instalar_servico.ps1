<#
  SisCMJ - instala (ou atualiza) o sistema no servidor como servico do Windows
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (20/11/2026) - Criacao (etapa 03d). Roda pelo instalar_servico.cmd, COMO ADMINISTRADOR,
                      de dentro da pasta gerada pelo api\publicar.cmd.
  v1.1 (20/11/2026) - Conferencia final com TLS 1.2 (ensaio: o PS 5.1 nao conectava).
  v1.2 (20/11/2026) - Mostra o codigo do servidor para a licenca (codigo_servidor.txt).
  v1.4 (20/11/2026) - Conferencia final pelo curl.exe (ensaio: Invoke-WebRequest do PS 5.1 falhava).
  v1.3 (20/11/2026) - Passo 10: backup (completo diario, log de hora em hora, teste semanal),
                      tarefas como SYSTEM; roda o 1o completo e o 1o teste na hora.
  Faz, nesta ordem (pode rodar de novo: atualiza sem perder nada):
    1) confere administrador e o .NET 10 (ASP.NET Core Runtime / Hosting Bundle);
    2) para o servico (se ja existe) e copia o programa para -PastaPrograma;
    3) cria o servico (inicio automatico atrasado, conta virtual "NT SERVICE\<Nome>",
       reinicia sozinho se cair);
    4) permissoes: pasta do programa so leitura para o servico; configuracao em
       %ProgramData%\SisCMJ so para administradores e o servico; registro e
       arquivos do sistema com gravacao para o servico;
    5) configuracao do servidor (%ProgramData%\SisCMJ\appsettings.Servidor.json), so se
       ainda nao existe: conexao com o banco pela conta do servico (sem senha), porta;
    6) login do servico no SQL Server (Windows, sem senha) no papel rl_sistemacmj_api;
    7) certificado HTTPS autoassinado (5 anos) no repositorio do Windows, com leitura
       para o servico; copia publica (.cer) para os computadores dos usuarios;
    8) regra do Firewall so para a porta do sistema e so para as redes permitidas;
    9) inicia o servico e confere /api/saude.
  Nada de senha fica em arquivo. O e-mail (SMTP) e preenchido depois no arquivo de
  configuracao do servidor.
#>
param(
    [string]$NomeServico    = 'SisCMJ',
    [string]$PastaPrograma  = 'C:\SisCMJ\programa',
    [string]$PastaArquivos  = 'C:\SistemaCMJ_Arquivos',
    [string]$Instancia      = '.\SQL2025',
    [string]$Banco          = 'SISTEMACMJ',
    [int]$Porta             = 5443,
    [string[]]$RedesPermitidas = @('LocalSubnet'),
    [string[]]$NomesExtras  = @(),
    [string]$HoraBackupCompleto = '23:00'
)
$ErrorActionPreference = 'Stop'
# Pelo .cmd (-File), listas chegam como um texto so: separa nas virgulas
$RedesPermitidas = @($RedesPermitidas | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$NomesExtras = @($NomesExtras | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Pacote = Split-Path $PSScriptRoot -Parent
$Origem = Join-Path $Pacote 'programa'
$PastaConfig = Join-Path $env:ProgramData 'SisCMJ'
$ArquivoConfig = Join-Path $PastaConfig 'appsettings.Servidor.json'
$Conta = 'NT SERVICE\' + $NomeServico
$Exe = Join-Path $PastaPrograma 'SistemaCMJ.Api.exe'
$Log = Join-Path $PSScriptRoot ('instalacao_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
Start-Transcript -LiteralPath $Log | Out-Null

function Passo([string]$Texto) { Write-Host ''; Write-Host ('=== ' + $Texto) -ForegroundColor Cyan }
function Sql([string]$BancoSql, [string]$Comando) {
    $Con = New-Object System.Data.SqlClient.SqlConnection("Server=$Instancia;Database=$BancoSql;Integrated Security=SSPI;Application Name=SisCMJ instalador")
    $Con.Open()
    try { $C = $Con.CreateCommand(); $C.CommandText = $Comando; $C.CommandTimeout = 120; return $C.ExecuteScalar() } finally { $Con.Close() }
}

try {
    Passo '1/10 Conferencias'
    $Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $Admin) { throw 'Rode como administrador (botao direito no instalar_servico.cmd > Executar como administrador).' }
    if (-not (Test-Path -LiteralPath (Join-Path $Origem 'SistemaCMJ.Api.exe'))) { throw ('Nao achei o programa em ' + $Origem + '. Rode este instalador de dentro da pasta gerada pelo publicar.cmd.') }
    $Runtimes = (& dotnet --list-runtimes 2>$null) -join "`n"
    if ($Runtimes -notmatch 'Microsoft\.AspNetCore\.App 10\.') { throw 'Falta o .NET 10 (ASP.NET Core Runtime). Instale o ".NET 10 Hosting Bundle" e rode de novo.' }
    $Existe = [bool](Get-Service -Name $NomeServico -ErrorAction SilentlyContinue)
    Write-Host ('Servico ' + $NomeServico + ': ' + $(if ($Existe) { 'ja existe (atualizacao)' } else { 'novo' }))
    $CodigoServidor = ([string](Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid).MachineGuid).Trim().ToUpper()
    Write-Host ('Codigo deste servidor (para a licenca): ' + $CodigoServidor)
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'codigo_servidor.txt'), ($env:COMPUTERNAME + ': ' + $CodigoServidor + "`r`n"), (New-Object System.Text.ASCIIEncoding))
    $Versao = [string](Sql $Banco "SELECT SIS.fn_SIS_Versao_Banco()")
    Write-Host ('Banco ' + $Instancia + '/' + $Banco + ': versao ' + $(if ($Versao) { $Versao } else { '(sem versao: rode o MASTER antes)' }))
    if (-not $Versao) { throw 'Rode antes o SISTEMACMJ_00_Criar_Banco.sql e o SISTEMACMJ_MASTER_Instalacao.sql no SSMS.' }

    Passo '2/10 Programa'
    if ($Existe) { Stop-Service -Name $NomeServico -Force; (Get-Service $NomeServico).WaitForStatus('Stopped', (New-TimeSpan -Seconds 60)) }
    New-Item -ItemType Directory -Force -Path $PastaPrograma | Out-Null
    & robocopy $Origem $PastaPrograma /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw ('Falha ao copiar o programa (robocopy ' + $LASTEXITCODE + ').') }
    Write-Host ('Copiado para ' + $PastaPrograma)

    Passo '3/10 Servico do Windows'
    if (-not $Existe) {
        & sc.exe create $NomeServico binPath= ('"' + $Exe + '"') start= delayed-auto obj= $Conta DisplayName= 'SisCMJ - Sistema da construtora' | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o servico.' }
    } else {
        & sc.exe config $NomeServico binPath= ('"' + $Exe + '"') start= delayed-auto obj= $Conta | Out-Host
    }
    & sc.exe description $NomeServico 'SisCMJ: telas, API, rotinas agendadas e e-mails do sistema.' | Out-Null
    & sc.exe failure $NomeServico reset= 86400 actions= restart/60000/restart/60000/restart/300000 | Out-Null

    Passo '4/10 Permissoes das pastas'
    & icacls $PastaPrograma /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' ($Conta + ':(OI)(CI)RX') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $PastaConfig 'logs') | Out-Null
    & icacls $PastaConfig /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' ($Conta + ':(OI)(CI)RX') | Out-Null
    & icacls (Join-Path $PastaConfig 'logs') /grant ($Conta + ':(OI)(CI)M') | Out-Null
    foreach ($Sub in @('Anexos', 'Backup', 'Atualizacoes', 'Identidade', 'Remessa', 'Retorno', 'OFX')) { New-Item -ItemType Directory -Force -Path (Join-Path $PastaArquivos $Sub) | Out-Null }
    & icacls $PastaArquivos /grant ($Conta + ':(OI)(CI)M') | Out-Null
    # Logomarcas da empresa (parametro IDENTIDADE_PASTA = <PastaArquivos>\Identidade): copia so as que faltam
    $Logos = Join-Path $Pacote 'identidade'
    if (Test-Path -LiteralPath $Logos) {
        Get-ChildItem -LiteralPath $Logos -File | Where-Object { $_.Name -ne 'desktop.ini' -and -not (Test-Path -LiteralPath (Join-Path (Join-Path $PastaArquivos 'Identidade') $_.Name)) } |
            Copy-Item -Destination (Join-Path $PastaArquivos 'Identidade')
    }
    Write-Host ('Programa: so leitura para o servico. Configuracao: ' + $PastaConfig + '. Arquivos: ' + $PastaArquivos)

    Passo '5/10 Configuracao do servidor'
    if (-not (Test-Path -LiteralPath $ArquivoConfig)) {
        $Cfg = [ordered]@{
            '_comentario' = 'SisCMJ - configuracao DESTE servidor. Pasta protegida (so administradores e o servico). Preencha o SMTP. Nunca copie este arquivo para o projeto.'
            'ConnectionStrings' = [ordered]@{ 'SistemaCMJ' = ('Server=' + $Instancia + ';Database=' + $Banco + ';Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Application Name=SisCMJ') }
            'Kestrel' = [ordered]@{ 'Endpoints' = [ordered]@{ 'Https' = [ordered]@{ 'Url' = ('https://*:' + $Porta) } } }
            'Identidade' = [ordered]@{ 'PastaReserva' = (Join-Path $PastaArquivos 'Identidade') }
            'Smtp' = [ordered]@{ 'Interna' = [ordered]@{ 'Servidor' = ''; 'Porta' = 587; 'Usuario' = ''; 'Remetente' = ''; 'Senha' = '' }; 'Externa' = @{} }
            'Agendador' = [ordered]@{ 'Ligado' = $true }
        }
        [System.IO.File]::WriteAllText($ArquivoConfig, ($Cfg | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
        Write-Host ('Criado: ' + $ArquivoConfig + ' (preencha o SMTP depois)')
    } else { Write-Host ('Ja existe, mantido: ' + $ArquivoConfig) }

    Passo '6/10 Acesso do servico ao banco (sem senha)'
    Sql 'master' ("IF SUSER_ID(N'" + $Conta + "') IS NULL CREATE LOGIN [" + $Conta + "] FROM WINDOWS;") | Out-Null
    Sql $Banco ("IF DATABASE_PRINCIPAL_ID(N'" + $Conta + "') IS NULL CREATE USER [" + $Conta + "] FOR LOGIN [" + $Conta + "]; ALTER ROLE [rl_sistemacmj_api] ADD MEMBER [" + $Conta + "];") | Out-Null
    Write-Host ($Conta + ' no papel rl_sistemacmj_api do banco ' + $Banco)

    Passo '7/10 Certificado HTTPS'
    $Cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq 'CN=SisCMJ' -and $_.NotAfter -gt (Get-Date).AddDays(30) } | Sort-Object NotAfter -Descending | Select-Object -First 1
    if (-not $Cert) {
        $Nomes = @($env:COMPUTERNAME, 'localhost') + $NomesExtras
        $Nomes += (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -ExpandProperty IPAddress)
        $Cert = New-SelfSignedCertificate -Subject 'CN=SisCMJ' -DnsName ($Nomes | Select-Object -Unique) -CertStoreLocation Cert:\LocalMachine\My `
                    -NotAfter (Get-Date).AddYears(5) -KeyAlgorithm RSA -KeyLength 2048 -KeyExportPolicy NonExportable -FriendlyName 'SisCMJ'
        Write-Host ('Criado, valido ate ' + $Cert.NotAfter.ToString('dd/MM/yyyy') + ', nomes: ' + (($Nomes | Select-Object -Unique) -join ', '))
    } else { Write-Host ('Ja existe, valido ate ' + $Cert.NotAfter.ToString('dd/MM/yyyy')) }
    $Chave = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Cert)
    $ArqChave = Join-Path $env:ProgramData ('Microsoft\Crypto\Keys\' + $Chave.Key.UniqueName)
    & icacls $ArqChave /grant ($Conta + ':R') | Out-Null
    $Cer = Join-Path $PSScriptRoot 'SisCMJ_certificado.cer'
    Export-Certificate -Cert $Cert -FilePath $Cer -Force | Out-Null
    Import-Certificate -FilePath $Cer -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    Write-Host ('Copia publica para os usuarios: ' + $Cer)

    Passo '8/10 Firewall'
    Get-NetFirewallRule -DisplayName ('SisCMJ*') -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like ('SisCMJ (' + $NomeServico + ')*') } | Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName ('SisCMJ (' + $NomeServico + ') HTTPS ' + $Porta) -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Porta `
        -Profile Domain,Private -RemoteAddress $RedesPermitidas | Out-Null
    Write-Host ('Porta ' + $Porta + ' liberada so para: ' + ($RedesPermitidas -join ', ') + ' (perfis Dominio e Privado). SQL Server continua fechado.')

    Passo '9/10 Iniciando e conferindo'
    Start-Service -Name $NomeServico
    # Conferencia pelo curl.exe (vem no Windows 10/11): o Invoke-WebRequest do PowerShell 5.1 nao negocia o TLS do sistema
    $Saude = $null
    for ($i = 0; $i -lt 30 -and -not $Saude; $i++) {
        Start-Sleep -Seconds 2
        $Resp = (& curl.exe -k -s --max-time 5 ('https://localhost:' + $Porta + '/api/saude')) -join ''
        if ($Resp -like '*"sistema"*') { $Saude = $Resp }
    }
    Write-Host ('Saude: ' + $(if ($Saude) { $Saude } else { 'sem resposta (veja ' + (Join-Path $PastaConfig 'logs') + ')' }))

    Passo '10/10 Backup automatico'
    # SYSTEM (conta das tarefas) faz backup e teste de restauracao no SQL
    # nome da conta SYSTEM no idioma do Windows (em portugues: AUTORIDADE NT\SISTEMA)
    $Sistema = (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')).Translate([System.Security.Principal.NTAccount]).Value
    Sql 'master' ("IF SUSER_ID(N'" + $Sistema + "') IS NULL CREATE LOGIN [" + $Sistema + "] FROM WINDOWS; ALTER SERVER ROLE [sysadmin] ADD MEMBER [" + $Sistema + "];") | Out-Null
    $PastaBackup = [string](Sql $Banco "SELECT SIS.fn_SIS_Parametro('BACKUP_PASTA')")
    if (-not $PastaBackup) { $PastaBackup = Join-Path $PastaArquivos 'Backup' }
    New-Item -ItemType Directory -Force -Path $PastaBackup | Out-Null
    $ContaSql = if ($Instancia -match '\\(.+)$') { 'NT Service\MSSQL$' + $Matches[1] } else { 'NT Service\MSSQLSERVER' }
    & icacls $PastaBackup /grant ($ContaSql + ':(OI)(CI)M') | Out-Null
    $PastaScripts = Join-Path (Split-Path $PastaPrograma -Parent) 'scripts'
    New-Item -ItemType Directory -Force -Path $PastaScripts | Out-Null
    & icacls $PastaScripts /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'backup_servidor.ps1') -Destination $PastaScripts -Force
    $Script = Join-Path $PastaScripts 'backup_servidor.ps1'
    $Quem = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $Config = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 4) -MultipleInstances IgnoreNew
    $Prefixo = 'SisCMJ (' + $NomeServico + ') - '
    $Tarefas = [ordered]@{
        'Backup completo'         = @('COMPLETO', (New-ScheduledTaskTrigger -Daily -At $HoraBackupCompleto))
        'Backup do log'           = @('LOG', (New-ScheduledTaskTrigger -Once -At ((Get-Date).Date.AddMinutes(30)) -RepetitionInterval (New-TimeSpan -Hours 1)))
        'Teste de restauracao'    = @('TESTE', (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '04:00'))
    }
    foreach ($Nome in $Tarefas.Keys) {
        $Acao = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "' + $Script + '" -Modo ' + $Tarefas[$Nome][0] + ' -Instancia "' + $Instancia + '" -Banco "' + $Banco + '"')
        Register-ScheduledTask -TaskName ($Prefixo + $Nome) -Action $Acao -Trigger $Tarefas[$Nome][1] -Principal $Quem -Settings $Config -Force | Out-Null
    }
    Write-Host ('Tarefas: completo todo dia as ' + $HoraBackupCompleto + ', log de hora em hora, teste de restauracao aos domingos 04:00. Pasta: ' + $PastaBackup)
    foreach ($Nome in @('Backup completo', 'Teste de restauracao')) {
        Start-ScheduledTask -TaskName ($Prefixo + $Nome)
        Start-Sleep -Seconds 3
        for ($i = 0; $i -lt 120 -and (Get-ScheduledTask -TaskName ($Prefixo + $Nome)).State -eq 'Running'; $i++) { Start-Sleep -Seconds 2 }
        $Res = (Get-ScheduledTaskInfo -TaskName ($Prefixo + $Nome)).LastTaskResult
        Write-Host ($Nome + ' (agora): ' + $(if ($Res -eq 0) { 'OK' } else { 'ERRO (codigo ' + $Res + '), veja ' + (Join-Path $PastaBackup 'backup.log') }))
    }

    # Arquivo para os computadores dos usuarios: certificado + atalho, com o endereco deste servidor
    $Endereco = 'https://' + $env:COMPUTERNAME + ':' + $Porta + '/'
    $Usuario = "@echo off`r`nrem SisCMJ - prepara um computador de usuario (rodar como administrador, uma vez)`r`ncd /d `"%~dp0`"`r`ncertutil -addstore -f Root SisCMJ_certificado.cer`r`npowershell -NoProfile -Command `"`$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('CommonDesktopDirectory')+'\SisCMJ.lnk'); `$s.TargetPath='" + $Endereco + "'; `$s.Save()`"`r`necho Pronto: abra o atalho SisCMJ na area de trabalho.`r`npause`r`n"
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'preparar_computador_usuario.cmd'), $Usuario, (New-Object System.Text.ASCIIEncoding))

    Write-Host ''
    Write-Host 'PRONTO.' -ForegroundColor Green
    Write-Host ('1) Neste servidor, abra https://localhost:' + $Porta + '/instalacao.html e defina as senhas dos administradores (so na primeira instalacao).')
    Write-Host ('2) Nos computadores dos usuarios: copie SisCMJ_certificado.cer e preparar_computador_usuario.cmd e rode o .cmd como administrador. Endereco: ' + $Endereco)
    Write-Host ('3) Preencha o SMTP em ' + $ArquivoConfig + ' e reinicie o servico (Restart-Service ' + $NomeServico + ').')
    Write-Host ('4) LICENCA: codigo deste servidor ' + $CodigoServidor + ' (tambem em codigo_servidor.txt). Gere a licenca no notebook do Celso e copie como ' + (Join-Path $PastaConfig 'licenca.lic') + ' (vale em ate 1 minuto, sem reiniciar).')
    Write-Host ('Registro desta instalacao: ' + $Log)
}
catch {
    Write-Host ''
    Write-Host ('ERRO: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('Registro desta instalacao: ' + $Log)
    Stop-Transcript | Out-Null
    exit 1
}
Stop-Transcript | Out-Null
exit 0

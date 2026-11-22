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
  v1.5 (20/11/2026) - Etapa 03d2: tarefa "Restauracao (pedidos)", a cada minuto, que faz as
                      restauracoes pedidas pela tela Sistema > Backups (para e religa o servico).
  v1.6 (22/11/2026) - Ensaio 3d-C (VM limpa), achados:
                      a) para com mensagem clara se a rede estiver como Publica (o firewall
                         so libera a porta nos perfis Dominio e Privado);
                      b) -EnderecoUsuarios: nome ou IP fixo que os usuarios usam (atalho e
                         certificado), para redes que nao acham o servidor pelo nome;
                      c) certificado com os IPs como "endereco IP" (o Chrome nao aceita IP
                         gravado como nome) e refeito se faltar algum nome/IP pedido;
                      d) acentos da resposta de /api/saude certos na janela (UTF-8).
  v1.7 (22/11/2026) - Etapa 03h (atualizacao em um clique):
                      a) grava os parametros usados em %ProgramData%\SisCMJ\instalacao.json,
                         para o atualizar.cmd repetir os mesmos (endereco dos usuarios etc.);
                      b) -SemBackupAgora: nao roda o backup completo e o teste na hora
                         (o atualizar.cmd faz o backup dele e segura a trava do backup).
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
    [string]$HoraBackupCompleto = '23:00',
    [string]$EnderecoUsuarios = '',
    [switch]$SemBackupAgora
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$EnderecoUsuarios = $EnderecoUsuarios.Trim()
if (-not $EnderecoUsuarios) { $EnderecoUsuarios = $env:COMPUTERNAME }
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
    # Rede Publica: o firewall (passo 8) so libera a porta nos perfis Dominio e Privado
    $Publicas = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.NetworkCategory -eq 'Public' })
    if ($Publicas.Count -gt 0) {
        throw ('A rede "' + (($Publicas | ForEach-Object { $_.InterfaceAlias + ' (' + $_.Name + ')' }) -join ', ') + '" esta como PUBLICA: os computadores dos usuarios nao vao conseguir entrar. ' +
               'Mude para Privada (Configuracoes > Rede e Internet > a conexao > Tipo de perfil de rede > Rede privada) e rode de novo.')
    }
    Write-Host ('Rede: ' + ((Get-NetConnectionProfile | ForEach-Object { $_.InterfaceAlias + ' = ' + $_.NetworkCategory }) -join ', '))
    Write-Host ('Endereco dos usuarios: https://' + $EnderecoUsuarios + ':' + $Porta + '/')

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
    # Nomes (DNS) e IPs (IP Address) do certificado: o Chrome so aceita IP gravado como IP
    $Todos = @($env:COMPUTERNAME, 'localhost') + $NomesExtras + @($EnderecoUsuarios)
    $Todos += (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -ExpandProperty IPAddress)
    $Todos = @($Todos | Where-Object { $_ } | Select-Object -Unique)
    $Ip = [System.Net.IPAddress]$null
    $Ips = @($Todos | Where-Object { [System.Net.IPAddress]::TryParse($_, [ref]$Ip) })
    $Dns = @($Todos | Where-Object { $Ips -notcontains $_ })
    $Exigidos = @($NomesExtras + @($EnderecoUsuarios) | Where-Object { $_ })
    $Cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq 'CN=SisCMJ' -and $_.NotAfter -gt (Get-Date).AddDays(30) } | Sort-Object NotAfter -Descending | Select-Object -First 1
    if ($Cert) {
        $San = [string](($Cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' }) | ForEach-Object { $_.Format($false) })
        $Faltam = @($Exigidos | Where-Object { $San -notmatch ('(=|\s)' + [regex]::Escape($_) + '(,|$)') })
        $SoNome = @($Ips | Where-Object { $Exigidos -contains $_ } | Where-Object { $San -notmatch ('IP[^=]*=' + [regex]::Escape($_)) })
        if ($Faltam.Count -gt 0 -or $SoNome.Count -gt 0) {
            Write-Host ('Certificado atual nao serve para: ' + (@($Faltam + $SoNome | Select-Object -Unique) -join ', ') + ' (sera refeito)')
            $Cert = $null
        }
    }
    if (-not $Cert) {
        $Partes = @($Dns | ForEach-Object { 'DNS=' + $_ }) + @($Ips | ForEach-Object { 'IPAddress=' + $_ })
        $Cert = New-SelfSignedCertificate -Subject 'CN=SisCMJ' -TextExtension @('2.5.29.17={text}' + ($Partes -join '&')) -CertStoreLocation Cert:\LocalMachine\My `
                    -NotAfter (Get-Date).AddYears(5) -KeyAlgorithm RSA -KeyLength 2048 -KeyExportPolicy NonExportable -FriendlyName 'SisCMJ'
        Write-Host ('Criado, valido ate ' + $Cert.NotAfter.ToString('dd/MM/yyyy') + '; nomes: ' + ($Dns -join ', ') + '; IPs: ' + ($Ips -join ', '))
        # tira os antigos (do servidor e da lista de confiaveis deste servidor)
        Get-ChildItem Cert:\LocalMachine\My, Cert:\LocalMachine\Root | Where-Object { $_.Subject -eq 'CN=SisCMJ' -and $_.Thumbprint -ne $Cert.Thumbprint } | Remove-Item -ErrorAction SilentlyContinue
        $CertNovo = $true
    } else { Write-Host ('Ja existe, valido ate ' + $Cert.NotAfter.ToString('dd/MM/yyyy')); $CertNovo = $false }
    $Chave = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Cert)
    $ArqChave = Join-Path $env:ProgramData ('Microsoft\Crypto\Keys\' + $Chave.Key.UniqueName)
    & icacls $ArqChave /grant ($Conta + ':R') | Out-Null
    $Cer = Join-Path $PSScriptRoot 'SisCMJ_certificado.cer'
    Export-Certificate -Cert $Cert -FilePath $Cer -Force | Out-Null
    Import-Certificate -FilePath $Cer -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    Write-Host ('Copia publica para os usuarios: ' + $Cer)
    if ($CertNovo -and $Existe) { Write-Host 'ATENCAO: certificado NOVO. Rode de novo o preparar_computador_usuario.cmd em cada computador de usuario.' -ForegroundColor Yellow }

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
        'Restauracao (pedidos)'   = @('RESTAURAR', (New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(1)) -RepetitionInterval (New-TimeSpan -Minutes 1)))
    }
    foreach ($Nome in $Tarefas.Keys) {
        $Acao = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "' + $Script + '" -Modo ' + $Tarefas[$Nome][0] + ' -Instancia "' + $Instancia + '" -Banco "' + $Banco + '" -Servico "' + $NomeServico + '"')
        Register-ScheduledTask -TaskName ($Prefixo + $Nome) -Action $Acao -Trigger $Tarefas[$Nome][1] -Principal $Quem -Settings $Config -Force | Out-Null
    }
    Write-Host ('Tarefas: completo todo dia as ' + $HoraBackupCompleto + ', log de hora em hora, teste de restauracao aos domingos 04:00, pedidos de restauracao da tela a cada minuto. Pasta: ' + $PastaBackup)
    foreach ($Nome in $(if ($SemBackupAgora) { @() } else { @('Backup completo', 'Teste de restauracao') })) {
        Start-ScheduledTask -TaskName ($Prefixo + $Nome)
        Start-Sleep -Seconds 3
        for ($i = 0; $i -lt 120 -and (Get-ScheduledTask -TaskName ($Prefixo + $Nome)).State -eq 'Running'; $i++) { Start-Sleep -Seconds 2 }
        $Res = (Get-ScheduledTaskInfo -TaskName ($Prefixo + $Nome)).LastTaskResult
        Write-Host ($Nome + ' (agora): ' + $(if ($Res -eq 0) { 'OK' } else { 'ERRO (codigo ' + $Res + '), veja ' + (Join-Path $PastaBackup 'backup.log') }))
    }

    # Arquivo para os computadores dos usuarios: certificado + atalho, com o endereco deste servidor
    $Endereco = 'https://' + $EnderecoUsuarios + ':' + $Porta + '/'
    $Usuario = "@echo off`r`nrem SisCMJ - prepara um computador de usuario (rodar como administrador, uma vez)`r`ncd /d `"%~dp0`"`r`npowershell -NoProfile -Command `"Get-ChildItem Cert:\LocalMachine\Root | Where-Object { `$_.Subject -eq 'CN=SisCMJ' } | Remove-Item`"`r`ncertutil -addstore -f Root SisCMJ_certificado.cer`r`npowershell -NoProfile -Command `"`$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('CommonDesktopDirectory')+'\SisCMJ.lnk'); `$s.TargetPath='" + $Endereco + "'; `$s.Save()`"`r`necho Pronto: abra o atalho SisCMJ na area de trabalho.`r`npause`r`n"
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'preparar_computador_usuario.cmd'), $Usuario, (New-Object System.Text.ASCIIEncoding))

    # Parametros desta instalacao, para o atualizar.cmd repetir os mesmos (sem senha nenhuma)
    $Usados = [ordered]@{
        'NomeServico' = $NomeServico; 'PastaPrograma' = $PastaPrograma; 'PastaArquivos' = $PastaArquivos; 'Instancia' = $Instancia; 'Banco' = $Banco
        'Porta' = $Porta; 'RedesPermitidas' = ($RedesPermitidas -join ','); 'NomesExtras' = ($NomesExtras -join ','); 'HoraBackupCompleto' = $HoraBackupCompleto
        'EnderecoUsuarios' = $EnderecoUsuarios; 'GravadoEm' = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    [System.IO.File]::WriteAllText((Join-Path $PastaConfig 'instalacao.json'), ($Usados | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ('Parametros desta instalacao guardados em ' + (Join-Path $PastaConfig 'instalacao.json') + ' (usados pelo atualizar.cmd).')

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

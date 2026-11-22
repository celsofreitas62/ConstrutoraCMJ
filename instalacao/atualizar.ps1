<#
  SisCMJ - atualizacao em um clique (versao nova do pacote neste servidor)
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (22/11/2026) - Criacao (etapa 03h). Roda pelo atualizar.cmd da raiz do pacote,
                      COMO ADMINISTRADOR. Excecao aprovada a regra 37 do PADRAO_SQL:
                      o MASTER roda pelo sqlcmd (-f 65001), depois do backup de seguranca
                      e com volta automatica se falhar.
  Faz, nesta ordem:
    1) conferencias: administrador; versao do pacote (versao.txt) x instalada (programa
       e banco): pacote mais velho = recusa; mesma versao = pergunta se reinstala;
       sqlcmd encontrado; quem esta com sessao aberta; confirmacao (S/N);
    2) segura a trava do backup (Global\SisCMJ_Backup_<banco>): nenhum backup ou
       restauracao da tela roda no meio;
    3) para o servico; backup de SEGURANCA (completo COPY_ONLY, nao mexe nas copias
       diarias) conferido com RESTORE VERIFYONLY; copia do programa atual em
       <pasta do programa>_anterior;
    4) MASTER novo pelo sqlcmd; confere a versao do banco;
    5) programa pelo instalar_servico.ps1 do pacote, com os MESMOS parametros da
       instalacao (%ProgramData%\SisCMJ\instalacao.json; se nao existir, pergunta o
       endereco dos usuarios e o instalador grava o arquivo);
    6) /api/saude: situacao ok e as versoes novas (ate 1 minuto);
    7) registra em SIS.Atualizacao (com a nota da versao, NOTAS_DA_VERSAO.txt);
    8) solta a trava e faz um backup completo da versao nova (a restauracao pela tela
       so volta ate o momento da atualizacao).
  Se algo falhar depois do passo 3: para o servico, restaura o backup de seguranca
  (se o MASTER chegou a rodar), volta o programa anterior, religa, confere a saude e
  registra DESFEITA (ou ERRO, se nem a volta funcionou: chamar o Celso).
  Registro: atualizacao_<data>.log ao lado deste script e copia em %ProgramData%\SisCMJ\logs.
  Ensaio na VM: -EnsaioFalha MASTER ou SAUDE provoca a falha de proposito (testa a volta).
  -Sim responde S as perguntas (so para ensaio). -Endereco: endereco dos usuarios, so
  quando nao houver instalacao.json.
#>
param(
    [string]$Endereco = '',
    [switch]$Sim,
    [ValidateSet('', 'MASTER', 'SAUDE')][string]$EnsaioFalha = ''
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Inicio = Get-Date
$Marca = $Inicio.ToString('yyyyMMdd_HHmmss')
$Pacote = Split-Path $PSScriptRoot -Parent
$PastaConfig = Join-Path $env:ProgramData 'SisCMJ'
$Log = Join-Path $PSScriptRoot ('atualizacao_' + $Marca + '.log')
Start-Transcript -LiteralPath $Log | Out-Null

$Mexeu = $false; $MexeuBanco = $false; $MexeuPrograma = $false
$Trava = $null; $TemTrava = $false; $BackupSeg = $null; $Parou = $null
$ProgDe = ''; $BancoDe = ''; $PkgProg = ''; $PkgBanco = ''; $Notas = ''
$Cfg = $null

function Passo([string]$Texto) { Write-Host ''; Write-Host ('=== ' + $Texto) -ForegroundColor Cyan }
function Sql([string]$BancoSql, [string]$Comando, [hashtable]$Parametros = @{}) {
    $Con = New-Object System.Data.SqlClient.SqlConnection("Server=$($Cfg.Instancia);Database=$BancoSql;Integrated Security=SSPI;Pooling=false;Application Name=SisCMJ atualizador")
    $Con.Open()
    try {
        $C = $Con.CreateCommand(); $C.CommandText = $Comando; $C.CommandTimeout = 0
        foreach ($k in $Parametros.Keys) { [void]$C.Parameters.AddWithValue($k, $(if ($null -eq $Parametros[$k]) { [DBNull]::Value } else { $Parametros[$k] })) }
        return $C.ExecuteScalar()
    } finally { $Con.Close() }
}
function Perguntar([string]$Texto) {
    if ($Sim) { Write-Host ($Texto + ' S (automatico, -Sim)'); return $true }
    $R = Read-Host ($Texto + ' (S/N)')
    return ($R.Trim().ToUpper() -eq 'S')
}
function Saude() {
    $Resp = (& curl.exe -k -s --max-time 5 ('https://localhost:' + $Cfg.Porta + '/api/saude')) -join ''
    if ($Resp -notlike '*"sistema"*') { return $null }
    try { return ($Resp | ConvertFrom-Json) } catch { return $null }
}
function Esperar-Saude([int]$Segundos, [scriptblock]$Bom) {
    $Ultima = $null
    for ($i = 0; $i -lt [math]::Ceiling($Segundos / 3); $i++) {
        Start-Sleep -Seconds 3
        $Ultima = Saude
        if ($Ultima -and (& $Bom $Ultima)) { return $Ultima }
    }
    return $Ultima
}
function Versao([string]$Texto) { try { return [version]($Texto.Split('+')[0].Trim()) } catch { return [version]'0.0' } }
function Registrar([string]$Situacao, [string]$Mensagem) {
    try {
        if (-not (Sql $Cfg.Banco "SELECT OBJECT_ID(N'SIS.SIS_Atualizacao_Registrar', N'P')")) { Write-Host 'Registro no banco: a versao do banco nao tem o historico (so no arquivo).'; return }
        $Fim = Get-Date
        $Fora = if ($Parou) { [int]($Fim - $Parou).TotalSeconds } else { 0 }
        $R = Sql $Cfg.Banco 'EXEC SIS.SIS_Atualizacao_Registrar @VersaoProgramaDe=@pd, @VersaoProgramaPara=@pp, @VersaoBancoDe=@bd, @VersaoBancoPara=@bp, @DtInicio=@i, @DtFim=@f, @SegundosFora=@s, @Situacao=@st, @Mensagem=@m, @Notas=@n, @Pacote=@pk' @{
            '@pd' = $ProgDe; '@pp' = $PkgProg; '@bd' = $BancoDe; '@bp' = $PkgBanco; '@i' = $Inicio; '@f' = $Fim; '@s' = $Fora; '@st' = $Situacao
            '@m' = $(if ($Mensagem.Length -gt 2000) { $Mensagem.Substring(0, 2000) } else { $Mensagem }); '@n' = $Notas; '@pk' = $Pacote }
        Write-Host ('Registro no banco (SIS.Atualizacao): ' + $(if ($R) { 'OK' } else { 'nao gravou' }))
    } catch { Write-Host ('Registro no banco falhou: ' + $_.Exception.Message) -ForegroundColor Yellow }
}
function Backup-Completo-Agora() {
    $Tarefa = 'SisCMJ (' + $Cfg.NomeServico + ') - Backup completo'
    if (-not (Get-ScheduledTask -TaskName $Tarefa -ErrorAction SilentlyContinue)) { Write-Host ('Tarefa nao encontrada: ' + $Tarefa) -ForegroundColor Yellow; return }
    Start-ScheduledTask -TaskName $Tarefa
    Start-Sleep -Seconds 3
    for ($i = 0; $i -lt 300 -and (Get-ScheduledTask -TaskName $Tarefa).State -eq 'Running'; $i++) { Start-Sleep -Seconds 2 }
    $Res = (Get-ScheduledTaskInfo -TaskName $Tarefa).LastTaskResult
    Write-Host ('Backup completo (agora): ' + $(if ($Res -eq 0) { 'OK' } else { 'ERRO (codigo ' + $Res + '), veja o backup.log da pasta do backup' }))
}
function Soltar-Trava() { if ($TemTrava) { try { $Trava.ReleaseMutex() } catch {} ; $script:TemTrava = $false } }

try {
    Passo '1/8 Conferencias'
    $Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $Admin) { throw 'Rode como administrador (botao direito no atualizar.cmd > Executar como administrador).' }
    $ArqVersao = Join-Path $Pacote 'versao.txt'
    if (-not (Test-Path -LiteralPath $ArqVersao)) { throw 'Pacote sem versao.txt (gerado antes da 03h): gere o pacote de novo com o publicar.cmd.' }
    foreach ($L in (Get-Content -LiteralPath $ArqVersao)) { if ($L -match '^PROGRAMA=(.+)$') { $PkgProg = $Matches[1].Trim() }; if ($L -match '^BANCO=(.+)$') { $PkgBanco = $Matches[1].Trim() } }
    if (-not $PkgProg -or -not $PkgBanco) { throw 'versao.txt do pacote sem PROGRAMA= ou BANCO=.' }
    $ArqNotas = Join-Path $Pacote 'NOTAS_DA_VERSAO.txt'
    if (Test-Path -LiteralPath $ArqNotas) { $Notas = [System.IO.File]::ReadAllText($ArqNotas, [System.Text.Encoding]::UTF8) }
    $Master = Join-Path $Pacote 'sql\SISTEMACMJ_MASTER_Instalacao.sql'
    if (-not (Test-Path -LiteralPath $Master)) { throw ('Nao achei o MASTER do pacote: ' + $Master) }

    # Parametros da instalacao (gravados pelo instalador v1.7)
    $ArqCfg = Join-Path $PastaConfig 'instalacao.json'
    if (Test-Path -LiteralPath $ArqCfg) {
        $Cfg = Get-Content -LiteralPath $ArqCfg -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host ('Parametros da instalacao: ' + $ArqCfg)
    } else {
        Write-Host 'Esta instalacao ainda nao tem instalacao.json (instalador antigo): usando o padrao.' -ForegroundColor Yellow
        if (-not $Endereco) {
            if ($Sim) { $Endereco = $env:COMPUTERNAME }
            else { $Endereco = (Read-Host ('Endereco que os usuarios usam para entrar (nome ou IP fixo; Enter = ' + $env:COMPUTERNAME + ')')).Trim() }
            if (-not $Endereco) { $Endereco = $env:COMPUTERNAME }
        }
        $Cfg = [pscustomobject]@{ NomeServico = 'SisCMJ'; PastaPrograma = 'C:\SisCMJ\programa'; PastaArquivos = 'C:\SistemaCMJ_Arquivos'; Instancia = '.\SQL2025'
                                  Banco = 'SISTEMACMJ'; Porta = 5443; RedesPermitidas = 'LocalSubnet'; NomesExtras = ''; HoraBackupCompleto = '23:00'; EnderecoUsuarios = $Endereco }
    }
    Write-Host ('Servico ' + $Cfg.NomeServico + ', banco ' + $Cfg.Instancia + '/' + $Cfg.Banco + ', porta ' + $Cfg.Porta + ', endereco dos usuarios ' + $Cfg.EnderecoUsuarios)
    if (-not (Get-Service -Name $Cfg.NomeServico -ErrorAction SilentlyContinue)) { throw ('O servico ' + $Cfg.NomeServico + ' nao existe neste computador: isto e uma instalacao nova, siga o roteiro (instalar_servico.cmd).') }

    $Exe = Join-Path $Cfg.PastaPrograma 'SistemaCMJ.Api.exe'
    $ProgDe = if (Test-Path -LiteralPath $Exe) { ([string](Get-Item -LiteralPath $Exe).VersionInfo.ProductVersion).Split('+')[0] } else { '' }
    $BancoDe = [string](Sql $Cfg.Banco 'SELECT SIS.fn_SIS_Versao_Banco()')
    Write-Host ('Instalado: programa ' + $ProgDe + ', banco ' + $BancoDe)
    Write-Host ('Pacote   : programa ' + $PkgProg + ', banco ' + $PkgBanco + '  (' + $Pacote + ')')
    if ((Versao $PkgBanco) -lt (Versao $BancoDe) -or (Versao $PkgProg) -lt (Versao $ProgDe)) {
        throw ('Este pacote e MAIS VELHO que o instalado. A atualizacao nunca volta versao (para voltar, so com o Celso, pela restauracao).')
    }
    if ((Versao $PkgBanco) -eq (Versao $BancoDe) -and (Versao $PkgProg) -eq (Versao $ProgDe)) {
        Write-Host 'O servidor ja esta nesta versao.' -ForegroundColor Yellow
        if (-not (Perguntar 'Reinstalar a mesma versao mesmo assim?')) { Write-Host 'Nada foi alterado.'; Stop-Transcript | Out-Null; exit 0 }
    }

    # sqlcmd (excecao a regra 37): instalado ou no pacote
    $Sqlcmd = $null
    $Achado = Get-Command sqlcmd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Achado) { $Sqlcmd = $Achado.Source }
    if (-not $Sqlcmd) {
        $Candidatos = @(Join-Path $Pacote 'ferramentas\sqlcmd.exe') + @(Get-ChildItem -Path 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\*\Tools\Binn\SQLCMD.EXE', 'C:\Program Files\SqlCmd\sqlcmd.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object { $_.FullName })
        $Sqlcmd = $Candidatos | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    }
    if (-not $Sqlcmd) { throw 'Nao achei o sqlcmd neste servidor (nem no pacote, pasta ferramentas). Nada foi alterado. Instale o sqlcmd ou fale com o Celso.' }
    Write-Host ('sqlcmd: ' + $Sqlcmd)

    $SaudeAntes = Saude
    Write-Host ('Saude agora: ' + $(if ($SaudeAntes) { $SaudeAntes.situacao } else { 'sem resposta' }))
    $Sessoes = [string](Sql $Cfg.Banco "SELECT ISNULL(STRING_AGG(CONVERT(NVARCHAR(MAX), u.LOGIN + N' (' + ISNULL(NULLIF(s.ESTACAO, N''), s.IP) + N')'), N', '), N'') FROM SIS.Sessao s WITH (NOLOCK) JOIN SIS.Usuario u WITH (NOLOCK) ON u.ID_USUARIO = s.ID_USUARIO WHERE s.DT_FIM IS NULL AND s.DT_ULTIMO_ACESSO > DATEADD(MINUTE, -30, SYSDATETIME())")
    Write-Host ('Usando o sistema (ultimos 30 min): ' + $(if ($Sessoes) { $Sessoes } else { 'ninguem' })) -ForegroundColor $(if ($Sessoes) { 'Yellow' } else { 'Gray' })
    if ($Notas) { Write-Host ''; Write-Host 'Nota da versao:'; Write-Host $Notas }
    if (-not (Perguntar ('Atualizar de ' + $BancoDe + ' para ' + $PkgBanco + ' agora? O sistema fica fora do ar de 1 a 3 minutos.'))) { Write-Host 'Nada foi alterado.'; Stop-Transcript | Out-Null; exit 0 }

    Passo '2/8 Trava do backup'
    $Trava = New-Object System.Threading.Mutex($false, ('Global\SisCMJ_Backup_' + $Cfg.Banco))
    try { $TemTrava = $Trava.WaitOne([TimeSpan]::FromMinutes(15)) } catch [System.Threading.AbandonedMutexException] { $TemTrava = $true }
    if (-not $TemTrava) { throw 'Um backup ou restauracao esta rodando ha mais de 15 minutos. Nada foi alterado; tente de novo mais tarde.' }
    Write-Host 'Trava segura: nenhum backup ou restauracao roda ate o fim da atualizacao.'

    Passo '3/8 Parando o sistema e backup de seguranca'
    $PastaBackup = [string](Sql $Cfg.Banco "SELECT SIS.fn_SIS_Parametro('BACKUP_PASTA')")
    if (-not $PastaBackup) { $PastaBackup = Join-Path $Cfg.PastaArquivos 'Backup' }
    $PastaSeg = Join-Path $PastaBackup 'Atualizacao'
    New-Item -ItemType Directory -Force -Path $PastaSeg | Out-Null
    $Mexeu = $true
    Stop-Service -Name $Cfg.NomeServico -Force
    (Get-Service $Cfg.NomeServico).WaitForStatus('Stopped', (New-TimeSpan -Seconds 60))
    $Parou = Get-Date
    Write-Host ('Sistema parado as ' + $Parou.ToString('HH:mm:ss'))
    $BackupSeg = Join-Path $PastaSeg ($Cfg.Banco + '_ANTES_' + $PkgBanco + '_' + $Marca + '.bak')
    Sql 'master' ('BACKUP DATABASE ' + '[' + $Cfg.Banco + ']' + ' TO DISK = @a WITH COPY_ONLY, CHECKSUM, INIT, NAME = N''SisCMJ - antes da atualizacao''') @{ '@a' = $BackupSeg } | Out-Null
    Sql 'master' 'RESTORE VERIFYONLY FROM DISK = @a WITH CHECKSUM' @{ '@a' = $BackupSeg } | Out-Null
    Write-Host ('Backup de seguranca conferido: ' + $BackupSeg + ' (' + [math]::Round((Get-Item -LiteralPath $BackupSeg).Length / 1MB, 1) + ' MB)')
    $ProgAnterior = $Cfg.PastaPrograma.TrimEnd('\') + '_anterior'
    & robocopy $Cfg.PastaPrograma $ProgAnterior /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw ('Falha ao guardar o programa atual (robocopy ' + $LASTEXITCODE + ').') }
    Write-Host ('Programa atual guardado em ' + $ProgAnterior)

    Passo '4/8 Banco: MASTER pelo sqlcmd'
    $SaidaMaster = Join-Path $PSScriptRoot ('master_' + $Marca + '.txt')
    $MexeuBanco = $true
    & $Sqlcmd -S $Cfg.Instancia -d $Cfg.Banco -E -C -b -f 65001 -I -i $Master -o $SaidaMaster
    $CodigoMaster = $LASTEXITCODE
    $TextoMaster = if (Test-Path -LiteralPath $SaidaMaster) { [System.IO.File]::ReadAllText($SaidaMaster, [System.Text.Encoding]::UTF8) } else { '' }
    $Erros = [regex]::Matches($TextoMaster, 'Msg \d+, Level (1[1-9]|2\d)[^\r\n]*(\r?\n[^\r\n]*){0,2}')
    if ($CodigoMaster -ne 0 -or $Erros.Count -gt 0) {
        throw ('O MASTER deu erro (sqlcmd ' + $CodigoMaster + '): ' + $(if ($Erros.Count -gt 0) { $Erros[0].Value.Trim() } else { ($TextoMaster -split "`n" | Select-Object -Last 5) -join ' ' }) + ' | saida completa: ' + $SaidaMaster)
    }
    if ($EnsaioFalha -eq 'MASTER') { throw 'Falha SIMULADA depois do MASTER (ensaio da volta automatica).' }
    $BancoAgora = [string](Sql $Cfg.Banco 'SELECT SIS.fn_SIS_Versao_Banco()')
    if ($BancoAgora -ne $PkgBanco) { throw ('Depois do MASTER o banco ficou na versao ' + $BancoAgora + ', e o pacote e ' + $PkgBanco + '.') }
    Write-Host ('MASTER OK: banco na versao ' + $BancoAgora + ' (saida: ' + $SaidaMaster + ')')

    Passo '5/8 Programa: instalador do pacote'
    $MexeuPrograma = $true
    $Args5 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'instalar_servico.ps1'),
               '-NomeServico', $Cfg.NomeServico, '-PastaPrograma', $Cfg.PastaPrograma, '-PastaArquivos', $Cfg.PastaArquivos, '-Instancia', $Cfg.Instancia,
               '-Banco', $Cfg.Banco, '-Porta', [string]$Cfg.Porta, '-RedesPermitidas', [string]$Cfg.RedesPermitidas, '-HoraBackupCompleto', $Cfg.HoraBackupCompleto,
               '-EnderecoUsuarios', $Cfg.EnderecoUsuarios, '-SemBackupAgora')
    if ([string]$Cfg.NomesExtras) { $Args5 += @('-NomesExtras', [string]$Cfg.NomesExtras) }
    & powershell.exe @Args5
    if ($LASTEXITCODE -ne 0) { throw ('O instalador do programa deu erro (codigo ' + $LASTEXITCODE + '); veja o instalacao_*.log da pasta instalacao do pacote.') }

    Passo '6/8 Conferencia (/api/saude)'
    $Aceita = @('ok') + $(if ($SaudeAntes -and $SaudeAntes.situacao -eq 'licenca_invalida') { @('licenca_invalida') } else { @() })
    $S = Esperar-Saude 60 { param($x) ($Aceita -contains $x.situacao) -and $x.versaoBanco -eq $PkgBanco -and $x.versao -eq $PkgProg }
    if ($EnsaioFalha -eq 'SAUDE') { throw 'Falha SIMULADA na conferencia da saude (ensaio da volta automatica).' }
    if (-not $S -or -not ($Aceita -contains $S.situacao) -or $S.versaoBanco -ne $PkgBanco -or $S.versao -ne $PkgProg) {
        throw ('A conferencia nao passou: ' + $(if ($S) { 'situacao ' + $S.situacao + ', programa ' + $S.versao + ', banco ' + $S.versaoBanco } else { 'o sistema nao respondeu em 1 minuto' }) + '.')
    }
    $Voltou = Get-Date
    Write-Host ('Saude: ' + $S.situacao + ', programa ' + $S.versao + ', banco ' + $S.versaoBanco + '. Fora do ar: ' + [int]($Voltou - $Parou).TotalSeconds + ' s.') -ForegroundColor Green

    Passo '7/8 Registro'
    Registrar 'CONCLUIDA' ('Atualizado de ' + $ProgDe + '/' + $BancoDe + ' para ' + $PkgProg + '/' + $PkgBanco + '.')

    Passo '8/8 Backup completo da versao nova'
    Soltar-Trava
    Backup-Completo-Agora

    Write-Host ''
    Write-Host ('ATUALIZACAO CONCLUIDA: programa ' + $ProgDe + ' -> ' + $PkgProg + ', banco ' + $BancoDe + ' -> ' + $PkgBanco + '. Fora do ar: ' + [int]($Voltou - $Parou).TotalSeconds + ' s; total ' + [int]((Get-Date) - $Inicio).TotalSeconds + ' s.') -ForegroundColor Green
    Write-Host ('Backup de seguranca (pode apagar depois de alguns dias): ' + $BackupSeg)
    Write-Host ('Registro: ' + $Log)
    $Codigo = 0
}
catch {
    $Motivo = $_.Exception.Message
    $MotivoOriginal = $Motivo
    Write-Host ''
    Write-Host ('ERRO: ' + $Motivo) -ForegroundColor Red
    $Codigo = 1
    if (-not $Mexeu) {
        Write-Host 'NADA FOI ALTERADO (o erro foi antes de parar o sistema).' -ForegroundColor Yellow
        if ($Cfg -and $BancoDe) { Registrar 'ERRO' ('Nao iniciada, nada alterado: ' + $Motivo) }
    } else {
        Passo 'VOLTA AUTOMATICA'
        $Situacao = 'DESFEITA'
        try {
            Stop-Service -Name $Cfg.NomeServico -Force -ErrorAction SilentlyContinue
            (Get-Service $Cfg.NomeServico).WaitForStatus('Stopped', (New-TimeSpan -Seconds 60))
            if ($MexeuBanco) {
                if (-not ($BackupSeg -and (Test-Path -LiteralPath $BackupSeg))) { throw 'sem o backup de seguranca para voltar o banco' }
                Sql 'master' ('ALTER DATABASE [' + $Cfg.Banco + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE') | Out-Null
                try { Sql 'master' ('RESTORE DATABASE [' + $Cfg.Banco + '] FROM DISK = @a WITH REPLACE, CHECKSUM, RECOVERY') @{ '@a' = $BackupSeg } | Out-Null }
                finally { Sql 'master' ('ALTER DATABASE [' + $Cfg.Banco + '] SET MULTI_USER') | Out-Null }
                Write-Host ('Banco voltou ao backup de seguranca (versao ' + [string](Sql $Cfg.Banco 'SELECT SIS.fn_SIS_Versao_Banco()') + ').')
            }
            if ($MexeuPrograma) {
                & robocopy $ProgAnterior $Cfg.PastaPrograma /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
                if ($LASTEXITCODE -ge 8) { throw ('falha ao voltar o programa anterior (robocopy ' + $LASTEXITCODE + ')') }
                Write-Host 'Programa anterior de volta.'
            }
            Start-Service -Name $Cfg.NomeServico
            $S = Esperar-Saude 60 { param($x) $x.versaoBanco -eq $BancoDe -and $x.situacao -ne 'banco_fora' -and $x.situacao -ne 'banco_desatualizado' }
            if (-not $S -or $S.versaoBanco -ne $BancoDe -or $S.situacao -in @('banco_fora', 'banco_desatualizado')) {
                throw ('depois da volta o sistema nao ficou bom: ' + $(if ($S) { $S.situacao + ', banco ' + $S.versaoBanco } else { 'sem resposta' }))
            }
            Write-Host ('Sistema de volta na versao anterior: ' + $S.situacao + ', programa ' + $S.versao + ', banco ' + $S.versaoBanco) -ForegroundColor Yellow
        } catch {
            $Situacao = 'ERRO'
            $Motivo = $Motivo + ' | A VOLTA AUTOMATICA FALHOU: ' + $_.Exception.Message
            Write-Host ('A VOLTA AUTOMATICA FALHOU: ' + $_.Exception.Message) -ForegroundColor Red
            Write-Host ('Chame o Celso. Backup de seguranca: ' + $BackupSeg + '; programa anterior: ' + $ProgAnterior) -ForegroundColor Red
        }
        Registrar $Situacao $Motivo
        Soltar-Trava
        if ($Situacao -eq 'DESFEITA' -and $MexeuBanco) { Backup-Completo-Agora }
        Write-Host ''
        if ($Situacao -eq 'DESFEITA') { Write-Host ('ATUALIZACAO DESFEITA: o sistema voltou para a versao ' + $BancoDe + ' e esta funcionando. Motivo: ' + $MotivoOriginal) -ForegroundColor Yellow }
        else { Write-Host 'ATUALIZACAO COM ERRO E SEM VOLTA AUTOMATICA. Chame o Celso.' -ForegroundColor Red }
    }
    Write-Host ('Registro: ' + $Log)
}
finally {
    Soltar-Trava
    try { Stop-Transcript | Out-Null } catch {}
    try { New-Item -ItemType Directory -Force -Path (Join-Path $PastaConfig 'logs') | Out-Null; Copy-Item -LiteralPath $Log -Destination (Join-Path $PastaConfig 'logs') -Force } catch {}
}
exit $Codigo

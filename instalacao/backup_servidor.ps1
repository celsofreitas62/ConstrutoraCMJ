<#
  SisCMJ - backup do banco no servidor (tarefas agendadas do Windows, conta SYSTEM)
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (20/11/2026) - Criacao (etapa 03d, 3d-B). Instalado e agendado pelo instalar_servico.ps1.
  Modos:
    COMPLETO (diario)    : modo de recuperacao FULL (liga se estiver SIMPLE), BACKUP DATABASE
                           com CHECKSUM + RESTORE VERIFYONLY, copia para a nuvem
                           (BACKUP_PASTA_EXTERNA, guarda BACKUP_NUVEM_MANTER) e apaga os
                           arquivos com mais de BACKUP_DIAS_MANTER dias (nunca o ultimo
                           completo nem os logs depois dele).
    LOG (de hora em hora): BACKUP LOG com CHECKSUM (perda maxima de 1 hora). So depois do
                           primeiro completo.
    TESTE (semanal)      : restaura o ultimo completo + os logs seguintes num banco de
                           teste, DBCC CHECKDB, conta as tabelas e apaga o banco de teste.
  Pastas e prazos vem dos parametros do banco (SIS.Parametro). Cada execucao e registrada
  em SIS.Backup_Execucao (SIS_Backup_Registrar); erro manda e-mail (EMAIL_ADMIN_ALERTA).
  Registro em arquivo: <BACKUP_PASTA>\backup.log.
  SQL Server Express nao aceita COMPRESSION: nao usar.
#>
param(
    [ValidateSet('COMPLETO', 'LOG', 'TESTE')][string]$Modo = 'COMPLETO',
    [string]$Instancia = '.\SQL2025',
    [string]$Banco     = 'SISTEMACMJ'
)
$ErrorActionPreference = 'Stop'
$Inicio = Get-Date
$Pasta = 'C:\SistemaCMJ_Arquivos\Backup'
$ArquivoLog = $null

function Executar([string]$BancoSql, [string]$Comando, [hashtable]$Parametros = @{}, [switch]$Escalar) {
    $Con = New-Object System.Data.SqlClient.SqlConnection("Server=$Instancia;Database=$BancoSql;Integrated Security=SSPI;Application Name=SisCMJ backup")
    $Con.Open()
    try {
        $C = $Con.CreateCommand(); $C.CommandText = $Comando; $C.CommandTimeout = 0
        foreach ($k in $Parametros.Keys) { [void]$C.Parameters.AddWithValue($k, $(if ($null -eq $Parametros[$k]) { [DBNull]::Value } else { $Parametros[$k] })) }
        if ($Escalar) { return $C.ExecuteScalar() } else { [void]$C.ExecuteNonQuery() }
    } finally { $Con.Close() }
}
function Parametro([string]$Chave, [string]$Padrao) {
    $v = [string](Executar $Banco 'SELECT SIS.fn_SIS_Parametro(@c)' @{ '@c' = $Chave } -Escalar)
    if ([string]::IsNullOrWhiteSpace($v)) { return $Padrao } else { return $v.Trim() }
}
function Gravar-Log([string]$Texto) {
    $Linha = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' [' + $Modo + '] ' + $Texto
    if ($ArquivoLog) { Add-Content -LiteralPath $ArquivoLog -Value $Linha -Encoding UTF8 }
    Write-Output $Linha
}
function Registrar([string]$Tipo, [string]$Arquivo, [string]$Situacao, [string]$Mensagem, [decimal]$Mb = 0, [bool]$Nuvem = $false) {
    $Existentes = (Get-ChildItem -LiteralPath $Pasta -File | Where-Object { $_.Extension -in '.bak', '.trn' } | ForEach-Object { $_.FullName }) -join '|'
    Executar $Banco 'EXEC SIS.SIS_Backup_Registrar @Tipo=@t, @Arquivo=@a, @DtInicio=@i, @DtFim=@f, @TamanhoMb=@m, @Situacao=@s, @Mensagem=@g, @CopiaNuvem=@n, @ArquivosExistentes=@e' @{
        '@t' = $Tipo; '@a' = $Arquivo; '@i' = $Inicio; '@f' = (Get-Date); '@m' = $Mb; '@s' = $Situacao; '@g' = $Mensagem; '@n' = $Nuvem; '@e' = $Existentes }
}
function Tamanho([string]$Arq) { return [math]::Round((Get-Item -LiteralPath $Arq).Length / 1MB, 1) }

try {
    $Pasta = Parametro 'BACKUP_PASTA' $Pasta
    New-Item -ItemType Directory -Force -Path $Pasta | Out-Null
    $ArquivoLog = Join-Path $Pasta 'backup.log'
    $Carimbo = Get-Date -Format 'yyyyMMdd_HHmm'

    if ($Modo -eq 'COMPLETO') {
        $Rec = [string](Executar 'master' 'SELECT recovery_model_desc FROM sys.databases WHERE name = @b' @{ '@b' = $Banco } -Escalar)
        if ($Rec -ne 'FULL') { Executar 'master' ("ALTER DATABASE [" + $Banco + "] SET RECOVERY FULL;"); Gravar-Log ('Modo de recuperacao: ' + $Rec + ' -> FULL (backup do log de hora em hora)') }
        $Arq = Join-Path $Pasta ($Banco + '_COMPLETO_' + $Carimbo + '.bak')
        Executar 'master' ("BACKUP DATABASE [" + $Banco + "] TO DISK = @a WITH INIT, CHECKSUM, NAME = @n;") @{ '@a' = $Arq; '@n' = ($Banco + ' completo ' + $Carimbo) }
        Executar 'master' 'RESTORE VERIFYONLY FROM DISK = @a WITH CHECKSUM;' @{ '@a' = $Arq }
        $Mb = Tamanho $Arq
        Gravar-Log ('OK: ' + $Arq + ' (' + $Mb + ' MB, conferido)')

        $Nuvem = $false
        $PastaNuvem = Parametro 'BACKUP_PASTA_EXTERNA' ''
        $NuvemManter = [int](Parametro 'BACKUP_NUVEM_MANTER' '1')
        if ($PastaNuvem -and $NuvemManter -gt 0) {
            New-Item -ItemType Directory -Force -Path $PastaNuvem | Out-Null
            Copy-Item -LiteralPath $Arq -Destination $PastaNuvem -Force
            Get-ChildItem -LiteralPath $PastaNuvem -Filter ($Banco + '_COMPLETO_*.bak') | Sort-Object Name -Descending | Select-Object -Skip $NuvemManter | Remove-Item -Force
            $Nuvem = $true
            Gravar-Log ('Copia na nuvem: ' + $PastaNuvem + ' (guarda ' + $NuvemManter + ')')
        }

        # Retencao: apaga o que passou de BACKUP_DIAS_MANTER, mas nunca o ultimo completo nem os logs depois do completo mais antigo que ficou
        $Dias = [int](Parametro 'BACKUP_DIAS_MANTER' '7')
        $Limite = (Get-Date).AddDays(-$Dias)
        $Completos = @(Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_COMPLETO_*.bak') | Sort-Object Name -Descending)
        $Completos | Select-Object -Skip 1 | Where-Object { $_.LastWriteTime -lt $Limite } | Remove-Item -Force
        $MaisAntigo = Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_COMPLETO_*.bak') | Sort-Object Name | Select-Object -First 1
        if ($MaisAntigo) {
            $Corte = $MaisAntigo.Name.Substring(($Banco + '_COMPLETO_').Length, 13)
            Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_LOG_*.trn') | Where-Object { $_.Name.Substring(($Banco + '_LOG_').Length, 13) -lt $Corte } | Remove-Item -Force
        }
        Registrar 'COMPLETO' $Arq 'OK' ('Conferido (VERIFYONLY).' + $(if ($Nuvem) { ' Copiado para a nuvem.' } else { '' })) $Mb $Nuvem
    }
    elseif ($Modo -eq 'LOG') {
        $Rec = [string](Executar 'master' 'SELECT recovery_model_desc FROM sys.databases WHERE name = @b' @{ '@b' = $Banco } -Escalar)
        $Completo = [int](Executar 'master' "SELECT COUNT(*) FROM msdb.dbo.backupset WHERE database_name = @b AND type = 'D'" @{ '@b' = $Banco } -Escalar)
        if ($Rec -ne 'FULL' -or $Completo -eq 0) { Gravar-Log 'Ainda sem backup completo em modo FULL: backup do log pulado.'; exit 0 }
        $Arq = Join-Path $Pasta ($Banco + '_LOG_' + $Carimbo + '.trn')
        Executar 'master' ("BACKUP LOG [" + $Banco + "] TO DISK = @a WITH INIT, CHECKSUM, NAME = @n;") @{ '@a' = $Arq; '@n' = ($Banco + ' log ' + $Carimbo) }
        $Mb = Tamanho $Arq
        Gravar-Log ('OK: ' + $Arq + ' (' + $Mb + ' MB)')
        Registrar 'LOG' $Arq 'OK' '' $Mb
    }
    else {
        $Teste = $Banco + '_RESTORE_TESTE'
        $Completo = Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_COMPLETO_*.bak') | Sort-Object Name -Descending | Select-Object -First 1
        if (-not $Completo) { throw 'Nenhum backup completo na pasta para testar.' }
        $Desde = $Completo.Name.Substring(($Banco + '_COMPLETO_').Length, 13)
        $Logs = @(Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_LOG_*.trn') | Where-Object { $_.Name.Substring(($Banco + '_LOG_').Length, 13) -ge $Desde } | Sort-Object Name)
        $PastaTeste = Join-Path $Pasta 'teste_restauracao'
        New-Item -ItemType Directory -Force -Path $PastaTeste | Out-Null
        Executar 'master' ("IF DB_ID(N'" + $Teste + "') IS NOT NULL BEGIN ALTER DATABASE [" + $Teste + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [" + $Teste + "]; END;")
        # nomes logicos dos arquivos do backup
        $Con = New-Object System.Data.SqlClient.SqlConnection("Server=$Instancia;Database=master;Integrated Security=SSPI")
        $Con.Open(); $C = $Con.CreateCommand(); $C.CommandText = 'RESTORE FILELISTONLY FROM DISK = @a'; [void]$C.Parameters.AddWithValue('@a', $Completo.FullName)
        $R = $C.ExecuteReader(); $Moves = @(); while ($R.Read()) { $Ext = $(if ($R['Type'] -eq 'L') { '.ldf' } else { '.mdf' }); $Moves += ("MOVE N'" + $R['LogicalName'] + "' TO N'" + (Join-Path $PastaTeste ($Teste + '_' + $R['LogicalName'] + $Ext)) + "'") }; $R.Close(); $Con.Close()
        Executar 'master' ("RESTORE DATABASE [" + $Teste + "] FROM DISK = @a WITH " + ($Moves -join ', ') + ", NORECOVERY, REPLACE, CHECKSUM;") @{ '@a' = $Completo.FullName }
        foreach ($L in $Logs) { Executar 'master' ("RESTORE LOG [" + $Teste + "] FROM DISK = @a WITH NORECOVERY, CHECKSUM;") @{ '@a' = $L.FullName } }
        Executar 'master' ("RESTORE DATABASE [" + $Teste + "] WITH RECOVERY;")
        Executar $Teste 'DBCC CHECKDB WITH NO_INFOMSGS;'
        $Tabelas = [int](Executar $Teste 'SELECT COUNT(*) FROM sys.tables' -Escalar)
        $Versao = [string](Executar $Teste 'SELECT SIS.fn_SIS_Versao_Banco()' -Escalar)
        Executar 'master' ("ALTER DATABASE [" + $Teste + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [" + $Teste + "];")
        $Msg = 'Restaurado ' + $Completo.Name + ' + ' + $Logs.Count + ' backup(s) do log; DBCC CHECKDB sem erros; ' + $Tabelas + ' tabelas; versao do banco ' + $Versao + '. Banco de teste apagado.'
        Gravar-Log ('OK: ' + $Msg)
        Registrar 'TESTE' $Completo.FullName 'OK' $Msg
    }
    exit 0
}
catch {
    $Erro = $_.Exception.Message
    Gravar-Log ('ERRO: ' + $Erro)
    try { Registrar $(if ($Modo -eq 'COMPLETO') { 'COMPLETO' } elseif ($Modo -eq 'LOG') { 'LOG' } else { 'TESTE' }) '' 'ERRO' $Erro } catch { Gravar-Log ('ERRO ao registrar no banco: ' + $_.Exception.Message) }
    exit 1
}

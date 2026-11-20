<#
  SisCMJ - backup e restauracao do banco no servidor (tarefas agendadas do Windows, conta SYSTEM)
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (20/11/2026) - Criacao (etapa 03d, 3d-B). Instalado e agendado pelo instalar_servico.ps1.
  v1.1 (20/11/2026) - Etapa 03d2: modo RESTAURAR (pedidos feitos pela tela Sistema > Backups);
                      trava unica entre os modos (um backup/restauracao por vez); depois de
                      restaurar faz um completo novo (base nova para os logs seguintes).
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
    RESTAURAR (a cada minuto): pega o pedido pendente (SIS_Backup_Restauracao_Capturar); sem
                           pedido, sai sem registrar nada. Com pedido:
                             1) confere os arquivos do plano (existem, RESTORE VERIFYONLY);
                             2) para o servico do SisCMJ (-Servico) e poe o banco em SINGLE_USER;
                             3) backup de SEGURANCA (completo COPY_ONLY) e o final do log
                                (tail, WITH NORECOVERY), para dar para desfazer;
                             4) restaura o completo e os logs; o ultimo com STOPAT (dia e hora);
                             5) MULTI_USER; registra de novo os backups que o banco restaurado
                                nao conhece (pelo msdb); faz um completo novo;
                             6) religa o servico e grava o resultado com o mesmo numero do
                                pedido (SIS_Backup_Restauracao_Resultado), que manda os e-mails.
                           Erro: tenta deixar o banco on-line (RECOVERY; se nao der, volta o
                           backup de seguranca), religa o servico e grava ERRO.
  Pastas e prazos vem dos parametros do banco (SIS.Parametro). Cada backup e registrado
  em SIS.Backup_Execucao (SIS_Backup_Registrar); erro manda e-mail (EMAIL_ADMIN_ALERTA).
  Registro em arquivo: <BACKUP_PASTA>\backup.log.
  SQL Server Express nao aceita COMPRESSION: nao usar.
#>
param(
    [ValidateSet('COMPLETO', 'LOG', 'TESTE', 'RESTAURAR')][string]$Modo = 'COMPLETO',
    [string]$Instancia = '.\SQL2025',
    [string]$Banco     = 'SISTEMACMJ',
    [string]$Servico   = 'SisCMJ'
)
$ErrorActionPreference = 'Stop'
$Inicio = Get-Date
$Pasta = 'C:\SistemaCMJ_Arquivos\Backup'
$ArquivoLog = $null
$Trava = $null

function Executar([string]$BancoSql, [string]$Comando, [hashtable]$Parametros = @{}, [switch]$Escalar, [switch]$Tabela) {
    $Con = New-Object System.Data.SqlClient.SqlConnection("Server=$Instancia;Database=$BancoSql;Integrated Security=SSPI;Pooling=false;Application Name=SisCMJ backup")
    $Con.Open()
    try {
        $C = $Con.CreateCommand(); $C.CommandText = $Comando; $C.CommandTimeout = 0
        foreach ($k in $Parametros.Keys) { [void]$C.Parameters.AddWithValue($k, $(if ($null -eq $Parametros[$k]) { [DBNull]::Value } else { $Parametros[$k] })) }
        if ($Escalar) { return $C.ExecuteScalar() }
        if ($Tabela) { $T = New-Object System.Data.DataTable; $T.Load($C.ExecuteReader()); return ,$T }
        [void]$C.ExecuteNonQuery()
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
function Existentes() { return (Get-ChildItem -LiteralPath $Pasta -File | Where-Object { $_.Extension -in '.bak', '.trn' } | ForEach-Object { $_.FullName }) -join '|' }
function Registrar([string]$Tipo, [string]$Arquivo, [string]$Situacao, [string]$Mensagem, [decimal]$Mb = 0, [bool]$Nuvem = $false, $DtInicio = $Inicio, $DtFim = (Get-Date)) {
    Executar $Banco 'EXEC SIS.SIS_Backup_Registrar @Tipo=@t, @Arquivo=@a, @DtInicio=@i, @DtFim=@f, @TamanhoMb=@m, @Situacao=@s, @Mensagem=@g, @CopiaNuvem=@n, @ArquivosExistentes=@e' @{
        '@t' = $Tipo; '@a' = $Arquivo; '@i' = $DtInicio; '@f' = $DtFim; '@m' = $Mb; '@s' = $Situacao; '@g' = $Mensagem; '@n' = $Nuvem; '@e' = (Existentes) }
}
function Tamanho([string]$Arq) { return [math]::Round((Get-Item -LiteralPath $Arq).Length / 1MB, 1) }
function Travar([int]$Minutos) {
    # uma trava por banco para todos os modos: backup e restauracao nunca rodam juntos
    $script:Trava = New-Object System.Threading.Mutex($false, ('Global\SisCMJ_Backup_' + $Banco))
    try { $ok = $script:Trava.WaitOne([TimeSpan]::FromMinutes($Minutos)) } catch [System.Threading.AbandonedMutexException] { $ok = $true }
    if (-not $ok) { throw ('Outro backup ou restauracao ainda esta rodando ha mais de ' + $Minutos + ' minutos.') }
}
function Estado-Banco() { return [string](Executar 'master' 'SELECT state_desc FROM sys.databases WHERE name = @b' @{ '@b' = $Banco } -Escalar) }

function Fazer-Completo() {
    $Rec = [string](Executar 'master' 'SELECT recovery_model_desc FROM sys.databases WHERE name = @b' @{ '@b' = $Banco } -Escalar)
    if ($Rec -ne 'FULL') { Executar 'master' ("ALTER DATABASE [" + $Banco + "] SET RECOVERY FULL;"); Gravar-Log ('Modo de recuperacao: ' + $Rec + ' -> FULL (backup do log de hora em hora)') }
    $InicioCompleto = Get-Date
    $Carimbo = Get-Date -Format 'yyyyMMdd_HHmmss'
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
    $Completos = @(Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_COMPLETO_*.bak') | Sort-Object LastWriteTime -Descending)
    $Completos | Select-Object -Skip 1 | Where-Object { $_.LastWriteTime -lt $Limite } | Remove-Item -Force
    Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_SEGURANCA_*.bak') | Where-Object { $_.LastWriteTime -lt $Limite } | Remove-Item -Force
    $MaisAntigo = Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_COMPLETO_*.bak') | Sort-Object LastWriteTime | Select-Object -First 1
    if ($MaisAntigo) {
        Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_LOG_*.trn') | Where-Object { $_.LastWriteTime -lt $MaisAntigo.LastWriteTime.AddMinutes(-1) } | Remove-Item -Force
    }
    Registrar 'COMPLETO' $Arq 'OK' ('Conferido (VERIFYONLY).' + $(if ($Nuvem) { ' Copiado para a nuvem.' } else { '' })) $Mb $Nuvem $InicioCompleto (Get-Date)
    return $Arq
}

function Registrar-Faltantes() {
    # backups deste banco que estao na pasta (msdb) e que o banco restaurado nao conhece
    $Conhecidos = @{}
    foreach ($r in (Executar $Banco 'SELECT ARQUIVO FROM SIS.Backup_Execucao' -Tabela).Rows) { $Conhecidos[[string]$r.ARQUIVO] = 1 }
    $Lista = Executar 'msdb' @"
SELECT m.physical_device_name AS ARQUIVO, b.type AS TIPO, b.is_copy_only AS COPIA, b.backup_start_date AS INICIO, b.backup_finish_date AS FIM,
       CAST(b.backup_size / 1048576.0 AS DECIMAL(12,1)) AS MB
FROM dbo.backupset b
INNER JOIN dbo.backupmediafamily m ON m.media_set_id = b.media_set_id
WHERE b.database_name = @b AND b.type IN ('D', 'L') AND b.backup_start_date >= DATEADD(DAY, -60, GETDATE())
ORDER BY b.backup_start_date
"@ @{ '@b' = $Banco } -Tabela
    $Qtd = 0
    foreach ($r in $Lista.Rows) {
        $Arq = [string]$r.ARQUIVO
        if ($Conhecidos.ContainsKey($Arq) -or -not $Arq.StartsWith($Pasta, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $Arq)) { continue }
        $Tipo = if ([string]$r.TIPO -eq 'L') { 'LOG' } elseif ([bool]$r.COPIA) { 'SEGURANCA' } else { 'COMPLETO' }
        Registrar $Tipo $Arq 'OK' 'Registrado de novo depois da restauracao (msdb).' ([decimal]$r.MB) $false ([datetime]$r.INICIO) ([datetime]$r.FIM)
        $Conhecidos[$Arq] = 1
        $Qtd++
    }
    return $Qtd
}

function Restaurar() {
    $Plano = Executar $Banco 'EXEC SIS.SIS_Backup_Restauracao_Capturar' -Tabela
    if ($Plano.Rows.Count -eq 0) { return }     # sem pedido: nao registra nada

    $P = $Plano.Rows[0]
    $Id = [int]$P.ID_RESTAURACAO
    $script:Pedido = $P
    $script:IdPedido = $Id
    $DtPonto = if ($P.DT_PONTO -is [DBNull]) { $null } else { [datetime]$P.DT_PONTO }
    $Arquivos = @($Plano.Rows | Sort-Object { [int]$_.ORDEM })
    $script:ArquivoBase = [string]$Arquivos[0].ARQUIVO
    $script:TextoPlano = ($Arquivos | ForEach-Object { [string]$_.ORDEM + ': ' + [string]$_.ARQUIVO }) -join ' | '
    Gravar-Log ('Pedido ' + $Id + ' de ' + $P.USUARIO_PEDIDO + ': voltar para ' + $(if ($DtPonto) { $DtPonto.ToString('dd/MM/yyyy HH:mm') } else { 'o backup ' + $script:ArquivoBase }) + '. Motivo: ' + $P.MOTIVO)

    # 1) arquivos do plano existem e estao bons (antes de tirar o sistema do ar)
    foreach ($A in $Arquivos) {
        if (-not (Test-Path -LiteralPath ([string]$A.ARQUIVO))) { throw ('Arquivo do plano nao existe: ' + $A.ARQUIVO) }
        Executar 'master' 'RESTORE VERIFYONLY FROM DISK = @a WITH CHECKSUM;' @{ '@a' = [string]$A.ARQUIVO }
    }
    Gravar-Log ('Plano conferido: ' + $Arquivos.Count + ' arquivo(s).')

    # 2) servico parado e banco so para este script
    $Svc = Get-Service -Name $Servico -ErrorAction SilentlyContinue
    if ($Svc -and $Svc.Status -ne 'Stopped') {
        Stop-Service -Name $Servico -Force
        $Svc.WaitForStatus('Stopped', (New-TimeSpan -Seconds 90))
        $script:ServicoParado = $true
        Gravar-Log ('Servico ' + $Servico + ' parado.')
    }
    Executar 'master' ("ALTER DATABASE [" + $Banco + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;")
    $script:SingleUser = $true

    # 3) seguranca: completo COPY_ONLY + final do log (deixa o banco em RESTORING)
    $Carimbo = Get-Date -Format 'yyyyMMdd_HHmmss'
    $Seg = Join-Path $Pasta ($Banco + '_SEGURANCA_' + $Carimbo + '.bak')
    Executar 'master' ("BACKUP DATABASE [" + $Banco + "] TO DISK = @a WITH INIT, CHECKSUM, COPY_ONLY, NAME = @n;") @{ '@a' = $Seg; '@n' = ($Banco + ' seguranca pedido ' + $Id) }
    Executar 'master' 'RESTORE VERIFYONLY FROM DISK = @a WITH CHECKSUM;' @{ '@a' = $Seg }
    $script:ArquivoSeguranca = $Seg
    Gravar-Log ('Backup de seguranca: ' + $Seg + ' (' + (Tamanho $Seg) + ' MB, conferido)')
    $Tail = Join-Path $Pasta ($Banco + '_LOG_' + $Carimbo + '.trn')
    Executar 'master' ("BACKUP LOG [" + $Banco + "] TO DISK = @a WITH INIT, CHECKSUM, NORECOVERY, NAME = @n;") @{ '@a' = $Tail; '@n' = ($Banco + ' final do log pedido ' + $Id) }
    $script:EmRestauracao = $true
    Gravar-Log ('Final do log: ' + $Tail)

    # 4) restauracao
    $Ultimo = $Arquivos.Count - 1
    for ($i = 0; $i -le $Ultimo; $i++) {
        $A = [string]$Arquivos[$i].ARQUIVO
        if ($i -eq 0) {
            Executar 'master' ("RESTORE DATABASE [" + $Banco + "] FROM DISK = @a WITH REPLACE, CHECKSUM, NORECOVERY;") @{ '@a' = $A }
        } elseif ($i -eq $Ultimo -and $DtPonto) {
            Executar 'master' ("RESTORE LOG [" + $Banco + "] FROM DISK = @a WITH CHECKSUM, NORECOVERY, STOPAT = @p;") @{ '@a' = $A; '@p' = $DtPonto }
        } else {
            Executar 'master' ("RESTORE LOG [" + $Banco + "] FROM DISK = @a WITH CHECKSUM, NORECOVERY;") @{ '@a' = $A }
        }
        Gravar-Log ('Aplicado: ' + $A)
    }
    Executar 'master' ("RESTORE DATABASE [" + $Banco + "] WITH RECOVERY;")
    $script:EmRestauracao = $false
    Executar 'master' ("ALTER DATABASE [" + $Banco + "] SET MULTI_USER;")
    $script:SingleUser = $false
    $Versao = [string](Executar $Banco 'SELECT SIS.fn_SIS_Versao_Banco()' -Escalar)
    Gravar-Log ('Banco restaurado e on-line (versao ' + $Versao + ').')

    # 5) backups que o banco restaurado nao conhece + completo novo (base dos proximos logs)
    $Qtd = Registrar-Faltantes
    if ($Qtd -gt 0) { Gravar-Log ('Registrados de novo ' + $Qtd + ' backup(s) do msdb.') }
    $Novo = Fazer-Completo

    # 6) servico de volta e resultado
    if ($script:ServicoParado) { Start-Service -Name $Servico; $script:ServicoParado = $false; Gravar-Log ('Servico ' + $Servico + ' religado.') }
    $Msg = 'Restaurado ' + $(if ($DtPonto) { 'ate ' + $DtPonto.ToString('dd/MM/yyyy HH:mm') } else { 'o backup ' + (Split-Path $script:ArquivoBase -Leaf) }) +
           ' (' + $Arquivos.Count + ' arquivo(s)); versao do banco ' + $Versao + '; backup completo novo: ' + (Split-Path $Novo -Leaf) + '.'
    Gravar-Resultado 'OK' $Msg
    Gravar-Log ('OK: ' + $Msg)
}

function Gravar-Resultado([string]$Situacao, [string]$Mensagem) {
    $P = $script:Pedido
    Executar $Banco @"
EXEC SIS.SIS_Backup_Restauracao_Resultado @IdRestauracao=@id, @Situacao=@s, @Mensagem=@m, @TipoPonto=@tp, @ArquivoBackup=@ab, @DtPonto=@dp,
     @Motivo=@mo, @IdUsuarioPedido=@iu, @UsuarioPedido=@us, @DtPedido=@dtp, @DtInicio=@dti, @Plano=@pl, @ArquivoSeguranca=@seg
"@ @{ '@id' = $script:IdPedido; '@s' = $Situacao; '@m' = $Mensagem; '@tp' = [string]$P.TIPO_PONTO;
      '@ab' = $(if ([string]$P.TIPO_PONTO -eq 'BACKUP') { $script:ArquivoBase } else { $null }); '@dp' = $(if ($P.DT_PONTO -is [DBNull]) { $null } else { $P.DT_PONTO });
      '@mo' = [string]$P.MOTIVO; '@iu' = [int]$P.ID_USUARIO_PEDIDO; '@us' = [string]$P.USUARIO_PEDIDO; '@dtp' = $P.DT_PEDIDO; '@dti' = $P.DT_INICIO;
      '@pl' = $script:TextoPlano; '@seg' = $script:ArquivoSeguranca }
}

function Socorrer-Restauracao([string]$Erro) {
    # deixa o banco on-line de qualquer jeito, religa o servico e grava o ERRO
    $Notas = @()
    try {
        if ((Estado-Banco) -ne 'ONLINE') {
            try { Executar 'master' ("RESTORE DATABASE [" + $Banco + "] WITH RECOVERY;"); $Notas += 'banco recuperado (RECOVERY)' }
            catch {
                if ($script:ArquivoSeguranca -and (Test-Path -LiteralPath $script:ArquivoSeguranca)) {
                    Executar 'master' ("RESTORE DATABASE [" + $Banco + "] FROM DISK = @a WITH REPLACE, CHECKSUM, RECOVERY;") @{ '@a' = $script:ArquivoSeguranca }
                    $Notas += 'banco voltou ao backup de seguranca (como estava antes do pedido)'
                } else { $Notas += 'BANCO FORA DO AR: restaure manualmente' }
            }
        }
        if ((Estado-Banco) -eq 'ONLINE') { Executar 'master' ("ALTER DATABASE [" + $Banco + "] SET MULTI_USER;") }
    } catch { $Notas += ('falha ao recuperar o banco: ' + $_.Exception.Message) }
    try { if ($script:ServicoParado) { Start-Service -Name $Servico; $Notas += 'servico religado' } } catch { $Notas += ('falha ao religar o servico: ' + $_.Exception.Message) }
    $Msg = 'Erro: ' + $Erro + $(if ($Notas.Count) { ' | ' + ($Notas -join '; ') } else { '' })
    Gravar-Log ('ERRO: ' + $Msg)
    try { if ((Estado-Banco) -eq 'ONLINE') { [void](Registrar-Faltantes) } } catch { }
    try { Gravar-Resultado 'ERRO' $Msg } catch { Gravar-Log ('ERRO ao gravar o resultado no banco: ' + $_.Exception.Message) }
}

try {
    $Pasta = Parametro 'BACKUP_PASTA' $Pasta
    New-Item -ItemType Directory -Force -Path $Pasta | Out-Null
    $ArquivoLog = Join-Path $Pasta 'backup.log'

    if ($Modo -eq 'RESTAURAR') {
        # roda a cada minuto: sem pedido pendente, sai sem tocar em nada
        $Pendentes = [int](Executar $Banco "SELECT COUNT(*) FROM SIS.Backup_Restauracao WHERE SITUACAO = 'PENDENTE'" -Escalar)
        if ($Pendentes -eq 0) { exit 0 }
        Travar 10
        $script:IdPedido = $null
        try { Restaurar }
        catch {
            if ($script:IdPedido) { Socorrer-Restauracao $_.Exception.Message; exit 1 }
            throw
        }
        exit 0
    }

    Travar 30
    $Carimbo = Get-Date -Format 'yyyyMMdd_HHmm'
    if ($Modo -eq 'COMPLETO') {
        [void](Fazer-Completo)
    }
    elseif ($Modo -eq 'LOG') {
        $Rec = [string](Executar 'master' 'SELECT recovery_model_desc FROM sys.databases WHERE name = @b' @{ '@b' = $Banco } -Escalar)
        $Completo = [int](Executar 'master' "SELECT COUNT(*) FROM msdb.dbo.backupset WHERE database_name = @b AND type = 'D' AND is_copy_only = 0" @{ '@b' = $Banco } -Escalar)
        if ($Rec -ne 'FULL' -or $Completo -eq 0) { Gravar-Log 'Ainda sem backup completo em modo FULL: backup do log pulado.'; exit 0 }
        $Arq = Join-Path $Pasta ($Banco + '_LOG_' + $Carimbo + '.trn')
        Executar 'master' ("BACKUP LOG [" + $Banco + "] TO DISK = @a WITH INIT, CHECKSUM, NAME = @n;") @{ '@a' = $Arq; '@n' = ($Banco + ' log ' + $Carimbo) }
        $Mb = Tamanho $Arq
        Gravar-Log ('OK: ' + $Arq + ' (' + $Mb + ' MB)')
        Registrar 'LOG' $Arq 'OK' '' $Mb
    }
    else {
        $Teste = $Banco + '_RESTORE_TESTE'
        $Completo = Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_COMPLETO_*.bak') | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $Completo) { throw 'Nenhum backup completo na pasta para testar.' }
        $Logs = @(Get-ChildItem -LiteralPath $Pasta -Filter ($Banco + '_LOG_*.trn') | Where-Object { $_.LastWriteTime -gt $Completo.LastWriteTime } | Sort-Object LastWriteTime)
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
    if ($Modo -eq 'RESTAURAR') { exit 1 }
    try { Registrar $(if ($Modo -eq 'COMPLETO') { 'COMPLETO' } elseif ($Modo -eq 'LOG') { 'LOG' } else { 'TESTE' }) '' 'ERRO' $Erro } catch { Gravar-Log ('ERRO ao registrar no banco: ' + $_.Exception.Message) }
    exit 1
}
finally {
    if ($Trava) { try { $Trava.ReleaseMutex() } catch { } ; $Trava.Dispose() }
}

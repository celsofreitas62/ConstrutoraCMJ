<#
  SistemaCMJ - teste de restauracao do backup (fase 3d, antecipado em 20/11/2026)
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (20/11/2026) - Criacao: restaura o backup mais recente num banco de teste,
                      roda DBCC CHECKDB, compara a quantidade de linhas de cada tabela
                      com o banco original e apaga o banco de teste.
  Rodar logo depois do backup (se alguem usar o sistema no meio, as contagens mudam).
#>
param(
    [string]$Instancia  = '.\SQL2025',
    [string]$Banco      = 'SISTEMACMJ_LOCAL',
    [string]$PastaLocal = 'C:\Backup_SisCMJ'
)
$ErrorActionPreference = 'Stop'
$BancoTeste = $Banco + '_RESTORE_TESTE'
$PastaTeste = Join-Path $PastaLocal 'teste'
New-Item -ItemType Directory -Force -Path $PastaTeste | Out-Null
$ArquivoLog = Join-Path $PastaLocal 'backup.log'

function Gravar-Log([string]$Texto) {
    $Linha = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' [TESTE] ' + $Texto
    Add-Content -LiteralPath $ArquivoLog -Value $Linha -Encoding UTF8
    Write-Output $Linha
}

function Consultar-Sql([string]$Sql, [string]$Base = 'master') {
    $Conexao = New-Object System.Data.SqlClient.SqlConnection("Server=$Instancia;Database=$Base;Integrated Security=SSPI")
    $Conexao.Open()
    try {
        $Comando = $Conexao.CreateCommand()
        $Comando.CommandText = $Sql
        $Comando.CommandTimeout = 0
        $Tabela = New-Object System.Data.DataTable
        $Leitor = $Comando.ExecuteReader()
        $Tabela.Load($Leitor)
        return ,$Tabela
    } finally { $Conexao.Close() }
}

$SqlContagem = @"
SELECT s.name + '.' + t.name AS TABELA, SUM(p.rows) AS LINHAS
FROM sys.tables t
INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY s.name, t.name
"@

try {
    $Ultimo = Get-ChildItem -LiteralPath $PastaLocal -Filter ($Banco + '_*.bak') | Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $Ultimo) { throw "Nenhum backup encontrado em $PastaLocal" }
    Gravar-Log ("Restaurando " + $Ultimo.Name + " como " + $BancoTeste)

    $Arquivos = Consultar-Sql ("RESTORE FILELISTONLY FROM DISK = N'" + $Ultimo.FullName + "';")
    $Moves = @()
    foreach ($Linha in $Arquivos.Rows) {
        $Extensao = if ($Linha.Type -eq 'L') { '.ldf' } else { '.mdf' }
        $Destino = Join-Path $PastaTeste ($BancoTeste + '_' + $Linha.LogicalName + $Extensao)
        $Moves += ("MOVE N'" + $Linha.LogicalName + "' TO N'" + $Destino + "'")
    }

    [void](Consultar-Sql ("IF DB_ID(N'" + $BancoTeste + "') IS NOT NULL BEGIN ALTER DATABASE [" + $BancoTeste + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [" + $BancoTeste + "]; END;"))
    [void](Consultar-Sql ("RESTORE DATABASE [" + $BancoTeste + "] FROM DISK = N'" + $Ultimo.FullName + "' WITH " + ($Moves -join ', ') + ", CHECKSUM, RECOVERY;"))
    Gravar-Log "OK: banco restaurado"

    [void](Consultar-Sql ("DBCC CHECKDB (N'" + $BancoTeste + "') WITH NO_INFOMSGS;"))
    Gravar-Log "OK: DBCC CHECKDB sem erros"

    $Original = @{}
    foreach ($L in (Consultar-Sql $SqlContagem $Banco).Rows) { $Original[$L.TABELA] = [int64]$L.LINHAS }
    $Restaurado = @{}
    foreach ($L in (Consultar-Sql $SqlContagem $BancoTeste).Rows) { $Restaurado[$L.TABELA] = [int64]$L.LINHAS }

    $Diferencas = @()
    foreach ($T in $Original.Keys) {
        $R = if ($Restaurado.ContainsKey($T)) { $Restaurado[$T] } else { -1 }
        if ($R -ne $Original[$T]) { $Diferencas += ($T + ': original ' + $Original[$T] + ', backup ' + $R) }
    }
    $TotalLinhas = ($Restaurado.Values | Measure-Object -Sum).Sum
    Gravar-Log ("Tabelas: " + $Restaurado.Count + " | linhas no backup: " + $TotalLinhas + " | tabelas com diferenca: " + $Diferencas.Count)
    foreach ($D in ($Diferencas | Select-Object -First 20)) { Gravar-Log ("  diferenca: " + $D) }

    [void](Consultar-Sql ("ALTER DATABASE [" + $BancoTeste + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [" + $BancoTeste + "];"))
    Gravar-Log "OK: banco de teste apagado"

    if ($Diferencas.Count -eq 0) { Gravar-Log "RESULTADO: RESTAURACAO OK" } else { Gravar-Log "RESULTADO: restaurou, mas ha diferencas (alguem usou o sistema depois do backup?)" }
    exit 0
}
catch {
    Gravar-Log ("ERRO: " + $_.Exception.Message)
    exit 1
}

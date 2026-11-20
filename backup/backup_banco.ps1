<#
  SistemaCMJ - backup do banco (fase 3d, antecipado em 20/11/2026)
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (20/11/2026) - Criacao: BACKUP com CHECKSUM + RESTORE VERIFYONLY,
                      guarda os ultimos N na pasta local e copia para a pasta da nuvem.
  Uso: chamado pela tarefa agendada "SistemaCMJ - Backup do banco".
  No servidor da CMJ (3d): mudar os parametros (-Instancia, -Banco, pastas).
  Obs.: SQL Server Express nao aceita COMPRESSION; nao usar.
#>
param(
    [string]$Instancia   = '.\SQL2025',
    [string]$Banco       = 'SISTEMACMJ_LOCAL',
    [string]$PastaLocal  = 'C:\Backup_SisCMJ',
    [string]$PastaNuvem  = 'C:\Recover SistemaCMJ\backup_db',
    [int]$ManterLocal    = 7,
    [int]$ManterNuvem    = 3
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $PastaLocal | Out-Null
$ArquivoLog = Join-Path $PastaLocal 'backup.log'

function Gravar-Log([string]$Texto) {
    $Linha = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Texto
    Add-Content -LiteralPath $ArquivoLog -Value $Linha -Encoding UTF8
    Write-Output $Linha
}

function Executar-Sql([string]$Sql) {
    $Conexao = New-Object System.Data.SqlClient.SqlConnection("Server=$Instancia;Database=master;Integrated Security=SSPI")
    $Conexao.Open()
    try {
        $Comando = $Conexao.CreateCommand()
        $Comando.CommandText = $Sql
        $Comando.CommandTimeout = 0
        [void]$Comando.ExecuteNonQuery()
    } finally { $Conexao.Close() }
}

$Status = Join-Path $PastaLocal 'ULTIMO_BACKUP.txt'
try {
    $Carimbo = Get-Date -Format 'yyyyMMdd_HHmm'
    $Arquivo = Join-Path $PastaLocal ($Banco + '_' + $Carimbo + '.bak')

    Gravar-Log ("Inicio do backup de " + $Banco + " -> " + $Arquivo)
    Executar-Sql ("BACKUP DATABASE [" + $Banco + "] TO DISK = N'" + $Arquivo + "' WITH INIT, CHECKSUM, NAME = N'" + $Banco + " " + $Carimbo + "';")
    Executar-Sql ("RESTORE VERIFYONLY FROM DISK = N'" + $Arquivo + "' WITH CHECKSUM;")
    $TamanhoMB = [math]::Round((Get-Item -LiteralPath $Arquivo).Length / 1MB, 1)
    Gravar-Log ("OK: backup gravado e conferido (" + $TamanhoMB + " MB)")

    Get-ChildItem -LiteralPath $PastaLocal -Filter ($Banco + '_*.bak') |
        Sort-Object Name -Descending | Select-Object -Skip $ManterLocal |
        Remove-Item -Force

    if ($PastaNuvem -ne '') {
        New-Item -ItemType Directory -Force -Path $PastaNuvem | Out-Null
        Copy-Item -LiteralPath $Arquivo -Destination $PastaNuvem -Force
        Get-ChildItem -LiteralPath $PastaNuvem -Filter ($Banco + '_*.bak') |
            Sort-Object Name -Descending | Select-Object -Skip $ManterNuvem |
            Remove-Item -Force
        Gravar-Log ("OK: copia enviada para " + $PastaNuvem)
    }

    Set-Content -LiteralPath $Status -Encoding UTF8 -Value ("OK " + (Get-Date -Format 'dd/MM/yyyy HH:mm') + " - " + (Split-Path $Arquivo -Leaf) + " (" + $TamanhoMB + " MB)")
    if ($PastaNuvem -ne '') { Copy-Item -LiteralPath $Status -Destination $PastaNuvem -Force }
    exit 0
}
catch {
    Gravar-Log ("ERRO: " + $_.Exception.Message)
    Set-Content -LiteralPath $Status -Encoding UTF8 -Value ("ERRO " + (Get-Date -Format 'dd/MM/yyyy HH:mm') + " - " + $_.Exception.Message)
    try { if ($PastaNuvem -ne '') { Copy-Item -LiteralPath $Status -Destination $PastaNuvem -Force } } catch { }
    exit 1
}

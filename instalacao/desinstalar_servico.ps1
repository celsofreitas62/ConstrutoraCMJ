<#
  SisCMJ - remove o servico (para ensaio ou reinstalacao limpa)
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (20/11/2026) - Criacao (etapa 03d). Rodar pelo desinstalar_servico.cmd, como administrador.
  Remove: servico, regra do Firewall e o programa. NAO apaga o banco nem os arquivos do sistema.
  Opcionais: -RemoverLoginSql (login do servico no SQL), -RemoverCertificado, -RemoverConfiguracao.
#>
param(
    [string]$NomeServico   = 'SisCMJ',
    [string]$PastaPrograma = 'C:\SisCMJ\programa',
    [string]$Instancia     = '.\SQL2025',
    [string]$Banco         = 'SISTEMACMJ',
    [switch]$RemoverLoginSql,
    [switch]$RemoverCertificado,
    [switch]$RemoverConfiguracao
)
$ErrorActionPreference = 'Continue'
$Conta = 'NT SERVICE\' + $NomeServico
if (Get-Service -Name $NomeServico -ErrorAction SilentlyContinue) {
    Stop-Service -Name $NomeServico -Force -ErrorAction SilentlyContinue
    & sc.exe delete $NomeServico | Out-Host
}
Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like ('SisCMJ (' + $NomeServico + ')*') } | Remove-NetFirewallRule
if (Test-Path -LiteralPath $PastaPrograma) { Remove-Item -LiteralPath $PastaPrograma -Recurse -Force }
if ($RemoverLoginSql) {
    foreach ($par in @(@($Banco, "IF DATABASE_PRINCIPAL_ID(N'$Conta') IS NOT NULL DROP USER [$Conta];"), @('master', "IF SUSER_ID(N'$Conta') IS NOT NULL DROP LOGIN [$Conta];"))) {
        $Con = New-Object System.Data.SqlClient.SqlConnection("Server=$Instancia;Database=$($par[0]);Integrated Security=SSPI")
        $Con.Open(); $C = $Con.CreateCommand(); $C.CommandText = $par[1]; [void]$C.ExecuteNonQuery(); $Con.Close()
    }
}
if ($RemoverCertificado) {
    Get-ChildItem Cert:\LocalMachine\My, Cert:\LocalMachine\Root | Where-Object { $_.Subject -eq 'CN=SisCMJ' } | Remove-Item
}
if ($RemoverConfiguracao) { Remove-Item -LiteralPath (Join-Path $env:ProgramData 'SisCMJ') -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host 'Servico removido.'

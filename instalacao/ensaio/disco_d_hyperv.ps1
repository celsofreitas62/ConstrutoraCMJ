<#
  disco_d_hyperv.ps1 - SistemaCMJ, 3d-C (21/11/2026)
  Acrescenta um 2o disco (30 GB, cresce com o uso) na VM do ensaio, para simular
  o HD de 1 TB do servidor da CMJ (backups em D:\SisCMJ_Backup).
  Pode rodar com a VM ligada (controladora SCSI da geracao 2).
#>
$Nome = 'SisCMJ-Servidor-Ensaio'
$ErrorActionPreference = 'Stop'
try {
    $Vhd = "C:\HyperV\$Nome\$Nome-Backup.vhdx"
    if (Test-Path $Vhd) { throw "O disco $Vhd ja existe" }
    New-VHD -Path $Vhd -SizeBytes 30GB -Dynamic | Out-Null
    Add-VMHardDiskDrive -VMName $Nome -ControllerType SCSI -Path $Vhd
    Write-Host "Disco de backup ligado na VM: $Vhd (30 GB)"
    Write-Host 'RESULTADO: OK'
}
catch { Write-Host "ERRO: $($_.Exception.Message)"; Write-Host 'RESULTADO: COM ERROS' }

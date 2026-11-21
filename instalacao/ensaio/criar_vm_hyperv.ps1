<#
  criar_vm_hyperv.ps1 - SistemaCMJ, etapa 3d-C (21/11/2026)
  Cria a maquina virtual "SisCMJ-Servidor-Ensaio" no Hyper-V do notebook do Celso,
  para ensaiar o Roteiro_Instalacao_Servidor.md num Windows limpo.
  Rede: "Default Switch" (rede interna do Hyper-V; nao altera a rede do notebook).
  Executar pelo criar_vm_hyperv.cmd, como administrador.
  Registro: criar_vm_hyperv.log (mesma pasta).
#>
$ErrorActionPreference = 'Stop'
$Log = Join-Path $PSScriptRoot 'criar_vm_hyperv.log'
Start-Transcript -Path $Log -Force | Out-Null
try {
    $Nome   = 'SisCMJ-Servidor-Ensaio'
    $Switch = 'Default Switch'
    $Pasta  = 'C:\HyperV'
    $Usuario = (Get-CimInstance Win32_ComputerSystem).UserName.Split('\')[-1]
    $Downloads = "C:\Users\$Usuario\Downloads"
    $Iso = Get-ChildItem -Path $Downloads -Filter '*CLIENTENTERPRISEEVAL*pt-br.iso' | Select-Object -First 1
    if (-not $Iso) { throw "ISO do Windows nao encontrado em $Downloads" }
    Write-Host "ISO: $($Iso.FullName)"
    if (-not (Get-VMSwitch -Name $Switch -ErrorAction SilentlyContinue)) { throw "Rede '$Switch' nao encontrada (Hyper-V ativo e notebook reiniciado?)" }
    if (Get-VM -Name $Nome -ErrorAction SilentlyContinue) { throw "A maquina '$Nome' ja existe no Hyper-V" }
    New-Item -ItemType Directory -Path $Pasta -Force | Out-Null
    $Vhd = Join-Path $Pasta "$Nome\$Nome.vhdx"
    New-VM -Name $Nome -Generation 2 -MemoryStartupBytes 6GB -NewVHDPath $Vhd -NewVHDSizeBytes 80GB -SwitchName $Switch -Path $Pasta | Out-Null
    Set-VMMemory    -VMName $Nome -DynamicMemoryEnabled $false
    Set-VMProcessor -VMName $Nome -Count 4
    Set-VM -Name $Nome -AutomaticCheckpointsEnabled $false -AutomaticStopAction ShutDown
    Add-VMDvdDrive  -VMName $Nome -Path $Iso.FullName
    $Dvd = Get-VMDvdDrive -VMName $Nome
    Set-VMFirmware  -VMName $Nome -FirstBootDevice $Dvd -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows
    Set-VMKeyProtector -VMName $Nome -NewLocalKeyProtector
    Enable-VMTPM    -VMName $Nome
    $Vm = Get-VM -Name $Nome
    Write-Host ''
    Write-Host "Maquina criada: $Nome"
    Write-Host ("Memoria: {0} GB fixa | Processadores: {1} | TPM: {2}" -f ($Vm.MemoryStartup/1GB), $Vm.ProcessorCount, (Get-VMSecurity -VMName $Nome).TpmEnabled)
    Write-Host "Disco: $Vhd (80 GB, cresce com o uso) | Rede: $Switch"
    Write-Host 'RESULTADO: OK'
}
catch {
    Write-Host ''
    Write-Host "ERRO: $($_.Exception.Message)"
    Write-Host 'RESULTADO: COM ERROS'
}
finally { Stop-Transcript | Out-Null }

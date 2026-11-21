<#
  boot_dvd_hyperv.ps1 - SistemaCMJ, 3d-C (21/11/2026)
  Liga (ou reinicia) a VM do ensaio e "aperta" a barra de espaco pelo Hyper-V
  (classe WMI Msvm_Keyboard) durante uns 20 s, para pegar o
  "Press any key to boot from CD or DVD" sem precisar do teclado.
#>
$Nome = 'SisCMJ-Servidor-Ensaio'
$ErrorActionPreference = 'Stop'
try {
    $Vm = Get-VM -Name $Nome
    if ($Vm.State -ne 'Off') { Stop-VM -Name $Nome -TurnOff -Force; Start-Sleep -Seconds 2 }
    Start-VM -Name $Nome
    Write-Host 'Maquina ligada; apertando a barra de espaco por 20 segundos...'
    $Fim = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $Fim) {
        $Cs = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_ComputerSystem -Filter "ElementName='$Nome'"
        $Kb = Get-CimAssociatedInstance -InputObject $Cs -ResultClassName Msvm_Keyboard -ErrorAction SilentlyContinue
        if ($Kb) { Invoke-CimMethod -InputObject $Kb -MethodName TypeKey -Arguments @{ keyCode = [uint32]0x20 } | Out-Null }
        Start-Sleep -Milliseconds 700
    }
    Write-Host 'Pronto. Veja na tela da maquina se abriu a instalacao do Windows.'
}
catch { Write-Host "ERRO: $($_.Exception.Message)" }

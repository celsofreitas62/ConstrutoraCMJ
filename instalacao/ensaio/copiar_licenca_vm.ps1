<#
  copiar_licenca_vm.ps1 - SistemaCMJ, 3d-C (21/11/2026)
  Copia a licenca mais recente gerada para o servidor de ensaio (codigo 84C92DB4...)
  de %USERPROFILE%\SisCMJ_Chave\licencas para C:\ProgramData\SisCMJ\licenca.lic dentro da VM.
#>
$Nome = 'SisCMJ-Servidor-Ensaio'
$Codigo = '84C92DB4'
$ErrorActionPreference = 'Stop'
try {
    $Usuario = (Get-CimInstance Win32_ComputerSystem).UserName.Split('\')[-1]
    $Pasta = "C:\Users\$Usuario\SisCMJ_Chave\licencas"
    $Lic = Get-ChildItem $Pasta -Filter "*_$Codigo*.lic" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if (-not $Lic) { throw "Nenhuma licenca do servidor $Codigo em $Pasta (rode api\gerar_licenca.cmd, opcao 2)" }
    Write-Host "Licenca: $($Lic.Name)"
    $Gsi = Get-VMIntegrationService -VMName $Nome | Where-Object { $_.Id -like '*6C09BB55-D683-4DA0-8931-C9BF705F6480' }
    if (-not $Gsi.Enabled) { $Gsi | Enable-VMIntegrationService; Start-Sleep -Seconds 15 }
    Copy-VMFile -Name $Nome -SourcePath $Lic.FullName -DestinationPath 'C:\ProgramData\SisCMJ\licenca.lic' -CreateFullPath -FileSource Host -Force
    Write-Host 'Copiada para C:\ProgramData\SisCMJ\licenca.lic (dentro da VM). Vale em ate 1 minuto.'
    Write-Host 'RESULTADO: OK'
}
catch { Write-Host "ERRO: $($_.Exception.Message)"; Write-Host 'RESULTADO: COM ERROS' }

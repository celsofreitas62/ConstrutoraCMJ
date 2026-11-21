<#
  copiar_pacote_vm.ps1 - SistemaCMJ, 3d-C (21/11/2026)
  Copia o pacote de instalacao mais recente de C:\SisCMJ_Publicacao para dentro da VM
  do ensaio, em C:\SisCMJ_Instalacao\<pacote> (passo 4 do roteiro), pelo Hyper-V
  (Copy-VMFile; liga a "Interface de Servico de Convidado" se estiver desligada).
#>
$Nome = 'SisCMJ-Servidor-Ensaio'
$ErrorActionPreference = 'Stop'
try {
    $Pacote = Get-ChildItem 'C:\SisCMJ_Publicacao' -Directory | Sort-Object Name | Select-Object -Last 1
    if (-not $Pacote) { throw 'Nenhum pacote em C:\SisCMJ_Publicacao' }
    Write-Host "Pacote: $($Pacote.Name)"
    if ((Get-VM -Name $Nome).State -ne 'Running') { throw 'A maquina virtual precisa estar ligada' }
    $Gsi = Get-VMIntegrationService -VMName $Nome | Where-Object { $_.Id -like '*6C09BB55-D683-4DA0-8931-C9BF705F6480' }
    if (-not $Gsi.Enabled) { $Gsi | Enable-VMIntegrationService; Write-Host 'Servico de convidado ligado; aguardando...'; Start-Sleep -Seconds 15 }
    $Destino = 'C:\SisCMJ_Instalacao\' + $Pacote.Name
    $Arquivos = Get-ChildItem $Pacote.FullName -Recurse -File
    $n = 0
    foreach ($A in $Arquivos) {
        $Rel = $A.FullName.Substring($Pacote.FullName.Length)
        Copy-VMFile -Name $Nome -SourcePath $A.FullName -DestinationPath ($Destino + $Rel) -CreateFullPath -FileSource Host -Force
        $n++
    }
    Write-Host "Copiados $n arquivos para $Destino (dentro da VM)"
    Write-Host 'RESULTADO: OK'
}
catch { Write-Host "ERRO: $($_.Exception.Message)"; Write-Host 'RESULTADO: COM ERROS' }

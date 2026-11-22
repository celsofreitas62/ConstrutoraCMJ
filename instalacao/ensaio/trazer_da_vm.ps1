<#
  trazer_da_vm.ps1 - SistemaCMJ, 3d-C (22/11/2026)
  Traz da VM do ensaio para o notebook os arquivos do computador de usuario
  (SisCMJ_certificado.cer e preparar_computador_usuario.cmd), pelo PowerShell Direct
  do Hyper-V. Pede a senha do usuario AdminCMJ da VM (janela do Windows).
  Destino: C:\SisCMJ_Ensaio_Usuario (fora do Drive).
#>
$Nome = 'SisCMJ-Servidor-Ensaio'
$Destino = 'C:\SisCMJ_Ensaio_Usuario'
$ErrorActionPreference = 'Stop'
try {
    $Cred = Get-Credential -UserName 'AdminCMJ' -Message 'Senha do usuario AdminCMJ da maquina virtual'
    $S = New-PSSession -VMName $Nome -Credential $Cred
    $Pasta = Invoke-Command -Session $S -ScriptBlock {
        (Get-ChildItem 'C:\SisCMJ_Instalacao' -Directory | Sort-Object Name | Select-Object -Last 1).FullName + '\instalacao'
    }
    Write-Host "Na VM: $Pasta"
    New-Item -ItemType Directory -Force -Path $Destino | Out-Null
    foreach ($Arq in @('SisCMJ_certificado.cer', 'preparar_computador_usuario.cmd')) {
        Copy-Item -FromSession $S -Path ($Pasta + '\' + $Arq) -Destination $Destino -Force
        Write-Host "Copiado: $Destino\$Arq"
    }
    $Ip = Invoke-Command -Session $S -ScriptBlock {
        (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*' } | Select-Object -First 1).IPAddress
    }
    Remove-PSSession $S
    Write-Host "IP da VM: $Ip"
    Write-Host 'RESULTADO: OK'
}
catch { Write-Host "ERRO: $($_.Exception.Message)"; Write-Host 'RESULTADO: COM ERROS' }

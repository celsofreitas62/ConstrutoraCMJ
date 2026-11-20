<#
  SistemaCMJ - registra a tarefa agendada do backup (rodar pelo instalar_backup.cmd)
  v1.0 (20/11/2026) - Diario as 19:00; se o notebook estiver desligado, roda assim que ligar.
#>
$ErrorActionPreference = 'Stop'
$Script = Join-Path $PSScriptRoot 'backup_banco.ps1'
$Acao = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $Script + '"')
$Gatilho = New-ScheduledTaskTrigger -Daily -At '19:00'
$Config = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
$Usuario = New-ScheduledTaskPrincipal -UserId ($env:USERDOMAIN + '\' + $env:USERNAME) -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'SistemaCMJ - Backup do banco' -Action $Acao -Trigger $Gatilho -Settings $Config -Principal $Usuario -Force | Out-Null
Write-Output 'OK: tarefa "SistemaCMJ - Backup do banco" registrada (todo dia as 19:00).'

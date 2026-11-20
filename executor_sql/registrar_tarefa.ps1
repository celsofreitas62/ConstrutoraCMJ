<#
  SistemaCMJ - registra a tarefa do executor SQL (rodar pelo instalar_executor.cmd)
  v1.0 (20/11/2026) - Inicia ao entrar no Windows (usuario atual), janela oculta,
                      sem limite de tempo; reinicia se cair.
#>
$ErrorActionPreference = 'Stop'
$Script = Join-Path $PSScriptRoot 'executor_sql.ps1'
$Acao = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $Script + '"')
$Gatilho = New-ScheduledTaskTrigger -AtLogOn -User ($env:USERDOMAIN + '\' + $env:USERNAME)
$Config = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
$Usuario = New-ScheduledTaskPrincipal -UserId ($env:USERDOMAIN + '\' + $env:USERNAME) -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'SistemaCMJ - Executor SQL' -Action $Acao -Trigger $Gatilho -Settings $Config -Principal $Usuario -Force | Out-Null
Start-ScheduledTask -TaskName 'SistemaCMJ - Executor SQL'
Write-Output 'OK: tarefa "SistemaCMJ - Executor SQL" registrada (inicia ao entrar no Windows) e iniciada agora.'

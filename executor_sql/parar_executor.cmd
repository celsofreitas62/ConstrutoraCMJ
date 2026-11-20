@echo off
rem SistemaCMJ - para o executor SQL (volta sozinho na proxima vez que entrar no Windows)
rem Para iniciar de novo agora: rode o instalar_executor.cmd.
powershell -NoProfile -Command "Stop-ScheduledTask -TaskName 'SistemaCMJ - Executor SQL'; Write-Output 'Executor parado.'"
pause

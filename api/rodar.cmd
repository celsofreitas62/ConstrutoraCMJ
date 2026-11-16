@echo off
rem SistemaCMJ - sobe o sistema no notebook: https://localhost:5443 (fase 3b)
rem Para parar: feche esta janela ou aperte Ctrl+C.
title SistemaCMJ - servidor de desenvolvimento
cd /d "%~dp0SistemaCMJ.Api"
dotnet run
pause

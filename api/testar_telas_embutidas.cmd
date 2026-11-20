@echo off
rem SistemaCMJ - TESTE (fase 3d): sobe uma segunda copia do sistema em https://localhost:5444
rem com as telas EMBUTIDAS no executavel, como vai ficar no servidor. O rodar.cmd (5443)
rem continua normal, com as telas soltas. Rodar DEPOIS do rodar.cmd (usa a compilacao dele).
rem Para parar: feche esta janela.
title SistemaCMJ - TESTE telas embutidas (5444)
cd /d "%~dp0SistemaCMJ.Api"
set Telas__Embutidas=true
set Agendador__Ligado=false
set ASPNETCORE_ENVIRONMENT=Development
dotnet run --no-build --no-launch-profile --urls https://localhost:5444
pause

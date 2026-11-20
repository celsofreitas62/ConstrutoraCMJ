@echo off
rem SisCMJ - gerador de licenca. SO no computador do Celso; nunca vai para o cliente.
rem Chave privada (cifrada com senha): %USERPROFILE%\SisCMJ_Chave\chave_privada_siscmj.pem
title SisCMJ - gerador de licenca
dotnet run --project "%~dp0GeradorLicenca" -- "%~dp0.."
pause

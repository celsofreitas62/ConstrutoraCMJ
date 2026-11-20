@echo off
rem SisCMJ - remove o servico (rodar COMO ADMINISTRADOR). Nao apaga o banco nem os arquivos do sistema.
rem Ensaio no notebook: desinstalar_servico.cmd -NomeServico SisCMJ_Ensaio -PastaPrograma C:\SisCMJ_Ensaio\programa -RemoverLoginSql
title SisCMJ - desinstalar servico
net session >nul 2>&1
if errorlevel 1 (
  echo Rode como administrador.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desinstalar_servico.ps1" %*
pause

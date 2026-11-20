@echo off
rem SisCMJ - remove o ENSAIO do servico no notebook (servico SisCMJ_Ensaio, porta 5445). Rodar COMO ADMINISTRADOR.
rem Remove servico, regra do firewall, programa, login do servico no SQL, certificado e a configuracao de ensaio.
rem Nao apaga o banco de ensaio SISTEMACMJ nem o SISTEMACMJ_LOCAL.
title SisCMJ - ENSAIO desinstalar do notebook
net session >nul 2>&1
if errorlevel 1 (
  echo Rode como administrador.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\desinstalar_servico.ps1" -NomeServico SisCMJ_Ensaio -PastaPrograma C:\SisCMJ_Ensaio\programa -RemoverLoginSql -RemoverCertificado -RemoverConfiguracao
pause

@echo off
rem SisCMJ - levantamento do servidor antes da instalacao (SO LEITURA, nao muda nada). Rodar COMO ADMINISTRADOR.
title SisCMJ - levantamento do servidor
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Rode como administrador: botao direito neste arquivo ^> Executar como administrador.
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0levantamento_servidor.ps1"
echo.
echo Mande para o Claude o arquivo levantamento_*.txt gravado nesta pasta.
pause

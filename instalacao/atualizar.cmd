@echo off
rem SisCMJ - ATUALIZACAO EM UM CLIQUE: botao direito > Executar como administrador.
rem Atualiza este servidor para a versao deste pacote (backup de seguranca, banco, programa,
rem conferencia e volta automatica se algo falhar). Roteiro: item 14.
title SisCMJ - atualizar
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Rode como administrador: botao direito neste arquivo ^> Executar como administrador.
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalacao\atualizar.ps1" %*
echo.
echo Tire um print desta janela e mande para o Claude.
pause

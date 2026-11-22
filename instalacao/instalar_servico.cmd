@echo off
rem SisCMJ - instala ou atualiza o sistema neste servidor (rodar COMO ADMINISTRADOR).
rem Opcoes (exemplos): instalar_servico.cmd -Porta 5443 -Instancia .\SQL2025 -RedesPermitidas LocalSubnet,10.8.0.0/24 -EnderecoUsuarios 192.168.0.10
title SisCMJ - instalar servico
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Rode como administrador: botao direito neste arquivo ^> Executar como administrador.
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_servico.ps1" %*
echo.
echo Tire um print desta janela e mande para o Claude.
pause

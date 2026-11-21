@echo off
rem SistemaCMJ - cria a maquina virtual do ensaio no Hyper-V (3d-C, 21/11/2026)
rem Clique com o botao direito e escolha "Executar como administrador".
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0criar_vm_hyperv.ps1"
echo.
pause

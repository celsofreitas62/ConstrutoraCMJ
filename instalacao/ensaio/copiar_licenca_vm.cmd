@echo off
rem SistemaCMJ - copia a licenca do servidor de ensaio para dentro da VM (3d-C, 21/11/2026)
rem Clique com o botao direito e escolha "Executar como administrador". A VM precisa estar ligada.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0copiar_licenca_vm.ps1"
echo.
pause

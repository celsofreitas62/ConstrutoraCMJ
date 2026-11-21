@echo off
rem SistemaCMJ - copia o pacote de instalacao para dentro da VM do ensaio (3d-C, 21/11/2026)
rem Clique com o botao direito e escolha "Executar como administrador". A VM precisa estar ligada.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0copiar_pacote_vm.ps1"
echo.
pause

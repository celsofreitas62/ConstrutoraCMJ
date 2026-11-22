@echo off
rem SistemaCMJ - traz da VM os arquivos do computador de usuario (3d-C, 22/11/2026)
rem Clique com o botao direito e escolha "Executar como administrador". A VM precisa estar ligada.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0trazer_da_vm.ps1"
echo.
pause

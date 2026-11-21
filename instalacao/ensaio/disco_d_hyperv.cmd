@echo off
rem SistemaCMJ - 2o disco (D:) na VM do ensaio (3d-C, 21/11/2026)
rem Clique com o botao direito e escolha "Executar como administrador".
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0disco_d_hyperv.ps1"
echo.
pause

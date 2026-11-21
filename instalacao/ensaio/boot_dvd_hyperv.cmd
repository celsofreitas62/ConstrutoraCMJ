@echo off
rem SistemaCMJ - reinicia a VM do ensaio pelo DVD, apertando a tecla sozinho (3d-C, 21/11/2026)
rem Clique com o botao direito e escolha "Executar como administrador".
start "" "%windir%\System32\vmconnect.exe" localhost "SisCMJ-Servidor-Ensaio"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0boot_dvd_hyperv.ps1"
timeout /t 10 >nul

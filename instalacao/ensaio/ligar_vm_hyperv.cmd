@echo off
rem SistemaCMJ - abre a tela da maquina virtual do ensaio e liga (3d-C, 21/11/2026)
rem Clique com o botao direito e escolha "Executar como administrador".
set VM=SisCMJ-Servidor-Ensaio
start "" "%windir%\System32\vmconnect.exe" localhost "%VM%"
timeout /t 4 /nobreak >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ((Get-VM -Name '%VM%').State -ne 'Running') { Start-VM -Name '%VM%'; 'Maquina ligada. Clique na tela dela e aperte Enter varias vezes.' } else { 'A maquina ja estava ligada.' }"
timeout /t 8 >nul

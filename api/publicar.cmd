@echo off
rem SisCMJ - gera o pacote de instalacao em C:\SisCMJ_Publicacao (fora do Google Drive)
title SisCMJ - publicar
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publicar.ps1"
pause

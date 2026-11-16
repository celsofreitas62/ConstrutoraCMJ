@echo off
rem SistemaCMJ - envia os commits para o GitHub (origin/main). Criado em 16/11/2026.
rem O ambiente do Claude nao tem acesso ao GitHub: dois cliques aqui fazem o envio.
title SistemaCMJ - enviar para o GitHub
cd /d "%~dp0"
git push origin main
echo.
echo Pronto. Pode fechar esta janela.
pause

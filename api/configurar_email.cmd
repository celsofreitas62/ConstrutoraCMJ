@echo off
rem SistemaCMJ - guarda a senha de app do e-mail que envia os e-mails do sistema (fase 3c)
rem A senha fica numa variavel de ambiente do seu usuario do Windows (Smtp__Interna__Senha),
rem nunca no banco nem nos arquivos do projeto. Depois de rodar, feche e abra de novo o rodar.cmd.
title SistemaCMJ - senha do e-mail
echo.
echo Cole a SENHA DE APP do Google (16 letras, pode ter espacos) e aperte Enter.
echo Ela fica guardada so neste computador, no seu usuario do Windows.
echo.
set /p SENHA_APP=Senha de app: 
if "%SENHA_APP%"=="" goto vazio
set SENHA_APP=%SENHA_APP: =%
setx Smtp__Interna__Senha "%SENHA_APP%" >nul
set SENHA_APP=
echo.
echo Pronto. Feche a janela do sistema (rodar.cmd) e abra de novo para valer.
pause
exit /b 0
:vazio
echo Nada foi gravado.
pause

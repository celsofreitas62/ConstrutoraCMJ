@echo off
rem SisCMJ - ENSAIO da instalacao no notebook do Celso (fase 3d). Rodar COMO ADMINISTRADOR.
rem Usa o pacote mais novo de C:\SisCMJ_Publicacao e instala o servico "SisCMJ_Ensaio" na porta 5445,
rem ligado ao banco de ensaio SISTEMACMJ. Nao mexe no rodar.cmd (5443) nem no SISTEMACMJ_LOCAL.
rem Para remover depois: ensaio_desinstalar_notebook.cmd (tambem como administrador).
title SisCMJ - ENSAIO instalar no notebook
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Rode como administrador: botao direito neste arquivo ^> Executar como administrador.
  echo.
  pause
  exit /b 1
)
set PACOTE=
for /f "delims=" %%d in ('dir /b /ad /o-n "C:\SisCMJ_Publicacao\SisCMJ_*" 2^>nul') do if not defined PACOTE set PACOTE=C:\SisCMJ_Publicacao\%%d
if not defined PACOTE (
  echo Nao achei pacote em C:\SisCMJ_Publicacao. Gere com api\publicar.cmd.
  pause
  exit /b 1
)
echo Pacote: %PACOTE%
rem Licenca: a de desenvolvimento deste notebook vale tambem para o servico de ensaio (mesmo computador)
if not exist "C:\ProgramData\SisCMJ" mkdir "C:\ProgramData\SisCMJ"
if exist "%~dp0..\..\api\licenca\licenca.lic" copy /y "%~dp0..\..\api\licenca\licenca.lic" "C:\ProgramData\SisCMJ\licenca.lic" >nul
call "%PACOTE%\instalacao\instalar_servico.cmd" -NomeServico SisCMJ_Ensaio -PastaPrograma C:\SisCMJ_Ensaio\programa -Porta 5445

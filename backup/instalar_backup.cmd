@echo off
rem SistemaCMJ - instala o backup do banco no notebook (rodar UMA vez, como administrador)
rem v1.0 (20/11/2026): pasta C:\Backup_SisCMJ com permissao para o SQL Server,
rem tarefa agendada diaria, 1o backup e teste de restauracao.
title SistemaCMJ - Instalar backup do banco
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Este arquivo precisa ser executado como administrador.
  echo  Clique com o botao direito nele e escolha "Executar como administrador".
  echo.
  pause
  exit /b 1
)
cd /d "%~dp0"
echo.
echo === 1/4 Pasta C:\Backup_SisCMJ e permissao para o SQL Server
if not exist "C:\Backup_SisCMJ\teste" mkdir "C:\Backup_SisCMJ\teste"
icacls "C:\Backup_SisCMJ" /grant "NT SERVICE\MSSQL$SQL2025:(OI)(CI)M"
echo.
echo === 2/4 Tarefa agendada
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0registrar_tarefa.ps1"
echo.
echo === 3/4 Primeiro backup
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup_banco.ps1"
echo.
echo === 4/4 Teste de restauracao
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0testar_restauracao.ps1"
echo.
echo Fim. Tire um print desta janela e mande para o Claude.
pause

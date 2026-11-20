@echo off
rem SistemaCMJ - instala o executor de scripts SQL no notebook (rodar UMA vez, com dois cliques)
rem v1.0 (20/11/2026): tarefa ao entrar no Windows, ja iniciada; so no banco SISTEMACMJ_LOCAL.
title SistemaCMJ - Instalar executor SQL
cd /d "%~dp0"
echo.
echo === 1/2 Tarefa "SistemaCMJ - Executor SQL"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0registrar_tarefa.ps1"
if errorlevel 1 (
  echo.
  echo  Nao consegui registrar a tarefa. Clique com o botao direito neste arquivo
  echo  e escolha "Executar como administrador".
  echo.
  pause
  exit /b 1
)
echo.
echo === 2/2 Conferindo se o executor esta ativo
timeout /t 5 /nobreak >nul
type "%~dp0STATUS.txt"
echo.
echo Fim. Tire um print desta janela e mande para o Claude.
pause

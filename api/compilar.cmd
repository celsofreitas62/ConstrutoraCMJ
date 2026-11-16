@echo off
rem SistemaCMJ - compila a API e grava o resultado em api\compilar.log (fase 3b)
cd /d "%~dp0SistemaCMJ.Api"
echo Compilando... > "%~dp0compilar.log"
dotnet build --nologo >> "%~dp0compilar.log" 2>&1
echo CODIGO_SAIDA=%ERRORLEVEL% >> "%~dp0compilar.log"

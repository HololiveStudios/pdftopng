@echo off
title Instalando Dependencias - PDF para JPG
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\instalar_dependencias.ps1"
echo.
pause

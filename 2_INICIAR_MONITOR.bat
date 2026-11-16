@echo off
title Monitor PDF para JPG
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\monitor_pdf_jpg.ps1"
echo.
pause

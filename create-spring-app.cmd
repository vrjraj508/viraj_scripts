@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create-spring-app.ps1" -OutputDir "%CD%"
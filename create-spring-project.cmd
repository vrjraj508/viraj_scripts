@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate_gemini.ps1" -OutputDir "%CD%"
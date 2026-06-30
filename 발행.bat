@echo off
chcp 65001 > nul
REM ====================================================
REM  사이트 발행 (더블클릭) - 발행.ps1 실행
REM ====================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0발행.ps1"

@echo off
chcp 65001 > nul
REM ====================================================
REM  미디어커머스 업계 동향 - 주간 리포트 생성 (더블클릭용)
REM  같은 폴더의 리포트생성.ps1 을 실행합니다.
REM ====================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0리포트생성.ps1"

@echo off
chcp 65001 > nul
REM ====================================================
REM  미디어커머스 업계 동향 - 주간 리포트 '무인 자동 생성'
REM  작업 스케줄러(월요일 오전)가 이 파일을 실행합니다.
REM  같은 폴더의 자동생성.ps1 을 headless 로 돌립니다.
REM  ※ 리포트 생성 + index.html 갱신 + 발행(push)까지 자동.
REM  ※ 이 파일은 UTF-8(BOM 없음)로 저장할 것.
REM ====================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0자동생성.ps1"
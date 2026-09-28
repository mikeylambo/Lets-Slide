@echo off
rem Double-click: build + launch the Let's Slide Playtest Harness on Course 01.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tools\playtest.ps1" %*
if exist "%~dp0playtests\LATEST.md" start "" notepad "%~dp0playtests\LATEST.md"

@echo off
setlocal ENABLEEXTENSIONS
title Roblox Tool Launcher DelShop
set "DEBUG_FLAG=%DEBUG%"
if /i "%DEBUG_FLAG%"=="1" echo [DEBUG] Starting launcher (raw args: %*)
where python >nul 2>nul
if not errorlevel 1 goto :have_python
echo [INFO] Python not found. Downloading installer...
powershell -Command "Try { Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe -OutFile python-installer.exe -ErrorAction Stop } Catch { Exit 1 }"
if errorlevel 1 echo [ERROR] Failed to download Python installer.& pause & exit /b 1
echo [INFO] Installing Python (silent)...
start /wait python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
del python-installer.exe 2>nul
where python >nul 2>nul
if errorlevel 1 echo [ERROR] Python installation failed.& pause & exit /b 1
echo [OK] Python installed.
:have_python
python -m ensurepip --default-pip >nul 2>nul
if /i "%DEBUG_FLAG%"=="1" echo [DEBUG] Checking dependencies
python -c "import requests" >nul 2>nul
if errorlevel 1 echo [INFO] Installing requests & python -m pip install --quiet requests >nul 2>nul
python -c "import psutil" >nul 2>nul
if errorlevel 1 echo [INFO] Installing psutil & python -m pip install --quiet psutil >nul 2>nul
if not exist bin mkdir bin
if /i "%~1"=="init" (
  echo [INFO] Resetting config to defaults...
  python roblox_tool.py --init-config
  shift
  if /i "%DEBUG_FLAG%"=="1" echo [DEBUG] After init shift, remaining args: %*
)
if /i "%DEBUG_FLAG%"=="1" echo [DEBUG] Dispatch decision (first arg now: %~1)
if "%~1"=="" goto :run_menu
goto :run_args
:run_menu
if /i "%DEBUG_FLAG%"=="1" echo [DEBUG] Launching interactive menu
python roblox_tool.py --menu
goto :end
:run_args
if /i "%DEBUG_FLAG%"=="1" echo [DEBUG] Passing args directly: %*
python roblox_tool.py %*
goto :end
:end
if /i "%DEBUG_FLAG%"=="1" echo [DEBUG] Launcher finished
endlocal
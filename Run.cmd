@echo off
setlocal
if not exist "%~dp0runtime\Godot.exe" (
  echo Godot 4.7.2 for Windows is required.
  echo Download it from https://godotengine.org/download/windows/
  echo Put the official 64-bit executable in runtime\Godot.exe.
  pause
  exit /b 1
)
start "" /b /wait "%~dp0runtime\Godot.exe" --headless --editor --single-threaded-scene --path "%~dp0." --import --quit
if errorlevel 1 exit /b 1
"%~dp0runtime\Godot.exe" --path "%~dp0." --fullscreen %*

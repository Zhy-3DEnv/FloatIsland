@echo off
setlocal
set "ROOT=%~dp0"
set "GODOT=%GODOT%"
if not defined GODOT set "GODOT=C:\Users\zhouhuiyuan\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe"
echo [playtest] 启动自动试玩（带窗口）...
"%GODOT%" --path "%ROOT%" --script res://scripts/playtest/playtest_run.gd

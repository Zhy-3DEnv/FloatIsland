@echo off
chcp 65001 >nul
echo FolatIsland: 导出 ^> 签名 ^> 安装到手机
echo.
bash "%~dp0scripts\install_apk.sh"
set EXIT_CODE=%ERRORLEVEL%
echo.
if %EXIT_CODE% neq 0 (
	echo 失败，退出码 %EXIT_CODE%
) else (
	echo 成功。
)
pause
exit /b %EXIT_CODE%

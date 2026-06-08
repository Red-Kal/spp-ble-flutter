@echo off
chcp 65001 >nul
cd /d "%~dp0flutterDemo"

echo ========================================
echo  Flutter BLE SPP - Git 推送工具
echo ========================================

:: 检查是否有未提交的改动
git status --porcelain >nul 2>&1
if errorlevel 1 (
    echo [错误] 不是 git 仓库
    exit /b 1
)

:: 1. 获取用户输入的提交信息
set /p COMMIT_MSG="请输入本次修改描述: "

if "%COMMIT_MSG%"=="" (
    set COMMIT_MSG=更新: %date% %time%
)

:: 2. 提交并推送代码到 master
echo.
echo [1/3] 提交代码到 master...
git add -A
git commit -m "%COMMIT_MSG%"
git push origin master

:: 3. 推送 APK 到 release 分支
echo.
echo [2/3] 推送 APK 到 release 分支...
if exist build\app\outputs\flutter-apk\app-debug.apk (
    git checkout release 2>nul
    if errorlevel 1 (
        git checkout --orphan release
        git rm -r --cached . 2>nul
    )
    
    :: 添加 APK
    git add -f build\app\outputs\flutter-apk\app-debug.apk
    git commit -m "Release: %COMMIT_MSG%"
    git push origin release
    
    :: 切回 master
    git checkout -f master
) else (
    echo [警告] 未找到 APK 文件，请先编译
)

:: 4. 完成
echo.
echo [3/3] 全部推送完成！
echo   代码: https://gitee.com/sayux/spp-ble-flutter (master)
echo   APK:  https://gitee.com/sayux/spp-ble-flutter (release)
echo.

pause

@echo off
chcp 65001 >nul
cd /d "%~dp0flutterDemo"

echo ========================================
echo  Flutter BLE SPP - Git 推送工具
echo ========================================

:: 检查 git 仓库
git status --porcelain >nul 2>&1
if errorlevel 1 (
    echo [错误] 不是 git 仓库
    exit /b 1
)

:: 1. 暂存所有改动
echo.
echo [1/4] 检测改动文件...
git add -A
git diff --cached --stat > .commit_stat.tmp
type .commit_stat.tmp

:: 2. 自动生成提交描述
set MSG=
set HAS_LIB=0
set HAS_ANDROID=0
set HAS_YAML=0
set HAS_SPP_BLE=0
set FILE_COUNT=0

for /f "usebackq delims=" %%a in (`.commit_stat.tmp`) do (
    set /a FILE_COUNT+=1
    echo %%a | findstr /i "^lib/" >nul && set HAS_LIB=1
    echo %%a | findstr /i "^android/" >nul && set HAS_ANDROID=1
    echo %%a | findstr /i "^pubspec.yaml" >nul && set HAS_YAML=1
    echo %%a | findstr /i "^SPP_BLE/" >nul && set HAS_SPP_BLE=1
)

set MSG=更新

if %HAS_LIB%==1 set MSG=%MSG% [Flutter代码]
if %HAS_ANDROID%==1 set MSG=%MSG% [Android原生]
if %HAS_YAML%==1 set MSG=%MSG% [依赖]
if %HAS_SPP_BLE%==1 set MSG=%MSG% [旧项目参考]

set MSG=%MSG% (%FILE_COUNT%个文件 - %date% %time%)

del .commit_stat.tmp

:: 3. 提交并推送 master
echo.
echo [2/4] 提交代码到 master...
git diff --cached --quiet 2>nul
if errorlevel 1 (
    git commit -m "%MSG%"
    echo   提交: %MSG%
) else (
    echo   无新改动，跳过
)
git push origin master
if errorlevel 1 (
    echo [重试] 推送失败，再试一次...
    timeout /t 3 /nobreak >nul
    git push origin master
)

:: 4. 推送 APK 到 release
echo.
echo [3/4] 推送 APK 到 release 分支...
if exist build\app\outputs\flutter-apk\app-debug.apk (
    git checkout release 2>nul
    if errorlevel 1 (
        git checkout --orphan release
        git rm -r --cached . 2>nul
    )
    git add -f build\app\outputs\flutter-apk\app-debug.apk
    git diff --cached --quiet 2>nul
    if errorlevel 1 (
        git commit -m "Release: %MSG%"
        echo   提交: Release: %MSG%
    ) else (
        echo   APK 无变化
    )
    git push origin release
    if errorlevel 1 (
        timeout /t 3 /nobreak >nul
        git push origin release
    )
    git checkout -f master
) else (
    echo [跳过] 未找到 APK，请先 flutter build
)

:: 5. 完成
echo.
echo [4/4] 全部完成！
echo   代码: https://gitee.com/sayux/spp-ble-flutter (master)
echo   APK:  https://gitee.com/sayux/spp-ble-flutter (release)
echo.
pause

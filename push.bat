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

:: 生成详细的改动列表
git diff --cached --name-status > .commit_files.tmp
git diff --cached --stat >> .commit_stat.tmp
type .commit_stat.tmp

:: 2. 自动生成详细提交描述
set MSG_TITLE=
set MSG_BODY=
set ADDED=0
set MODIFIED=0
set DELETED=0
set HAS_LIB_DART=0
set HAS_LIB_SERVICE=0
set HAS_ANDROID_KOTLIN=0
set HAS_ANDROID_XML=0
set HAS_ANDROID_GRADLE=0
set HAS_YAML=0
set HAS_SPP_BLE=0
set HAS_APK=0
set HAS_SCRIPT=0

for /f "usebackq delims=" %%a in (`.commit_files.tmp`) do (
    echo %%a | findstr /i "^A	" >nul && set /a ADDED+=1
    echo %%a | findstr /i "^M	" >nul && set /a MODIFIED+=1
    echo %%a | findstr /i "^D	" >nul && set /a DELETED+=1
    echo %%a | findstr /i "^." >nul && (
        echo %%a | findstr /i "lib/" >nul && set HAS_LIB_DART=1
        echo %%a | findstr /i "lib/services/" >nul && set HAS_LIB_SERVICE=1
        echo %%a | findstr /i "android/.*\.kt" >nul && set HAS_ANDROID_KOTLIN=1
        echo %%a | findstr /i "android/.*\.xml" >nul && set HAS_ANDROID_XML=1
        echo %%a | findstr /i "android/.*\.kts" >nul && set HAS_ANDROID_GRADLE=1
        echo %%a | findstr /i "pubspec.yaml" >nul && set HAS_YAML=1
        echo %%a | findstr /i "^A	SPP_BLE/" >nul && set HAS_SPP_BLE=1
        echo %%a | findstr /i "\.apk" >nul && set HAS_APK=1
        echo %%a | findstr /i "push\.bat" >nul && set HAS_SCRIPT=1
    )
)

:: 构建标题
if %HAS_LIB_DART%==1 set MSG_TITLE=%MSG_TITLE% [Dart代码]
if %HAS_LIB_SERVICE%==1 set MSG_TITLE=%MSG_TITLE% [蓝牙服务]
if %HAS_ANDROID_KOTLIN%==1 set MSG_TITLE=%MSG_TITLE% [Android原生]
if %HAS_ANDROID_XML%==1 set MSG_TITLE=%MSG_TITLE% [Android配置]
if %HAS_ANDROID_GRADLE%==1 set MSG_TITLE=%MSG_TITLE% [构建脚本]
if %HAS_YAML%==1 set MSG_TITLE=%MSG_TITLE% [依赖]
if %HAS_SPP_BLE%==1 set MSG_TITLE=%MSG_TITLE% [旧项目参考]
if %HAS_APK%==1 set MSG_TITLE=%MSG_TITLE% [APK]
if %HAS_SCRIPT%==1 set MSG_TITLE=%MSG_TITLE% [工具脚本]

if "%MSG_TITLE%"=="" set MSG_TITLE=[通用]

:: 构建正文 - 列出具体改动的文件
set FILE_LIST=
for /f "usebackq delims=" %%a in (`.commit_files.tmp`) do (
    set FILE_LIST=!FILE_LIST!  - %%a
)

set MSG=%MSG_TITLE% (+%ADDED%/-%DELETED%/~%MODIFIED% 个文件)

del .commit_files.tmp
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

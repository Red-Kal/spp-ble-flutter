@echo off
set PROJECT_DIR=%~dp0
cd /d "%PROJECT_DIR%"
echo Building in: %PROJECT_DIR%
flutter build apk --release --target-platform android-arm64
if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)
echo Build success!

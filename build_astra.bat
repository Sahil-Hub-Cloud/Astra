@echo off
setlocal

:: Get the directory where this script is located
set "BASE_DIR=%~dp0"
if "%BASE_DIR:~-1%"=="\" set "BASE_DIR=%BASE_DIR:~0,-1%"

:: Set explicit paths with verified SHORT JAVA_HOME
set "JAVA_HOME=C:\PROGRA~1\Android\ANDROI~1\jbr"
set "FLUTTER_ROOT=%BASE_DIR%\flutter"
set "PATH=%PATH%;%FLUTTER_ROOT%\bin;C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0"

echo [INFO] Using JAVA_HOME: %JAVA_HOME%
echo [INFO] Using Flutter: %FLUTTER_ROOT%
echo [INFO] Base Directory: %BASE_DIR%

:: Verify paths exist
if not exist "%JAVA_HOME%\bin\java.exe" (
    echo [ERROR] JAVA_HOME is invalid! [%JAVA_HOME%]
    exit /b 1
)
if not exist "%FLUTTER_ROOT%\bin\flutter.bat" (
    echo [ERROR] Flutter not found at [%FLUTTER_ROOT%\bin\flutter.bat]
    exit /b 1
)

cd /d "%BASE_DIR%"

echo.
echo [1/3] Cleaning project...
call flutter clean

echo.
echo [2/3] Getting dependencies...
call flutter pub get

echo.
echo [3/3] Building Release APK...
call flutter build apk --release --dart-define=SUPABASE_URL=https://mqahrwkfwasitlxgbobz.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xYWhyd2tmd2FzaXRseGdib2J6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4MzkyMDgsImV4cCI6MjA4NjQxNTIwOH0.nT_5NET7nUX-Kmow5LyGmycEgUZbT4ZYmJtqS298v0o

if errorlevel 1 (
    echo.
    echo [ERROR] Build failed! Check the output above for details.
    exit /b 1
)

echo.
echo ============================================
echo   BUILD SUCCESSFUL!
echo   APK: build\app\outputs\flutter-apk\app-release.apk
echo ============================================
echo.

endlocal

@echo off
echo ============================================
echo   ASTRA EMERGENCY - Production APK Builder
echo ============================================
echo.

set PATH=%PATH%;C:\WINDOWS\System32\WindowsPowerShell\v1.0;D:\Astra\flutter\bin

echo [1/3] Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: flutter pub get failed
    exit /b 1
)

echo.
echo [2/3] Checking for Dart errors...
call flutter analyze --no-fatal-infos --no-fatal-warnings
echo.

echo [3/3] Building Release APK...
call flutter build apk --release --dart-define=SUPABASE_URL=https://mqahrwkfwasitlxgbobz.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xYWhyd2tmd2FzaXRseGdib2J6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4MzkyMDgsImV4cCI6MjA4NjQxNTIwOH0.nT_5NET7nUX-Kmow5LyGmycEgUZbT4ZYmJtqS298v0o
if errorlevel 1 (
    echo.
    echo ERROR: Build failed!
    exit /b 1
)

echo.
echo ============================================
echo   BUILD SUCCESSFUL!
echo   APK: build\app\outputs\flutter-apk\app-release.apk
echo ============================================


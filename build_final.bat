@echo off
set PATH=C:\WINDOWS\System32\WindowsPowerShell\v1.0;%PATH%
cd /d "D:\Astra"
call "D:\Astra\flutter\bin\flutter.bat" build apk --release --dart-define=SUPABASE_URL=https://dummy.supabase.co --dart-define=SUPABASE_ANON_KEY=dummy < nul
pause


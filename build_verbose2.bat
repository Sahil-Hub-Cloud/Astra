@echo off
set PATH=%PATH%;C:\WINDOWS\System32\WindowsPowerShell\v1.0;D:\Astra\flutter\bin

echo Building with verbose output...
call flutter build apk --release --verbose --dart-define=SUPABASE_URL=https://mqahrwkfwasitlxgbobz.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xYWhyd2tmd2FzaXRseGdib2J6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4MzkyMDgsImV4cCI6MjA4NjQxNTIwOH0.nT_5NET7nUX-Kmow5LyGmycEgUZbT4ZYmJtqS298v0o > build_verbose2.txt 2>&1
echo Exit code: %errorlevel%


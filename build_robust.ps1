$env:PATH = "C:\WINDOWS\System32\WindowsPowerShell\v1.0;" + $env:PATH
& "D:\Astra\flutter\bin\flutter.bat" build apk --release --dart-define=SUPABASE_URL=https://dummy.supabase.co --dart-define=SUPABASE_ANON_KEY=dummy
read-host "Press Enter to exit"


$files = @(
    'D:\Astra\android\settings.gradle',
    'D:\Astra\android\build.gradle',
    'D:\Astra\android\app\build.gradle'
)

$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)

foreach ($f in $files) {
    if (Test-Path $f) {
        $content = [System.IO.File]::ReadAllText($f)
        [System.IO.File]::WriteAllText($f, $content, $utf8NoBOM)
        Write-Host "Removed BOM from $f"
    } else {
        Write-Warning "File not found: $f"
    }
}

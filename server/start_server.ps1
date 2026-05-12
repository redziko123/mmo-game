# start_server.ps1 – uruchamia serwer MMO na VPS
# Ustaw zmienne środowiskowe bazy danych
$env:DB_HOST = "localhost"
$env:DB_PORT = "5432"
$env:DB_NAME = "mmo_game"
$env:DB_USER = "mmo_user"
$env:DB_PASS = "TWOJE_HASLO"   # ← zmień na swoje hasło

# Zabij ewentualny poprzedni serwer na porcie 9999
$procs = Get-NetTCPConnection -LocalPort 9999 -ErrorAction SilentlyContinue
if ($procs) {
    $procs | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    Start-Sleep 1
    Write-Host "Poprzedni serwer zatrzymany."
}

Write-Host "Startuje serwer MMO..."
python server.py

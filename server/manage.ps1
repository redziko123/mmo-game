# manage.ps1 - Zarzadzanie serwerem MMO
# Uzycie:  .\manage.ps1 start|stop|restart|status|logs|watch

$PYTHON  = "C:\Users\Administrator\AppData\Local\Python\pythoncore-3.14-64\python.exe"
$SCRIPT  = "C:\Users\Administrator\Documents\projects\gd1\server\server.py"
$LOGFILE = "C:\Users\Administrator\Documents\projects\gd1\server\server.log"
$PORT    = 9999

function Get-ServerPid {
    $conn = Get-NetTCPConnection -LocalPort $PORT -ErrorAction SilentlyContinue
    if ($conn) { return $conn.OwningProcess } else { return $null }
}

function Show-Status {
    $pid2 = Get-ServerPid
    if ($pid2) {
        $proc = Get-Process -Id $pid2 -ErrorAction SilentlyContinue
        $ram = [math]::Round($proc.WorkingSet64/1MB, 1)
        Write-Host "[OK] Serwer DZIALA  (PID: $pid2, RAM: $ram MB)" -ForegroundColor Green
        Write-Host "     Uruchomiony: $($proc.StartTime)"
    } else {
        Write-Host "[!!] Serwer NIE DZIALA" -ForegroundColor Red
    }
}

function Start-Server {
    $pid2 = Get-ServerPid
    if ($pid2) {
        Write-Host "[!!] Serwer juz dziala (PID: $pid2)" -ForegroundColor Yellow
        return
    }
    Write-Host "[..] Startuje serwer..." -ForegroundColor Cyan
    Start-Process -FilePath $PYTHON -ArgumentList $SCRIPT `
        -RedirectStandardOutput $LOGFILE `
        -RedirectStandardError "$LOGFILE.err" `
        -WindowStyle Hidden -PassThru | Out-Null
    Start-Sleep 2
    Show-Status
}

function Stop-Server {
    $pid2 = Get-ServerPid
    if ($pid2) {
        Stop-Process -Id $pid2 -Force
        Start-Sleep 1
        Write-Host "[OK] Serwer zatrzymany." -ForegroundColor Yellow
    } else {
        Write-Host "[  ] Serwer byl juz zatrzymany." -ForegroundColor Gray
    }
}

function Restart-Server {
    Stop-Server
    Start-Sleep 1
    Start-Server
}

function Show-Logs {
    if (Test-Path $LOGFILE) {
        Write-Host "=== Ostatnie 40 linii logow ===" -ForegroundColor Cyan
        Get-Content $LOGFILE -Tail 40
        if (Test-Path "$LOGFILE.err") {
            $err = Get-Content "$LOGFILE.err" -Tail 10
            if ($err) {
                Write-Host "=== BLEDY ===" -ForegroundColor Red
                $err
            }
        }
    } else {
        Write-Host "Brak pliku logow." -ForegroundColor Gray
    }
}

switch ($args[0]) {
    "start"   { Start-Server }
    "stop"    { Stop-Server }
    "restart" { Restart-Server }
    "status"  { Show-Status }
    "logs"    { Show-Logs }
    "watch"   { Write-Host "Sledzenie logow (Ctrl+C wyjscie)..." -ForegroundColor Cyan; Get-Content $LOGFILE -Wait -Tail 20 }
    default   {
        Write-Host ""
        Write-Host "  Uzycie: .\manage.ps1 [komenda]" -ForegroundColor Cyan
        Write-Host "    start    - uruchom serwer"
        Write-Host "    stop     - zatrzymaj serwer"
        Write-Host "    restart  - restart serwera"
        Write-Host "    status   - sprawdz czy dziala"
        Write-Host "    logs     - ostatnie logi"
        Write-Host "    watch    - logi na zywo"
        Write-Host ""
        Show-Status
    }
}

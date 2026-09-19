#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$PG_USER = "viraj"
$PG_PASS  = "viraj@123"

function Write-Header {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Magenta
    Write-Host "       SPRING BOOT DATABASE MANAGER" -ForegroundColor Magenta
    Write-Host "       PostgreSQL  |  User: $PG_USER" -ForegroundColor Magenta
    Write-Host "  ============================================================" -ForegroundColor Magenta
    Write-Host ""
}

function Invoke-PsqlFile {
    param ([string]$Sql, [switch]$Tuples)
    $safeDir = "C:\Temp"
    if (-not (Test-Path $safeDir)) { New-Item -ItemType Directory -Path $safeDir -Force | Out-Null }
    $sqlFile = "$safeDir\dbm_cmd.sql"
    $outFile = "$safeDir\dbm_out.txt"
    $errFile = "$safeDir\dbm_err.txt"
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($sqlFile, "${Sql}`n", $utf8)
    $psqlExe = Get-Command psql -ErrorAction SilentlyContinue
    if (-not $psqlExe) { Write-Host "  ERROR: psql not found." -ForegroundColor Red; exit 1 }
    $env:PGPASSWORD = $PG_PASS
    $argList = "-U", $PG_USER, "-h", "localhost", "-d", "postgres", "-f", $sqlFile
    if ($Tuples) { $argList = "-U", $PG_USER, "-h", "localhost", "-d", "postgres", "-t", "-f", $sqlFile }
    $proc = Start-Process -FilePath $psqlExe.Source `
        -ArgumentList $argList `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $outFile `
        -RedirectStandardError  $errFile
    $outText = (Get-Content $outFile -ErrorAction SilentlyContinue) -join "`n"
    $errText = (Get-Content $errFile -ErrorAction SilentlyContinue) -join " "
    Remove-Item $sqlFile, $outFile, $errFile -Force -ErrorAction SilentlyContinue
    $env:PGPASSWORD = ""
    Write-Host "  [DEBUG] SQL  : $Sql" -ForegroundColor DarkGray
    Write-Host "  [DEBUG] exit : $($proc.ExitCode)" -ForegroundColor DarkGray
    Write-Host "  [DEBUG] out  : $outText" -ForegroundColor DarkGray
    if ($errText) { Write-Host "  [DEBUG] err  : $errText" -ForegroundColor DarkGray }
    return @{ ExitCode = $proc.ExitCode; Out = $outText.Trim(); Err = $errText.Trim() }
}

function Get-DbFromProject {
    $dir = $PWD.Path
    for ($i = 0; $i -lt 5; $i++) {
        $candidate = Join-Path $dir "src\main\resources\application.properties"
        if (Test-Path $candidate) {
            Write-Host "  [DEBUG] Found: $candidate" -ForegroundColor DarkGray
            $lines = Get-Content $candidate -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                if ($line -match "^spring\.datasource\.url\s*=\s*.+/([^/?]+)") {
                    Write-Host "  [DEBUG] Detected DB: $($Matches[1])" -ForegroundColor DarkGray
                    return $Matches[1]
                }
                if ($line -match "^spring\.data\.mongodb\.database\s*=\s*(.+)") {
                    Write-Host "  [DEBUG] Detected MongoDB: $($Matches[1].Trim())" -ForegroundColor DarkGray
                    return $Matches[1].Trim()
                }
            }
        }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-AllDatabases {
    $sql = "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN (chr(39) + chr(112) + chr(111) + chr(115) + chr(116) + chr(103) + chr(114) + chr(101) + chr(115) + chr(39)) ORDER BY datname;"
    $sql = "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres' ORDER BY datname;"
    $result = Invoke-PsqlFile -Sql $sql -Tuples
    if ($result.ExitCode -ne 0) {
        Write-Host "  ERROR: Could not connect to PostgreSQL." -ForegroundColor Red
        exit 1
    }
    $dbs = $result.Out -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    return $dbs
}

function Select-Database {
    $detected = Get-DbFromProject
    if ($detected) {
        Write-Host ""
        Write-Host "  Detected database: $detected" -ForegroundColor Green
        $confirm = (Read-Host "  Use this database? [Y/N]").ToUpper()
        if ($confirm -eq "Y") { return $detected }
    }
    else {
        Write-Host "  No project detected in current folder." -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  Fetching your PostgreSQL databases..." -ForegroundColor Cyan
    $dbs = Get-AllDatabases
    if ($dbs.Count -eq 0) { Write-Host "  No databases found." -ForegroundColor Yellow; exit 0 }
    Write-Host ""
    Write-Host "  Your Databases:" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $dbs.Count; $i++) {
        $num = $i + 1
        Write-Host "  [$num] $($dbs[$i])" -ForegroundColor Cyan
    }
    Write-Host ""
    $pick = Read-Host "  Pick a database"
    $idx  = [int]$pick - 1
    if ($idx -lt 0 -or $idx -ge $dbs.Count) { Write-Host "  ERROR: Invalid selection." -ForegroundColor Red; exit 1 }
    return $dbs[$idx]
}

function Get-DisconnectSql {
    param ([string]$DbName)
    $sql = "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DbName' AND pid != pg_backend_pid();"
    return $sql
}

function Invoke-CreateDb {
    param ([string]$DbName)
    Write-Host ""
    Write-Host "  Creating: $DbName" -ForegroundColor Cyan
    $result = Invoke-PsqlFile -Sql "CREATE DATABASE `"$DbName`";"
    if ($result.Out -match "CREATE DATABASE") { Write-Host "  Created: $DbName" -ForegroundColor Green }
    elseif ($result.Err -match "already exists") { Write-Host "  Already exists: $DbName" -ForegroundColor Yellow }
    else { Write-Host "  ERROR: $($result.Err)" -ForegroundColor Red }
}

function Invoke-DropDb {
    param ([string]$DbName)
    Write-Host ""
    Write-Host "  WARNING: This will permanently delete: $DbName" -ForegroundColor Yellow
    $confirm = (Read-Host "  Drop $DbName? [Y/N]").ToUpper()
    if ($confirm -ne "Y") { Write-Host "  Aborted." -ForegroundColor Red; return }
    $disconnectSql = Get-DisconnectSql -DbName $DbName
    Invoke-PsqlFile -Sql $disconnectSql | Out-Null
    $result = Invoke-PsqlFile -Sql "DROP DATABASE IF EXISTS `"$DbName`";"
    if ($result.ExitCode -eq 0) { Write-Host "  Dropped: $DbName" -ForegroundColor Green }
    else { Write-Host "  ERROR: $($result.Err)" -ForegroundColor Red }
}

function Invoke-ResetDb {
    param ([string]$DbName)
    Write-Host ""
    Write-Host "  RESET will DROP then CREATE: $DbName" -ForegroundColor Yellow
    Write-Host "  All tables and data will be erased." -ForegroundColor Yellow
    $confirm = (Read-Host "  Reset $DbName? [Y/N]").ToUpper()
    if ($confirm -ne "Y") { Write-Host "  Aborted." -ForegroundColor Red; return }
    Write-Host "  Disconnecting active sessions..." -ForegroundColor Cyan
    $disconnectSql = Get-DisconnectSql -DbName $DbName
    Invoke-PsqlFile -Sql $disconnectSql | Out-Null
    Write-Host "  Dropping: $DbName" -ForegroundColor Cyan
    $drop = Invoke-PsqlFile -Sql "DROP DATABASE IF EXISTS `"$DbName`";"
    if ($drop.ExitCode -ne 0) { Write-Host "  ERROR dropping: $($drop.Err)" -ForegroundColor Red; return }
    Write-Host "  Dropped." -ForegroundColor DarkGray
    Write-Host "  Creating: $DbName" -ForegroundColor Cyan
    $create = Invoke-PsqlFile -Sql "CREATE DATABASE `"$DbName`";"
    if ($create.Out -match "CREATE DATABASE") {
        Write-Host ""
        Write-Host "  RESET complete: $DbName is fresh and empty." -ForegroundColor Green
        Write-Host "  Start Spring Boot. Hibernate will recreate all tables." -ForegroundColor DarkGray
    }
    else { Write-Host "  ERROR creating: $($create.Err)" -ForegroundColor Red }
}

function Invoke-ListDbs {
    Write-Host ""
    Write-Host "  Your PostgreSQL Databases:" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    $dbs = Get-AllDatabases
    if ($dbs.Count -eq 0) { Write-Host "  No databases found." -ForegroundColor DarkGray; return }
    foreach ($db in $dbs) { Write-Host "  - $db" -ForegroundColor Cyan }
    Write-Host ""
    $total = $dbs.Count
    Write-Host "  Total: $total" -ForegroundColor DarkGray
}

function Invoke-BackupDb {
    param ([string]$DbName)
    $pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
    if (-not $pgDump) { Write-Host "  ERROR: pg_dump not found in PATH." -ForegroundColor Red; return }
    $backupDir = "C:\db-backups"
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
    $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$backupDir\${DbName}_${timestamp}.sql"
    Write-Host "  Backing up: $DbName" -ForegroundColor Cyan
    Write-Host "  Destination: $backupFile" -ForegroundColor DarkGray
    $outFile = "C:\Temp\pgdump_out.txt"
    $errFile = "C:\Temp\pgdump_err.txt"
    $env:PGPASSWORD = $PG_PASS
    $proc = Start-Process -FilePath $pgDump.Source `
        -ArgumentList "-U", $PG_USER, "-h", "localhost", "-d", $DbName, "-f", $backupFile `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $outFile `
        -RedirectStandardError  $errFile
    $errText = (Get-Content $errFile -ErrorAction SilentlyContinue) -join " "
    Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
    $env:PGPASSWORD = ""
    Write-Host "  [DEBUG] exit: $($proc.ExitCode)" -ForegroundColor DarkGray
    if ($errText) { Write-Host "  [DEBUG] err : $errText" -ForegroundColor DarkGray }
    if ($proc.ExitCode -eq 0) {
        $sizeKb  = [math]::Round((Get-Item $backupFile).Length / 1KB, 1)
        $sizeMsg = "Size: $sizeKb KB"
        Write-Host "  Backup complete: $backupFile" -ForegroundColor Green
        Write-Host "  $sizeMsg" -ForegroundColor DarkGray
    }
    else { Write-Host "  ERROR: Backup failed." -ForegroundColor Red }
}

function Invoke-RestoreDb {
    param ([string]$DbName)
    $backupDir = "C:\db-backups"
    if (-not (Test-Path $backupDir)) { Write-Host "  No backups folder at C:\db-backups" -ForegroundColor Yellow; return }
    $backups = Get-ChildItem -Path $backupDir -Filter "${DbName}_*.sql" | Sort-Object LastWriteTime -Descending
    if ($backups.Count -eq 0) { Write-Host "  No backups found for: $DbName" -ForegroundColor Yellow; return }
    Write-Host ""
    Write-Host "  Available backups for $DbName" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $backups.Count; $i++) {
        $num    = $i + 1
        $sizeKb = [math]::Round($backups[$i].Length / 1KB, 1)
        $age    = $backups[$i].LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        $fname  = $backups[$i].Name
        $info   = "  [$num] $fname   $sizeKb KB   $age"
        Write-Host $info -ForegroundColor Cyan
    }
    Write-Host ""
    $pick = Read-Host "  Pick backup to restore"
    $idx  = [int]$pick - 1
    if ($idx -lt 0 -or $idx -ge $backups.Count) { Write-Host "  Invalid selection." -ForegroundColor Red; return }
    $backupFile = $backups[$idx].FullName
    Write-Host "  Restoring from: $backupFile" -ForegroundColor Cyan
    Write-Host "  WARNING: Database will be reset then restored." -ForegroundColor Yellow
    $confirm = (Read-Host "  Restore into $DbName? [Y/N]").ToUpper()
    if ($confirm -ne "Y") { Write-Host "  Aborted." -ForegroundColor Red; return }
    Write-Host "  Resetting database..." -ForegroundColor Cyan
    $disconnectSql = Get-DisconnectSql -DbName $DbName
    Invoke-PsqlFile -Sql $disconnectSql | Out-Null
    Invoke-PsqlFile -Sql "DROP DATABASE IF EXISTS `"$DbName`";" | Out-Null
    Invoke-PsqlFile -Sql "CREATE DATABASE `"$DbName`";" | Out-Null
    $psqlExe = Get-Command psql -ErrorAction SilentlyContinue
    $outFile  = "C:\Temp\restore_out.txt"
    $errFile  = "C:\Temp\restore_err.txt"
    $env:PGPASSWORD = $PG_PASS
    $proc = Start-Process -FilePath $psqlExe.Source `
        -ArgumentList "-U", $PG_USER, "-h", "localhost", "-d", $DbName, "-f", $backupFile `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $outFile `
        -RedirectStandardError  $errFile
    $errText = (Get-Content $errFile -ErrorAction SilentlyContinue) -join " "
    Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
    $env:PGPASSWORD = ""
    Write-Host "  [DEBUG] exit: $($proc.ExitCode)" -ForegroundColor DarkGray
    if ($errText) { Write-Host "  [DEBUG] err : $errText" -ForegroundColor DarkGray }
    if ($proc.ExitCode -eq 0) { Write-Host "  Restore complete: $DbName" -ForegroundColor Green }
    else { Write-Host "  ERROR: Restore failed." -ForegroundColor Red }
}

# ============================================================
#  MAIN
# ============================================================
Write-Header
Write-Host "  [1] Create database" -ForegroundColor Cyan
Write-Host "  [2] Drop database" -ForegroundColor Cyan
Write-Host "  [3] Reset database - DROP and CREATE fresh" -ForegroundColor Cyan
Write-Host "  [4] List all databases" -ForegroundColor Cyan
Write-Host "  [5] Backup database" -ForegroundColor Cyan
Write-Host "  [6] Restore database" -ForegroundColor Cyan
Write-Host ""
$choice = (Read-Host "  Choose [1-6]").Trim()
switch ($choice) {
    "1" { $db = Select-Database; Invoke-CreateDb  -DbName $db }
    "2" { $db = Select-Database; Invoke-DropDb    -DbName $db }
    "3" { $db = Select-Database; Invoke-ResetDb   -DbName $db }
    "4" { Invoke-ListDbs }
    "5" { $db = Select-Database; Invoke-BackupDb  -DbName $db }
    "6" { $db = Select-Database; Invoke-RestoreDb -DbName $db }
    default { Write-Host "  Invalid choice." -ForegroundColor Red; exit 1 }
}
Write-Host ""
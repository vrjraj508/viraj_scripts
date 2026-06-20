# Fix encoding issue
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

# ==============================
# SHARED DEFAULTS
# ==============================
$dbUsername   = "root"
$dbPassword   = "viraj@123"
$type         = "maven-project"
$javaVersion  = "21"
$dependencies = "web%2Cdata-jpa%2Cmysql%2Clombok%2Cdevtools"

$folders = @(
    "controller",
    "service",
    "repository",
    "entity",
    "dto",
    "mapper",
    "exception",
    "config"
)

# ==============================
# HELPER FUNCTION — Generate one Spring Boot project
# ==============================
function New-SpringProject {
    param (
        [string]$projectName,
        [string]$basePackage,
        [string]$dbName,
        [string]$outputDir
    )

    $url = "https://start.spring.io/starter.zip?type=$type&language=java&javaVersion=$javaVersion&groupId=com.basics&artifactId=$projectName&name=$projectName&packageName=$basePackage&dependencies=$dependencies"

    $zipPath = "$outputDir\$projectName.zip"

    Write-Host "   Downloading $projectName..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $zipPath

    Write-Host "   Extracting $projectName..." -ForegroundColor Cyan
    Expand-Archive $zipPath -DestinationPath "$outputDir\$projectName" -Force
    Remove-Item $zipPath -Force

    # ── Find the actual main Application.java location dynamically ──
    # This is the REAL folder where all packages must be created
    $mainJavaFile = Get-ChildItem -Path "$outputDir\$projectName\src\main\java" `
                        -Filter "*Application.java" -Recurse | Select-Object -First 1

    if ($null -eq $mainJavaFile) {
        Write-Host "   WARNING: Could not find main Application.java for $projectName" -ForegroundColor Yellow
        return
    }

    # The folder containing Application.java is the root for all packages
    $mainPath = $mainJavaFile.DirectoryName

    Write-Host "   Package root: $mainPath" -ForegroundColor DarkGray

    # ── Create subpackages INSIDE the same folder as Application.java ──
    foreach ($folder in $folders) {
        $folderPath = "$mainPath\$folder"
        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
        New-Item -ItemType File -Path "$folderPath\.gitkeep" -Force | Out-Null
    }

    # ── Delete auto-generated test file ───────────
    $testFiles = Get-ChildItem -Path "$outputDir\$projectName\src\test" `
                     -Filter "*.java" -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $testFiles) { Remove-Item $file.FullName -Force }

    # ── application.properties ────────────────────
    $resourcesPath = "$outputDir\$projectName\src\main\resources"
    if (-not (Test-Path $resourcesPath)) {
        New-Item -ItemType Directory -Path $resourcesPath -Force | Out-Null
    }

    $jdbcUrl = "jdbc:mysql://localhost:3306/" + $dbName + "?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true"

$properties = @"
# ========================
# SERVER
# ========================
server.port=8080

# ========================
# DATABASE
# ========================
spring.datasource.url=$jdbcUrl
spring.datasource.username=$dbUsername
spring.datasource.password=$dbPassword
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

# ========================
# JPA / HIBERNATE
# ========================
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.database-platform=org.hibernate.dialect.MySQLDialect

# ========================
# APP INFO
# ========================
spring.application.name=$projectName
"@
    Set-Content "$resourcesPath\application.properties" $properties -Encoding UTF8

    Write-Host "   Done: $projectName" -ForegroundColor DarkGreen
}

# ==============================
# OPEN IN INTELLIJ HELPER
# ==============================
function Open-InIntelliJ {
    param ([string]$folderPath)

    $ideaPaths = @(
        "C:\Program Files\JetBrains\IntelliJ IDEA 2025.3.1.1\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA 2024.3\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2024.3\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition\bin\idea64.exe"
    )

    $opened = $false
    foreach ($path in $ideaPaths) {
        if (Test-Path $path) {
            Start-Process -FilePath $path -ArgumentList "`"$folderPath`""
            $opened = $true
            break
        }
    }
    if (-not $opened) {
        try { Start-Process "idea64.exe" -ArgumentList "`"$folderPath`"" }
        catch { Write-Host "Open manually: $folderPath" -ForegroundColor Yellow }
    }
}

# ==============================
# MENU
# ==============================
Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "   SPRING BOOT PROJECT GENERATOR" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  [1]  Single Spring Boot Project"
Write-Host "  [2]  Microservice (Multiple Services)"
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

$choice = Read-Host "Select option (1 or 2)"

# ══════════════════════════════════════════════
# OPTION 1 — SINGLE PROJECT
# ══════════════════════════════════════════════
if ($choice -eq "1") {

    $projectName = Read-Host "Enter project name"
    $dbName      = Read-Host "Enter DB name"
    $basePackage = "com.basics.$($projectName.ToLower())"
    $outputDir   = "$PWD"

    Write-Host ""
    try {
        New-SpringProject -projectName $projectName -basePackage $basePackage -dbName $dbName -outputDir $outputDir

        Open-InIntelliJ -folderPath "$outputDir\$projectName"

        Write-Host ""
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "  SPRING BOOT PROJECT READY!" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "  Project  : $projectName"
        Write-Host "  Package  : $basePackage"
        Write-Host "  Database : $dbName"
        Write-Host "  Java     : 21  |  Build: Maven"
        Write-Host ""
        Write-Host "  Packages created inside main class folder:"
        foreach ($f in $folders) { Write-Host "     -- $f" }
        Write-Host "============================================" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ══════════════════════════════════════════════
# OPTION 2 — MICROSERVICE
# ══════════════════════════════════════════════
elseif ($choice -eq "2") {

    $appName = Read-Host "Enter microservice app name (e.g. ecommerce)"
    $dbName  = Read-Host "Enter DB name (shared across all services)"

    Write-Host ""
    Write-Host "Enter service names one by one (e.g. cart, order, product)." -ForegroundColor Yellow
    Write-Host "Press ENTER with no input when done." -ForegroundColor Yellow
    Write-Host ""

    $services = @()
    while ($true) {
        $svc = Read-Host "  Service name"
        if ([string]::IsNullOrWhiteSpace($svc)) { break }
        $services += $svc.Trim().ToLower()
    }

    if ($services.Count -eq 0) {
        Write-Host "No services entered. Exiting." -ForegroundColor Red
        exit
    }

    $rootFolder = "$PWD\$appName-microservice"
    New-Item -ItemType Directory -Path $rootFolder -Force | Out-Null

    Write-Host ""
    Write-Host "Generating $($services.Count) service(s) inside $appName-microservice..." -ForegroundColor Cyan
    Write-Host ""

    $port = 8081

    foreach ($svc in $services) {
        $projectName = "$svc-service"
        $basePackage = "com.basics.$($appName.ToLower()).$($svc.ToLower())"

        try {
            New-SpringProject -projectName $projectName -basePackage $basePackage -dbName $dbName -outputDir $rootFolder

            # Update port per service
            $propsFile = "$rootFolder\$projectName\src\main\resources\application.properties"
            (Get-Content $propsFile) -replace "server.port=8080", "server.port=$port" |
                Set-Content $propsFile -Encoding UTF8

            Write-Host "   Port assigned: $port" -ForegroundColor DarkCyan
            $port++
        }
        catch {
            Write-Host "ERROR generating $projectName : $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Open-InIntelliJ -folderPath $rootFolder

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  MICROSERVICE PROJECT READY!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  App      : $appName-microservice"
    Write-Host "  Database : $dbName"
    Write-Host "  Java     : 21  |  Build: Maven"
    Write-Host ""
    Write-Host "  Services Generated:"
    $p = 8081
    foreach ($svc in $services) {
        Write-Host "     -- $svc-service   (port $p)"
        $p++
    }
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
}

else {
    Write-Host "Invalid option. Run the script again and choose 1 or 2." -ForegroundColor Red
}
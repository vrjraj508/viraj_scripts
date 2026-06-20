# Fix encoding issue
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

# ==============================
# INPUT — Only 2 questions
# ==============================
$projectName = Read-Host "Enter project name"
$dbName      = Read-Host "Enter DB name"

# Auto-derived values (no prompts)
$basePackage = "com.basics.$projectName".ToLower()
$dbUsername  = "root"
$dbPassword  = "viraj@123"

# ==============================
# CONFIG
# ==============================
$type         = "maven-project"
$javaVersion  = "21"
$dependencies = "web%2Cdata-jpa%2Cmysql%2Clombok%2Cdevtools"

$url = "https://start.spring.io/starter.zip?type=$type&language=java&javaVersion=$javaVersion&groupId=com.basics&artifactId=$projectName&name=$projectName&packageName=$basePackage&dependencies=$dependencies"

try {
    Write-Host ""
    Write-Host "Downloading Spring Boot project..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile "$projectName.zip"

    Write-Host "Extracting project..." -ForegroundColor Cyan
    Expand-Archive "$projectName.zip" -DestinationPath "$projectName" -Force
    Remove-Item "$projectName.zip" -Force

    # ==============================
    # PACKAGE STRUCTURE
    # ==============================
    $packagePath = $basePackage.Replace('.', '\')
    $mainPath    = "$projectName\src\main\java\$packagePath"

    Write-Host "Creating package structure..." -ForegroundColor Cyan

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

    foreach ($folder in $folders) {
        $folderPath = "$mainPath\$folder"
        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
        New-Item -ItemType File -Path "$folderPath\.gitkeep" -Force | Out-Null
        Write-Host "   Created: $folder" -ForegroundColor DarkGreen
    }

    # ==============================
    # DELETE AUTO-GENERATED TEST FILE
    # ==============================
    $testPath  = "$projectName\src\test\java\$packagePath"
    $testFiles = Get-ChildItem -Path $testPath -Filter "*.java" -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $testFiles) {
        Remove-Item $file.FullName -Force
    }

    # ==============================
    # APPLICATION.PROPERTIES
    # ==============================
    Write-Host "Writing application.properties..." -ForegroundColor Cyan

    $resourcesPath = "$projectName\src\main\resources"
    if (-not (Test-Path $resourcesPath)) {
        New-Item -ItemType Directory -Path $resourcesPath -Force | Out-Null
    }

    # NOTE: DB name is placed directly in the JDBC URL string below
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

    # ==============================
    # OPEN IN INTELLIJ
    # ==============================
    Write-Host "Opening project in IntelliJ IDEA..." -ForegroundColor Cyan

    $fullPath  = "$PWD\$projectName"
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
            Start-Process -FilePath $path -ArgumentList "`"$fullPath`""
            $opened = $true
            break
        }
    }

    if (-not $opened) {
        try {
            Start-Process "idea64.exe" -ArgumentList "`"$fullPath`""
        } catch {
            Write-Host "Could not open IntelliJ automatically. Open this folder manually:" -ForegroundColor Yellow
            Write-Host "   $fullPath" -ForegroundColor White
        }
    }

    # ==============================
    # SUCCESS SUMMARY
    # ==============================
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  SPRING BOOT PROJECT READY!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Project Name  : $projectName"
    Write-Host "  Base Package  : $basePackage"
    Write-Host "  Java Version  : 21"
    Write-Host "  Build Tool    : Maven"
    Write-Host "  Database      : $dbName"
    Write-Host "  DB Username   : $dbUsername"
    Write-Host "  Dependencies  : Web, Data JPA, MySQL, Lombok, DevTools"
    Write-Host ""
    Write-Host "  Empty Packages Created:"
    foreach ($folder in $folders) {
        Write-Host "     -- $folder"
    }
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red

    if (Test-Path "$projectName.zip") {
        Remove-Item "$projectName.zip" -Force
    }
}
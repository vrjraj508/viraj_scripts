# =============================================================================
# SPRING BOOT MICROSERVICES GENERATOR
# Usage: create-spring-ms (or .\create-spring-ms.ps1)
# =============================================================================

$ErrorActionPreference = "Stop"

try {
    # Get app details
    $appName = Read-Host "Enter app name"
    $dbName = Read-Host "Enter DB name"
    
    if ([string]::IsNullOrWhiteSpace($appName)) {
        Write-Host "ERROR: App name cannot be empty!" -ForegroundColor Red
        exit 1
    }
    
    if ([string]::IsNullOrWhiteSpace($dbName)) {
        Write-Host "ERROR: DB name cannot be empty!" -ForegroundColor Red
        exit 1
    }
    
    # Collect service names
    $services = @()
    Write-Host ""
    Write-Host "Enter service names (leave blank to finish):" -ForegroundColor Cyan
    
    while ($true) {
        $serviceName = Read-Host "Service name"
        if ([string]::IsNullOrWhiteSpace($serviceName)) {
            break
        }
        $services += $serviceName
    }
    
    if ($services.Count -eq 0) {
        Write-Host "ERROR: At least one service is required!" -ForegroundColor Red
        exit 1
    }
    
    # Create parent folder
    $parentFolder = "$appName-microservice"
    Write-Host ""
    Write-Host "Creating microservice architecture: $parentFolder" -ForegroundColor Cyan
    Write-Host "Services: $($services -join ', ')" -ForegroundColor Gray
    Write-Host "Database: $dbName" -ForegroundColor Gray
    Write-Host ""
    
    New-Item -ItemType Directory -Path $parentFolder -Force | Out-Null
    
    # Port counter starts at 8081
    $port = 8081
    
    # Create each service
    foreach ($service in $services) {
        $serviceName = "$service-service"
        $artifactId = $serviceName.ToLower() -replace '[^a-z0-9]', ''
        $packageName = "com.basics.$artifactId"
        
        Write-Host "Creating $serviceName (port: $port)..." -ForegroundColor Yellow
        
        # Spring Initializr URL
        $url = "https://start.spring.io/starter.zip?type=maven-project&language=java&groupId=com.basics&artifactId=$artifactId&name=$serviceName&packageName=$packageName&javaVersion=17&dependencies=web%2Cdata-jpa%2Cmysql%2Clombok"
        
        # Download
        Invoke-WebRequest -Uri $url -OutFile "$serviceName.zip" -ErrorAction Stop
        
        # Extract
        Expand-Archive -Path "$serviceName.zip" -DestinationPath "$parentFolder\$serviceName" -Force
        Remove-Item "$serviceName.zip"
        
        # Convert package to path
        $packagePath = $packageName.Replace('.', '\')
        $mainPath = "$parentFolder\$serviceName\src\main\java\$packagePath"
        
        # Create folder structure
        $folders = @("controller", "service", "repository", "entity", "dto", "mapper", "exception", "config")
        
        foreach ($folder in $folders) {
            New-Item -ItemType Directory -Path "$mainPath\$folder" -Force | Out-Null
        }
        
        # Create application.properties with CORRECT database name
        $propertiesPath = "$parentFolder\$serviceName\src\main\resources\application.properties"
        
        # FIXED: Using $dbName variable properly
        $properties = @"
# ===============================
# SERVICE CONFIG
# ===============================
spring.application.name=$serviceName
server.port=$port

# ===============================
# DATABASE CONFIG
# ===============================
spring.datasource.url=jdbc:mysql://localhost:3306/${dbName}?useSSL=false&serverTimezone=UTC
spring.datasource.username=root
spring.datasource.password=viraj@123
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

# ===============================
# JPA CONFIG
# ===============================
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.database-platform=org.hibernate.dialect.MySQL8Dialect

# ===============================
# HIKARI CONFIG
# ===============================
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=5
"@
        
        Set-Content -Path $propertiesPath -Value $properties
        
        # Increment port for next service
        $port++
    }
    
    # Create README in parent folder
    $readmePath = "$parentFolder\README.md"
    $readmeContent = @"
# $appName Microservices

## Services

"@
    
    $displayPort = 8081
    foreach ($service in $services) {
        $readmeContent += "- **$service-service**: http://localhost:$displayPort`n"
        $displayPort++
    }
    
    $readmeContent += @"

## Database
``````sql
CREATE DATABASE $dbName;
``````

## Running Services

### Run all services:
``````bash
# Terminal 1
cd cart-service
.\mvnw.cmd spring-boot:run

# Terminal 2
cd order-service
.\mvnw.cmd spring-boot:run

# Terminal 3
cd product-service
.\mvnw.cmd spring-boot:run
``````

## IntelliJ IDEA Setup

### Option 1: Open as Multi-Module Project
1. File → Open
2. Select the **$parentFolder** folder
3. Right-click each service folder → Mark Directory as → Module Root

### Option 2: Open Individual Services
1. File → Open
2. Select **cart-service** folder
3. Repeat for other services in separate windows

## Configuration

- Username: root
- Password: viraj@123
- Database: $dbName
"@
    
    Set-Content -Path $readmePath -Value $readmeContent
    
    # Success message
    Write-Host ""
    Write-Host "SUCCESS: Microservices created!" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Gray
    Write-Host "Location: $PWD\$parentFolder" -ForegroundColor Cyan
    Write-Host "Database: CREATE DATABASE $dbName;" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Services created:" -ForegroundColor Cyan
    
    $displayPort = 8081
    foreach ($service in $services) {
        Write-Host "  - $service-service (port: $displayPort)" -ForegroundColor Gray
        $displayPort++
    }
    
    Write-Host ""
    Write-Host "To open in IntelliJ:" -ForegroundColor Yellow
    Write-Host "  Option 1: Open parent folder: $PWD\$parentFolder" -ForegroundColor Gray
    Write-Host "  Option 2: Open each service individually" -ForegroundColor Gray
    
    # Ask user which way to open
    Write-Host ""
    $openChoice = Read-Host "Open in IntelliJ? (1=Parent folder, 2=First service, N=Skip)"
    
    $projectPath = ""
    
    if ($openChoice -eq "1") {
        $projectPath = "$PWD\$parentFolder"
    } elseif ($openChoice -eq "2") {
        $firstService = "$($services[0])-service"
        $projectPath = "$PWD\$parentFolder\$firstService"
    }
    
    if ($projectPath -ne "") {
        # Try to open in IntelliJ IDEA
        Write-Host "Opening project in IntelliJ IDEA..." -ForegroundColor Yellow
        
        # Common IntelliJ installation paths
        $intellijPaths = @(
            "C:\Program Files\JetBrains\IntelliJ IDEA*\bin\idea64.exe",
            "C:\Program Files (x86)\JetBrains\IntelliJ IDEA*\bin\idea64.exe",
            "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\IDEA-C\*\bin\idea64.exe",
            "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\IDEA-U\*\bin\idea64.exe"
        )
        
        $intellijFound = $false
        
        foreach ($pathPattern in $intellijPaths) {
            $resolvedPaths = Get-Item $pathPattern -ErrorAction SilentlyContinue
            if ($resolvedPaths) {
                $intellijExe = $resolvedPaths | Select-Object -First 1 -ExpandProperty FullName
                if (Test-Path $intellijExe) {
                    Start-Process -FilePath $intellijExe -ArgumentList "`"$projectPath`""
                    $intellijFound = $true
                    Write-Host "Opened in IntelliJ IDEA!" -ForegroundColor Green
                    break
                }
            }
        }
        
        if (-not $intellijFound) {
            Write-Host "WARNING: IntelliJ IDEA not found" -ForegroundColor Yellow
            Write-Host "Please open manually: File -> Open -> $projectPath" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Gray
    Write-Host "Happy coding!" -ForegroundColor Magenta
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
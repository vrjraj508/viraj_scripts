# =============================================================================
# SPRING BOOT MAVEN PROJECT GENERATOR
# Usage: .\spring-create-maven.ps1 [ProjectName]
# =============================================================================

param(
    [string]$ProjectName
)

# If no project name provided, ask for it
if (-not $ProjectName) {
    $ProjectName = Read-Host "Enter your project name (e.g., Spring01RestBasics)"
}

# Validate project name
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    Write-Host "ERROR: Project name cannot be empty!" -ForegroundColor Red
    exit 1
}

# Convert to artifact-friendly name
$artifactId = $ProjectName.ToLower() -replace '[^a-z0-9]', ''
$packageName = "com.basics.$artifactId"

Write-Host ""
Write-Host "Creating Spring Boot MAVEN project: $ProjectName" -ForegroundColor Cyan
Write-Host "Build Tool: Maven" -ForegroundColor Magenta
Write-Host "Artifact ID: $artifactId" -ForegroundColor Gray
Write-Host "Package: $packageName" -ForegroundColor Gray
Write-Host ""

# Spring Initializr URL for MAVEN (single line to avoid & issues)
$url = "https://start.spring.io/starter.zip?type=maven-project&language=java&bootVersion=3.2.5&baseDir=$ProjectName&groupId=com.basics&artifactId=$artifactId&name=$ProjectName&packageName=$packageName&javaVersion=17&dependencies=web,data-jpa,mysql,lombok"

# Download project
Write-Host "Downloading from Spring Initializr..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $url -OutFile "$ProjectName.zip" -ErrorAction Stop
} catch {
    Write-Host "ERROR: Failed to download project: $_" -ForegroundColor Red
    exit 1
}

# Extract project
Write-Host "Extracting project..." -ForegroundColor Yellow
Expand-Archive "$ProjectName.zip" -DestinationPath "." -Force
Remove-Item "$ProjectName.zip"

# Get full path before changing directory
$projectPath = Join-Path (Get-Location) $ProjectName

# Navigate into project
Set-Location $ProjectName

# Create application.properties
Write-Host "Configuring application.properties..." -ForegroundColor Yellow
$dbName = $artifactId -replace '-', ''
$properties = @"
# ===============================
# DATABASE CONFIG
# ===============================
spring.datasource.url=jdbc:mysql://localhost:3306/$dbName?useSSL=false&serverTimezone=UTC
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

# ===============================
# SERVER CONFIG
# ===============================
server.port=8080
"@

$properties | Out-File -FilePath "src/main/resources/application.properties" -Encoding UTF8

# Create folder structure
Write-Host "Creating package structure..." -ForegroundColor Yellow
$basePath = "src/main/java/$($packageName.Replace('.', '/'))"

$folders = @(
    "config",
    "controller",
    "dtos",
    "entity",
    "exceptions",
    "repository",
    "service",
    "util"
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path "$basePath/$folder" -Force | Out-Null
}

# Create .gitignore
Write-Host "Creating .gitignore..." -ForegroundColor Yellow
$gitignore = @"
HELP.md
target/
!.mvn/wrapper/maven-wrapper.jar
!**/src/main/**/target/
!**/src/test/**/target/

### STS ###
.apt_generated
.classpath
.factorypath
.project
.settings
.springBeans
.sts4-cache

### IntelliJ IDEA ###
.idea
*.iws
*.iml
*.ipr

### NetBeans ###
/nbproject/private/
/nbbuild/
/dist/
/nbdist/
/.nb-gradle/
build/
!**/src/main/**/build/
!**/src/test/**/build/

### VS Code ###
.vscode/

### Maven ###
.mvn/
mvnw
mvnw.cmd
"@

$gitignore | Out-File -FilePath ".gitignore" -Encoding UTF8

# Success message
Write-Host ""
Write-Host "SUCCESS: Maven project created!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Gray
Write-Host "Location: $projectPath" -ForegroundColor Cyan
Write-Host "Database: $dbName" -ForegroundColor Cyan
Write-Host "Build Tool: Maven (pom.xml)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Create MySQL database:" -ForegroundColor White
Write-Host "     CREATE DATABASE $dbName;" -ForegroundColor Gray
Write-Host "  2. Run with Maven:" -ForegroundColor White
Write-Host "     .\mvnw.cmd spring-boot:run" -ForegroundColor Gray
Write-Host ""

# Try to open in IntelliJ IDEA
Write-Host "Opening project in IntelliJ IDEA..." -ForegroundColor Yellow

# Common IntelliJ installation paths
$intellijPaths = @(
    "${env:ProgramFiles}\JetBrains\IntelliJ IDEA Community Edition*\bin\idea64.exe",
    "${env:ProgramFiles}\JetBrains\IntelliJ IDEA*\bin\idea64.exe",
    "${env:ProgramFiles(x86)}\JetBrains\IntelliJ IDEA Community Edition*\bin\idea64.exe",
    "${env:ProgramFiles(x86)}\JetBrains\IntelliJ IDEA*\bin\idea64.exe",
    "$env:LOCALAPPDATA\Programs\IntelliJ IDEA Community Edition*\bin\idea64.exe",
    "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\IDEA-C\*\bin\idea64.exe",
    "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\IDEA-U\*\bin\idea64.exe"
)

$intellijFound = $false

foreach ($pathPattern in $intellijPaths) {
    $resolvedPaths = Get-Item $pathPattern -ErrorAction SilentlyContinue
    if ($resolvedPaths) {
        $intellijExe = $resolvedPaths | Select-Object -First 1 -ExpandProperty FullName
        if (Test-Path $intellijExe) {
            Write-Host "  Found IntelliJ at: $intellijExe" -ForegroundColor Gray
            Start-Process $intellijExe -ArgumentList $projectPath
            $intellijFound = $true
            Write-Host "  Opened in IntelliJ IDEA!" -ForegroundColor Green
            break
        }
    }
}

if (-not $intellijFound) {
    Write-Host "  WARNING: IntelliJ IDEA not found automatically" -ForegroundColor Yellow
    Write-Host "  Please open manually:" -ForegroundColor White
    Write-Host "    File -> Open -> $projectPath" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Gray
Write-Host "Happy coding with Maven!" -ForegroundColor Magenta
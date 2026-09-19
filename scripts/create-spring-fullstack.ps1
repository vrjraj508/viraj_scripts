$ErrorActionPreference = "Stop"

# ================================================
# SPRING BOOT PROFILES
# ================================================
$profiles = @{
    "1" = @{ Name = "REST API Only";                   Deps = "web,lombok,devtools,validation,actuator" }
    "2" = @{ Name = "REST API + JPA";                  Deps = "web,data-jpa,lombok,devtools,validation,actuator" }
    "3" = @{ Name = "REST API + JPA + Security";       Deps = "web,data-jpa,security,lombok,devtools,validation,actuator" }
    "4" = @{ Name = "REST API + JPA + Kafka";          Deps = "web,data-jpa,kafka,lombok,devtools,validation,actuator" }
    "5" = @{ Name = "Full (JPA+Security+Kafka+Redis)"; Deps = "web,data-jpa,security,oauth2-resource-server,kafka,data-redis,cache,lombok,devtools,validation,actuator" }
}

# ================================================
# DATABASE PROFILES
# ================================================
$dbProfiles = @{
    "1" = @{ Name = "PostgreSQL";     Dep = "postgresql"; Driver = "org.postgresql.Driver";    Dialect = "org.hibernate.dialect.PostgreSQLDialect" }
    "2" = @{ Name = "MySQL";          Dep = "mysql";      Driver = "com.mysql.cj.jdbc.Driver"; Dialect = "org.hibernate.dialect.MySQLDialect" }
    "3" = @{ Name = "H2 (In-Memory)"; Dep = "h2";         Driver = "org.h2.Driver";            Dialect = "org.hibernate.dialect.H2Dialect" }
    "4" = @{ Name = "No Database";    Dep = "";           Driver = "";                         Dialect = "" }
}

# ================================================
# OPEN INTELLIJ
# ================================================
function Open-InIntelliJ {
    param ([string]$FolderPath)
    $ideaPaths = @(
        "C:\Program Files\JetBrains\IntelliJ IDEA 2025.3.1.1\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA 2024.3\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2025.1\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2024.3\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition\bin\idea64.exe"
    )
    foreach ($p in $ideaPaths) {
        if (Test-Path $p) {
            Start-Process -FilePath $p -ArgumentList "`"$FolderPath`""
            Write-Host "  Opening IntelliJ..." -ForegroundColor Cyan
            return
        }
    }
    try { Start-Process "idea64.exe" -ArgumentList "`"$FolderPath`"" }
    catch { Write-Host "  Open manually: $FolderPath" -ForegroundColor Yellow }
}

# ================================================
# FILE WRITER
# ================================================
function Write-TextFile {
    param ([string]$FilePath, [string[]]$Lines)
    $dir = Split-Path $FilePath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $FilePath -Value $Lines -Encoding UTF8
}

# ================================================
# HEADER
# ================================================
Clear-Host
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host "    FULLSTACK PROJECT CREATOR               " -ForegroundColor Magenta
Write-Host "    Spring Boot 3.x  +  React (Vite)        " -ForegroundColor Magenta
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host ""

# ================================================
# COLLECT INPUTS
# ================================================
$projectName = (Read-Host "  Project name (e.g. bankflow)").Trim().ToLower()
if ([string]::IsNullOrWhiteSpace($projectName)) {
    Write-Host "  ERROR: Project name required." -ForegroundColor Red; exit 1
}

Write-Host ""
Write-Host "  Spring Boot Profile:" -ForegroundColor Yellow
foreach ($k in ($profiles.Keys | Sort-Object)) {
    Write-Host "  [$k] $($profiles[$k].Name)" -ForegroundColor Cyan
}
Write-Host ""
$profileKey = (Read-Host "  Choose [1-5]").Trim()
if (-not $profiles.ContainsKey($profileKey)) {
    Write-Host "  ERROR: Invalid choice." -ForegroundColor Red; exit 1
}
$selectedProfile = $profiles[$profileKey]

Write-Host ""
Write-Host "  Database:" -ForegroundColor Yellow
foreach ($k in ($dbProfiles.Keys | Sort-Object)) {
    Write-Host "  [$k] $($dbProfiles[$k].Name)" -ForegroundColor Cyan
}
Write-Host ""
$dbKey = (Read-Host "  Choose [1-4]").Trim()
if (-not $dbProfiles.ContainsKey($dbKey)) {
    Write-Host "  ERROR: Invalid choice." -ForegroundColor Red; exit 1
}
$selectedDb = $dbProfiles[$dbKey]

$dbName = ""
if ($dbKey -ne "4") {
    $dbName = (Read-Host "  Database name (e.g. ${projectName}_db)").Trim()
    if ([string]::IsNullOrWhiteSpace($dbName)) {
        Write-Host "  ERROR: Database name required." -ForegroundColor Red; exit 1
    }
}

$backendPort = (Read-Host "  Backend port [Enter = 8080]").Trim()
if ([string]::IsNullOrWhiteSpace($backendPort)) { $backendPort = "8080" }

$frontendPort = (Read-Host "  Frontend port [Enter = 3000]").Trim()
if ([string]::IsNullOrWhiteSpace($frontendPort)) { $frontendPort = "3000" }

# ================================================
# SETUP PATHS AND VARIABLES
# ================================================
$rootDir     = "$($PWD.Path)\$projectName"
$backendDir  = "$rootDir\$projectName-backend"
$frontendDir = "$rootDir\$projectName-frontend"
$groupId     = "com.$projectName"

# Build final deps string
$allDeps = $selectedProfile.Deps
if ($selectedDb.Dep -ne "") { $allDeps = "$allDeps,$($selectedDb.Dep)" }
$encodedDeps = $allDeps.Replace(",", "%2C")

# Spring Initializr URL
$initUrl = "https://start.spring.io/starter.zip" +
    "?type=maven-project&language=java&javaVersion=21&bootVersion=3.5.0" +
    "&groupId=$groupId" +
    "&artifactId=${projectName}-backend" +
    "&name=${projectName}-backend" +
    "&packageName=$groupId" +
    "&dependencies=$encodedDeps"

$originalLocation = $PWD.Path

Write-Host ""
Write-Host "  Creating root folder..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $rootDir -Force | Out-Null

# ================================================
# DOWNLOAD SPRING BOOT PROJECT
# ================================================
Write-Host "  Downloading from start.spring.io..." -ForegroundColor Cyan
$zipPath = "$rootDir\backend.zip"
try {
    Invoke-WebRequest -Uri $initUrl -OutFile $zipPath -ErrorAction Stop
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "  Extracting..." -ForegroundColor Cyan
Expand-Archive -Path $zipPath -DestinationPath $backendDir -Force
Remove-Item $zipPath -Force
Write-Host "  Spring Boot ready." -ForegroundColor Green

# ================================================
# FIND MAIN SOURCE DIRECTORY
# ================================================
$appJava = Get-ChildItem -Path "$backendDir\src\main\java" -Filter "*Application.java" -Recurse |
           Select-Object -First 1
if (-not $appJava) {
    Write-Host "  ERROR: Could not find Application.java" -ForegroundColor Red; exit 1
}
$mainSrc   = $appJava.DirectoryName
$resources = "$backendDir\src\main\resources"

# ================================================
# CREATE PACKAGE FOLDERS
# ================================================
$packages = [System.Collections.Generic.List[string]]::new()
$packages.AddRange([string[]]@("controller", "service", "dto", "exception", "config", "utils"))

if ($allDeps -like "*data-jpa*")   { $packages.AddRange([string[]]@("repository", "entity", "mapper")) }
if ($allDeps -like "*security*")   { $packages.AddRange([string[]]@("security", "filter")) }
if ($allDeps -like "*kafka*")      { $packages.AddRange([string[]]@("event", "producer", "consumer")) }
if ($allDeps -like "*data-redis*") { $packages.Add("cache") }

Write-Host "  Creating packages..." -ForegroundColor Cyan
foreach ($pkg in $packages) {
    $fullPkg = "$mainSrc\$pkg"
    New-Item -ItemType Directory -Path $fullPkg -Force | Out-Null
    New-Item -ItemType File -Path "$fullPkg\.gitkeep" -Force | Out-Null
    Write-Host "    + $pkg" -ForegroundColor DarkGreen
}

# Remove generated test file (start clean)
Get-ChildItem "$backendDir\src\test" -Filter "*.java" -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item $_.FullName -Force }

# ================================================
# DELETE application.properties
# Replace with application.yml
# ================================================
$propsFile = "$resources\application.properties"
if (Test-Path $propsFile) { Remove-Item $propsFile -Force }

$yml = [System.Collections.Generic.List[string]]::new()

$yml.Add("spring:")
$yml.Add("  application:")
$yml.Add("    name: ${projectName}-backend")
$yml.Add("")

# --- Database ---
if ($dbKey -eq "1") {
    $yml.Add("  datasource:")
    $yml.Add("    url: jdbc:postgresql://localhost:5432/$dbName")
    $yml.Add("    username: postgres")
    $yml.Add("    password: postgres")
    $yml.Add("    driver-class-name: org.postgresql.Driver")
    $yml.Add("    hikari:")
    $yml.Add("      maximum-pool-size: 10")
    $yml.Add("      minimum-idle: 2")
    $yml.Add("")
    $yml.Add("  jpa:")
    $yml.Add("    hibernate:")
    $yml.Add("      ddl-auto: update")
    $yml.Add("    show-sql: true")
    $yml.Add("    open-in-view: false")
    $yml.Add("    properties:")
    $yml.Add("      hibernate:")
    $yml.Add("        format_sql: true")
    $yml.Add("        dialect: org.hibernate.dialect.PostgreSQLDialect")
}
elseif ($dbKey -eq "2") {
    $mysqlUrl = "jdbc:mysql://localhost:3306/" + $dbName + "?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true"
    $yml.Add("  datasource:")
    $yml.Add("    url: $mysqlUrl")
    $yml.Add("    username: root")
    $yml.Add("    password: root")
    $yml.Add("    driver-class-name: com.mysql.cj.jdbc.Driver")
    $yml.Add("    hikari:")
    $yml.Add("      maximum-pool-size: 10")
    $yml.Add("      minimum-idle: 2")
    $yml.Add("")
    $yml.Add("  jpa:")
    $yml.Add("    hibernate:")
    $yml.Add("      ddl-auto: update")
    $yml.Add("    show-sql: true")
    $yml.Add("    open-in-view: false")
    $yml.Add("    properties:")
    $yml.Add("      hibernate:")
    $yml.Add("        format_sql: true")
    $yml.Add("        dialect: org.hibernate.dialect.MySQLDialect")
}
elseif ($dbKey -eq "3") {
    $yml.Add("  datasource:")
    $yml.Add("    url: jdbc:h2:mem:$dbName")
    $yml.Add("    driver-class-name: org.h2.Driver")
    $yml.Add("    username: sa")
    $yml.Add("    password: ''")
    $yml.Add("")
    $yml.Add("  h2:")
    $yml.Add("    console:")
    $yml.Add("      enabled: true")
    $yml.Add("      path: /h2-console")
    $yml.Add("")
    $yml.Add("  jpa:")
    $yml.Add("    hibernate:")
    $yml.Add("      ddl-auto: create-drop")
    $yml.Add("    show-sql: true")
    $yml.Add("    open-in-view: false")
    $yml.Add("    database-platform: org.hibernate.dialect.H2Dialect")
}

# --- Kafka ---
if ($allDeps -like "*kafka*") {
    $yml.Add("")
    $yml.Add("  kafka:")
    $yml.Add("    bootstrap-servers: localhost:9092")
    $yml.Add("    producer:")
    $yml.Add("      key-serializer: org.apache.kafka.common.serialization.StringSerializer")
    $yml.Add("      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer")
    $yml.Add("    consumer:")
    $yml.Add("      group-id: ${projectName}-group")
    $yml.Add("      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer")
    $yml.Add("      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer")
    $yml.Add("      auto-offset-reset: earliest")
}

# --- Redis ---
if ($allDeps -like "*data-redis*") {
    $yml.Add("")
    $yml.Add("  data:")
    $yml.Add("    redis:")
    $yml.Add("      host: localhost")
    $yml.Add("      port: 6379")
    $yml.Add("")
    $yml.Add("  cache:")
    $yml.Add("    type: redis")
}

# --- Security ---
if ($allDeps -like "*security*") {
    $yml.Add("")
    $yml.Add("  security:")
    $yml.Add("    oauth2:")
    $yml.Add("      resourceserver:")
    $yml.Add("        jwt:")
    $yml.Add("          issuer-uri: http://localhost:8180/realms/${projectName}-realm")
}

$yml.Add("")
$yml.Add("server:")
$yml.Add("  port: $backendPort")
$yml.Add("")
$yml.Add("management:")
$yml.Add("  endpoints:")
$yml.Add("    web:")
$yml.Add("      exposure:")
$yml.Add("        include: health,metrics,info")
$yml.Add("  endpoint:")
$yml.Add("    health:")
$yml.Add("      show-details: always")
$yml.Add("")
$yml.Add("logging:")
$yml.Add("  level:")
$yml.Add("    root: INFO")
$yml.Add("    ${groupId}: DEBUG")

Write-TextFile -FilePath "$resources\application.yml" -Lines $yml
Write-Host "  application.yml written." -ForegroundColor Green

# ================================================
# DOCKERFILE (backend)
# ================================================
Write-TextFile -FilePath "$backendDir\Dockerfile" -Lines @(
    "FROM maven:3.9-eclipse-temurin-21 AS builder",
    "WORKDIR /app",
    "COPY pom.xml .",
    "RUN mvn dependency:go-offline -B",
    "COPY src ./src",
    "RUN mvn clean package -DskipTests -B",
    "",
    "FROM eclipse-temurin:21-jre-alpine",
    "WORKDIR /app",
    "COPY --from=builder /app/target/*.jar app.jar",
    "EXPOSE $backendPort",
    "ENTRYPOINT [""java"", ""-jar"", ""app.jar""]"
)

# .gitignore (backend)
Write-TextFile -FilePath "$backendDir\.gitignore" -Lines @(
    "target/",
    ".idea/",
    "*.iml",
    "*.log",
    ".env"
)

Write-Host "  Backend files created." -ForegroundColor Green

# ================================================
# REACT FRONTEND
# ================================================
Write-Host ""
Write-Host "  Setting up React frontend..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $frontendDir -Force | Out-Null

# Detect Node
$hasNode = $false
try {
    $nodeVer = node --version 2>&1
    if ($LASTEXITCODE -eq 0) { $hasNode = $true }
} catch {}

if ($hasNode) {
    Write-Host "  Node $nodeVer found. Scaffolding with Vite..." -ForegroundColor Cyan
    Push-Location $rootDir
    try {
        echo "y" | npm create vite@latest "${projectName}-frontend" -- --template react
        Write-Host "  Vite scaffold done." -ForegroundColor Green
        Write-Host "  Running npm install inside frontend..." -ForegroundColor Cyan
        Set-Location "$rootDir\${projectName}-frontend"
        npm install
        Write-Host "  npm install done." -ForegroundColor Green
    } catch {
        Write-Host "  Vite scaffold failed. Creating folder structure manually." -ForegroundColor Yellow
        $hasNode = $false
    }
    Pop-Location
} else {
    Write-Host "  Node.js not found - creating folder structure only." -ForegroundColor Yellow
}

# ================================================
# FRONTEND FOLDER STRUCTURE
# Always created whether Vite ran or not
# ================================================
$frontendFolders = @(
    "src\api",
    "src\assets",
    "src\components",
    "src\hooks",
    "src\pages",
    "src\routes",
    "src\context",
    "src\utils",
    "public"
)
foreach ($folder in $frontendFolders) {
    $fp = "$frontendDir\$folder"
    if (-not (Test-Path $fp)) {
        New-Item -ItemType Directory -Path $fp -Force | Out-Null
    }
    $contents = Get-ChildItem $fp -ErrorAction SilentlyContinue
    if (-not $contents) {
        New-Item -ItemType File -Path "$fp\.gitkeep" -Force | Out-Null
    }
    Write-Host "    + $folder" -ForegroundColor DarkGreen
}

# ================================================
# FRONTEND CONFIG FILES
# These are always written (override Vite defaults)
# ================================================

# vite.config.js
# Vite already generated this with correct imports — we read it and inject our server config
$viteConfigFile = "$frontendDir\vite.config.js"
if (Test-Path $viteConfigFile) {
    $original = Get-Content $viteConfigFile -Raw
    $importSection = ($original -split 'export default')[0].TrimEnd()
    $serverConfig = @"

export default defineConfig({
  plugins: [react()],
  server: {
    port: $frontendPort,
    proxy: {
      '/api': {
        target: 'http://localhost:$backendPort',
        changeOrigin: true,
        secure: false
      }
    }
  }
})
"@
    Set-Content -Path $viteConfigFile -Value ($importSection + $serverConfig) -Encoding UTF8
} else {
    $fallback = "import { defineConfig } from 'vite'`nexport default defineConfig({ server: { port: $frontendPort } })"
    Set-Content -Path $viteConfigFile -Value $fallback -Encoding UTF8
}

# .env
Write-TextFile -FilePath "$frontendDir\.env" -Lines @(
    "VITE_API_BASE_URL=http://localhost:$backendPort/api",
    "VITE_APP_NAME=$projectName"
)

# .gitignore
Write-TextFile -FilePath "$frontendDir\.gitignore" -Lines @(
    "node_modules/",
    "dist/",
    ".env.local",
    "*.log",
    ".DS_Store"
)

# src/api/api.js — simple Axios instance (no interceptors, no complexity)
Write-TextFile -FilePath "$frontendDir\src\api\api.js" -Lines @(
    "import axios from 'axios'",
    "",
    "const api = axios.create({",
    "  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',",
    "  timeout: 10000,",
    "  headers: {",
    "    'Content-Type': 'application/json'",
    "  }",
    "})",
    "",
    "export default api"
)

# src/utils/constants.js
Write-TextFile -FilePath "$frontendDir\src\utils\constants.js" -Lines @(
    "export const APP_NAME = import.meta.env.VITE_APP_NAME || '$projectName'",
    "export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL"
)

# package.json — only if Node was not available (Vite generates its own)
if (-not $hasNode) {
    Write-TextFile -FilePath "$frontendDir\package.json" -Lines @(
        "{",
        "  `"name`": `"${projectName}-frontend`",",
        "  `"version`": `"1.0.0`",",
        "  `"type`": `"module`",",
        "  `"scripts`": {",
        "    `"dev`": `"vite`",",
        "    `"build`": `"vite build`",",
        "    `"preview`": `"vite preview`"",
        "  },",
        "  `"dependencies`": {",
        "    `"react`": `"^18.3.1`",",
        "    `"react-dom`": `"^18.3.1`",",
        "    `"react-router-dom`": `"^6.28.0`",",
        "    `"axios`": `"^1.7.9`"",
        "  },",
        "  `"devDependencies`": {",
        "    `"@vitejs/plugin-react`": `"^4.3.4`",",
        "    `"vite`": `"^6.0.5`"",
        "  }",
        "}"
    )

    Write-TextFile -FilePath "$frontendDir\index.html" -Lines @(
        "<!doctype html>",
        "<html lang=`"en`">",
        "  <head>",
        "    <meta charset=`"UTF-8`" />",
        "    <meta name=`"viewport`" content=`"width=device-width, initial-scale=1.0`" />",
        "    <title>$projectName</title>",
        "  </head>",
        "  <body>",
        "    <div id=`"root`"></div>",
        "    <script type=`"module`" src=`"/src/main.jsx`"></script>",
        "  </body>",
        "</html>"
    )
}

# ================================================
# ROOT FILES
# ================================================
Write-TextFile -FilePath "$rootDir\.gitignore" -Lines @(
    "**/target/",
    "**/node_modules/",
    "**/dist/",
    "**/.idea/",
    "**/*.iml",
    "**/*.log"
)

Write-TextFile -FilePath "$rootDir\README.md" -Lines @(
    "# $projectName",
    "",
    "Full stack - Spring Boot $backendPort + React $frontendPort",
    "",
    "## Run Backend",
    "``````bash",
    "cd ${projectName}-backend",
    "mvn spring-boot:run",
    "``````",
    "",
    "## Run Frontend",
    "``````bash",
    "cd ${projectName}-frontend",
    "npm install",
    "npm run dev",
    "``````",
    "",
    "React proxies /api calls to http://localhost:$backendPort"
)

# ================================================
# OPEN IN INTELLIJ
# ================================================
Open-InIntelliJ -FolderPath $rootDir

# ================================================
# DONE
# ================================================
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host "   PROJECT READY!" -ForegroundColor Green
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Name      : $projectName" -ForegroundColor White
Write-Host "  Profile   : $($selectedProfile.Name)" -ForegroundColor White
if ($dbName -ne "") {
    Write-Host "  Database  : $($selectedDb.Name) - $dbName" -ForegroundColor White
} else {
    Write-Host "  Database  : $($selectedDb.Name)" -ForegroundColor White
}
Write-Host "  Backend   : http://localhost:$backendPort" -ForegroundColor White
Write-Host "  Frontend  : http://localhost:$frontendPort" -ForegroundColor White
Write-Host "  Location  : $rootDir" -ForegroundColor White
Write-Host ""
Write-Host "  NEXT:" -ForegroundColor Yellow
Write-Host "  1. IntelliJ opened - let Maven import finish" -ForegroundColor White
if ($hasNode) {
    Write-Host "  2. cd ${projectName}-frontend" -ForegroundColor White
    Write-Host "  3. npm run dev" -ForegroundColor White
} else {
    Write-Host "  2. Install Node.js from https://nodejs.org" -ForegroundColor White
    Write-Host "  3. cd ${projectName}-frontend && npm install && npm run dev" -ForegroundColor White
}
Write-Host ""

# Return to original directory so script can be run again from same terminal
Set-Location $originalLocation
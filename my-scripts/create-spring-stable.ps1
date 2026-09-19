#requires -Version 5.1
$ErrorActionPreference = "Stop"

# ============================================================
# FULLSTACK PROJECT CREATOR v4.0
# Spring Boot + React/Vite starter that works together
#
# Design goals:
#   - Generate the backend with Spring Initializr
#   - Generate a minimal, pinned React/Vite frontend
#   - React calls /api/... through the Vite dev proxy
#   - Spring Boot has global CORS configured as well
#   - A real /api/health endpoint proves the connection
#   - No database is required for the basic profile
#   - Optional PostgreSQL/JPA profile is included
# ============================================================

function Get-SafeName {
    param([string]$Raw)

    $s = $Raw.Trim().ToLower()
    $s = $s -replace '[_\s]+', '-'
    $s = $s -replace '[^a-z0-9\-]', ''
    $s = $s.Trim('-')

    if ([string]::IsNullOrWhiteSpace($s)) {
        throw "Project name is empty after sanitization."
    }

    return $s
}

function Get-GroupId {
    param([string]$SafeName)

    $part = ($SafeName -replace '-', '') -replace '[^a-z0-9]', ''
    if ([string]::IsNullOrWhiteSpace($part)) {
        throw "Could not create a valid Java groupId."
    }

    return "com.$part"
}

function Get-DbName {
    param([string]$SafeName)
    return (($SafeName -replace '-', '_') + "_db")
}

function Get-FreePort {
    param([int]$Start)

    for ($port = $Start; $port -lt ($Start + 200); $port++) {
        try {
            $inUse = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
            if (-not $inUse) {
                return $port
            }
        } catch {
            # If Get-NetTCPConnection is unavailable, fall back to the first port.
            return $Start
        }
    }

    throw "Could not find a free port starting at $Start."
}

function Write-TextFile {
    param(
        [string]$FilePath,
        [string[]]$Lines
    )

    $dir = Split-Path $FilePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # UTF-8 without BOM. This avoids Node/Vite parsing problems on Windows.
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($FilePath, $Lines, $utf8NoBom)
}

function Test-Command {
    param([string]$Name)

    try {
        $null = Get-Command $Name -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-BootVersion {
    Write-Host "  Reading current Spring Boot metadata..." -ForegroundColor Cyan

    try {
        $headers = @{
            "Accept" = "application/vnd.initializr.v2.3+json"
            "User-Agent" = "FullstackProjectCreator/4.0"
        }

        $metadata = Invoke-RestMethod `
            -Uri "https://start.spring.io/" `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop

        $version = $metadata.bootVersion.default

        if ([string]::IsNullOrWhiteSpace($version)) {
            throw "Spring Initializr did not return a default Boot version."
        }

        Write-Host "  Spring Boot: $version" -ForegroundColor Green
        return $version
    } catch {
        throw "Could not read Spring Initializr metadata: $($_.Exception.Message)"
    }
}

function Download-SpringBootProject {
    param(
        [string]$BootVersion,
        [string]$ProjectName,
        [string]$GroupId,
        [string]$BackendDir,
        [string]$Dependencies
    )

    $encodedDeps = [System.Uri]::EscapeDataString($Dependencies)

    $uri =
        "https://start.spring.io/starter.zip" +
        "?type=maven-project" +
        "&language=java" +
        "&javaVersion=21" +
        "&bootVersion=$BootVersion" +
        "&groupId=$([System.Uri]::EscapeDataString($GroupId))" +
        "&artifactId=$([System.Uri]::EscapeDataString("${ProjectName}-backend"))" +
        "&name=$([System.Uri]::EscapeDataString("${ProjectName}-backend"))" +
        "&packageName=$([System.Uri]::EscapeDataString($GroupId))" +
        "&dependencies=$encodedDeps"

    $zipPath = Join-Path (Split-Path $BackendDir -Parent) "backend.zip"

    Write-Host "  Downloading Spring Boot project..." -ForegroundColor Cyan

    try {
        $headers = @{ "User-Agent" = "FullstackProjectCreator/4.0" }

        Invoke-WebRequest `
            -Uri $uri `
            -Headers $headers `
            -OutFile $zipPath `
            -UseBasicParsing `
            -ErrorAction Stop

        if (-not (Test-Path $zipPath)) {
            throw "Spring Initializr did not create the ZIP file."
        }

        $size = (Get-Item $zipPath).Length
        if ($size -lt 1000) {
            throw "Downloaded Spring project is unexpectedly small ($size bytes)."
        }

        New-Item -ItemType Directory -Path $BackendDir -Force | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath $BackendDir -Force
        Remove-Item $zipPath -Force

        Write-Host "  Spring Boot project created." -ForegroundColor Green
    } catch {
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        }

        throw "Spring Boot generation failed: $($_.Exception.Message)"
    }
}

function Write-BackendStarterFiles {
    param(
        [string]$BackendDir,
        [string]$ProjectName,
        [string]$GroupId,
        [int]$BackendPort,
        [int]$FrontendPort,
        [bool]$UsePostgres,
        [bool]$UseH2,
        [string]$DbName
    )

    $mainJava = Get-ChildItem `
        -Path "$BackendDir\src\main\java" `
        -Filter "*Application.java" `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $mainJava) {
        throw "Could not find the generated Spring Boot Application.java."
    }

    $mainPackageDir = $mainJava.DirectoryName
    $resourcesDir = "$BackendDir\src\main\resources"

    $controllerDir = "$mainPackageDir\controller"
    $configDir = "$mainPackageDir\config"

    New-Item -ItemType Directory -Path $controllerDir -Force | Out-Null
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null

    # --------------------------------------------------------
    # /api/health
    # This is intentionally separate from Actuator.
    # The frontend uses this endpoint to prove frontend->backend.
    # --------------------------------------------------------
    Write-TextFile "$controllerDir\HealthController.java" @(
        "package $GroupId.controller;",
        "",
        "import java.util.Map;",
        "import org.springframework.web.bind.annotation.GetMapping;",
        "import org.springframework.web.bind.annotation.RequestMapping;",
        "import org.springframework.web.bind.annotation.RestController;",
        "",
        "@RestController",
        "@RequestMapping(`"/api`")",
        "public class HealthController {",
        "",
        "    @GetMapping(`"/health`")",
        "    public Map<String, String> health() {",
        "        return Map.of(",
        "            `"status`", `"UP`",",
        "            `"message`", `"Backend is reachable`"",
        "        );",
        "    }",
        "}"
    )

    # --------------------------------------------------------
    # Global CORS
    # The Vite proxy means normal development requests do not
    # require CORS, but this makes direct browser/API calls work too.
    # --------------------------------------------------------
    Write-TextFile "$configDir\CorsConfig.java" @(
        "package $GroupId.config;",
        "",
        "import org.springframework.context.annotation.Configuration;",
        "import org.springframework.web.servlet.config.annotation.CorsRegistry;",
        "import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;",
        "",
        "@Configuration",
        "public class CorsConfig implements WebMvcConfigurer {",
        "",
        "    @Override",
        "    public void addCorsMappings(CorsRegistry registry) {",
        "        registry.addMapping(`"/api/**`")",
        "            .allowedOrigins(`"http://localhost:$FrontendPort`")",
        "            .allowedMethods(`"GET`", `"POST`", `"PUT`", `"PATCH`", `"DELETE`", `"OPTIONS`")",
        "            .allowedHeaders(`"*`");",
        "    }",
        "}"
    )

    # --------------------------------------------------------
    # application.yml
    # --------------------------------------------------------
    $yml = [System.Collections.Generic.List[string]]::new()

    $yml.Add("spring:")
    $yml.Add("  application:")
    $yml.Add("    name: ${ProjectName}-backend")

    if ($UsePostgres) {
        $yml.Add("")
        $yml.Add("  datasource:")
        $yml.Add("    url: jdbc:postgresql://localhost:5432/$DbName")
        $yml.Add("    username: postgres")
        $yml.Add("    password: postgres")
        $yml.Add("    driver-class-name: org.postgresql.Driver")
        $yml.Add("")
        $yml.Add("  jpa:")
        $yml.Add("    hibernate:")
        $yml.Add("      ddl-auto: update")
        $yml.Add("    open-in-view: false")
        $yml.Add("    show-sql: true")
    }

    if ($UseH2) {
        $yml.Add("")
        $yml.Add("  datasource:")
        $yml.Add("    url: jdbc:h2:mem:${ProjectName};DB_CLOSE_DELAY=-1")
        $yml.Add("    username: sa")
        $yml.Add("    password:")
        $yml.Add("    driver-class-name: org.h2.Driver")
        $yml.Add("")
        $yml.Add("  jpa:")
        $yml.Add("    hibernate:")
        $yml.Add("      ddl-auto: create-drop")
        $yml.Add("    open-in-view: false")
        $yml.Add("    show-sql: true")
    }

    $yml.Add("")
    $yml.Add("server:")
    $yml.Add("  port: $BackendPort")

    $yml.Add("")
    $yml.Add("management:")
    $yml.Add("  endpoints:")
    $yml.Add("    web:")
    $yml.Add("      exposure:")
    $yml.Add("        include: health,info,metrics")
    $yml.Add("  endpoint:")
    $yml.Add("    health:")
    $yml.Add("      show-details: always")

    $yml.Add("")
    $yml.Add("logging:")
    $yml.Add("  level:")
    $yml.Add("    root: INFO")
    $yml.Add("    ${GroupId}: DEBUG")

    Write-TextFile "$resourcesDir\application.yml" $yml

    # Remove generated application.properties if Initializr supplied one.
    $propertiesPath = "$resourcesDir\application.properties"
    if (Test-Path $propertiesPath) {
        Remove-Item $propertiesPath -Force
    }

    # --------------------------------------------------------
    # Backend README
    # --------------------------------------------------------
    Write-TextFile "$BackendDir\README.md" @(
        "# $ProjectName backend",
        "",
        "Spring Boot REST backend.",
        "",
        "## Start",
        "",
        "```powershell",
        "mvn spring-boot:run",
        "```",
        "",
        "## Test",
        "",
        "http://localhost:$BackendPort/api/health",
        "",
        "Expected response:",
        "",
        "```json",
        "{",
        "  `"status`": `"UP`",",
        "  `"message`": `"Backend is reachable`"",
        "}",
        "```"
    )

    # Dockerfile is useful later, but it does not participate in local startup.
    Write-TextFile "$BackendDir\Dockerfile" @(
        "FROM maven:3.9-eclipse-temurin-21 AS build",
        "WORKDIR /app",
        "COPY pom.xml .",
        "RUN mvn -q -DskipTests dependency:go-offline",
        "COPY src ./src",
        "RUN mvn -q -DskipTests package",
        "",
        "FROM eclipse-temurin:21-jre",
        "WORKDIR /app",
        "COPY --from=build /app/target/*.jar app.jar",
        "EXPOSE $BackendPort",
        "ENTRYPOINT [`"java`", `"-jar`", `"app.jar`"]"
    )
}

function Write-FrontendStarterFiles {
    param(
        [string]$FrontendDir,
        [string]$ProjectName,
        [int]$FrontendPort,
        [int]$BackendPort
    )

    $src = "$FrontendDir\src"

    foreach ($folder in @(
        $src,
        "$src\api",
        "$src\components",
        "$src\pages",
        "$src\hooks",
        "$src\utils",
        "$FrontendDir\public"
    )) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    # --------------------------------------------------------
    # package.json
    #
    # Pin versions instead of "latest". This is deliberate:
    # a starter generator should not silently change dependency
    # graphs every time it is run.
    # --------------------------------------------------------
    Write-TextFile "$FrontendDir\package.json" @(
        "{",
        "  `"name`": `"${ProjectName}-frontend`",",
        "  `"private`": true,",
        "  `"version`": `"0.0.1`",",
        "  `"type`": `"module`",",
        "  `"scripts`": {",
        "    `"dev`": `"vite`",",
        "    `"build`": `"vite build`",",
        "    `"preview`": `"vite preview`"",
        "  },",
        "  `"dependencies`": {",
        "    `"react`": `"19.2.8`",",
        "    `"react-dom`": `"19.2.8`"",
        "  },",
        "  `"devDependencies`": {",
        "    `"@vitejs/plugin-react`": `"6.1.0`",",
        "    `"vite`": `"8.2.2`"",
        "  },",
        "  `"engines`": {",
        "    `"node`": `">=20.19.0`"",
        "  }",
        "}"
    )

    # --------------------------------------------------------
    # Vite proxy:
    #
    # Browser -> localhost:FRONTEND/api/health
    # Vite    -> localhost:BACKEND/api/health
    #
    # Therefore the browser sees one origin during development.
    # --------------------------------------------------------
    Write-TextFile "$FrontendDir\vite.config.js" @(
        "import { defineConfig } from 'vite'",
        "import react from '@vitejs/plugin-react'",
        "",
        "export default defineConfig({",
        "  plugins: [react()],",
        "  server: {",
        "    port: $FrontendPort,",
        "    strictPort: true,",
        "    proxy: {",
        "      '/api': {",
        "        target: 'http://localhost:$BackendPort',",
        "        changeOrigin: true,",
        "        secure: false",
        "      }",
        "    }",
        "  }",
        "})"
    )

    Write-TextFile "$FrontendDir\index.html" @(
        "<!doctype html>",
        "<html lang=`"en`">",
        "  <head>",
        "    <meta charset=`"UTF-8`" />",
        "    <meta name=`"viewport`" content=`"width=device-width, initial-scale=1.0`" />",
        "    <title>$ProjectName</title>",
        "  </head>",
        "  <body>",
        "    <div id=`"root`"></div>",
        "    <script type=`"module`" src=`"/src/main.jsx`"></script>",
        "  </body>",
        "</html>"
    )

    Write-TextFile "$FrontendDir\.env" @(
        "VITE_API_BASE_URL=/api",
        "VITE_APP_NAME=$ProjectName"
    )

    Write-TextFile "$src\api\api.js" @(
        "const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'",
        "",
        "export async function getHealth() {",
        "  const response = await fetch(`${API_BASE_URL}/health`)",
        "",
        "  if (!response.ok) {",
        "    throw new Error(`Backend returned HTTP ${response.status}`)",
        "  }",
        "",
        "  return response.json()",
        "}"
    )

    Write-TextFile "$src\App.jsx" @(
        "import { useEffect, useState } from 'react'",
        "import { getHealth } from './api/api'",
        "import './App.css'",
        "",
        "function App() {",
        "  const [status, setStatus] = useState('Checking...')",
        "  const [message, setMessage] = useState('')",
        "",
        "  useEffect(() => {",
        "    getHealth()",
        "      .then(data => {",
        "        setStatus(data.status)",
        "        setMessage(data.message)",
        "      })",
        "      .catch(error => {",
        "        console.error(error)",
        "        setStatus('DOWN')",
        "        setMessage('Backend not reachable')",
        "      })",
        "  }, [])",
        "",
        "  return (",
        "    <main className=`"app`">",
        "      <h1>{import.meta.env.VITE_APP_NAME}</h1>",
        "      <p>React frontend is running.</p>",
        "      <section className=`"status-card`">",
        "        <div>Backend status: <strong>{status}</strong></div>",
        "        <div>{message}</div>",
        "      </section>",
        "    </main>",
        "  )",
        "}",
        "",
        "export default App"
    )

    Write-TextFile "$src\main.jsx" @(
        "import { StrictMode } from 'react'",
        "import { createRoot } from 'react-dom/client'",
        "import App from './App.jsx'",
        "import './index.css'",
        "",
        "createRoot(document.getElementById('root')).render(",
        "  <StrictMode>",
        "    <App />",
        "  </StrictMode>",
        ")"
    )

    Write-TextFile "$src\index.css" @(
        ":root {",
        "  font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, `"Segoe UI`", sans-serif;",
        "  color: #1f2937;",
        "  background: #f5f7fb;",
        "}",
        "",
        "* { box-sizing: border-box; }",
        "",
        "body { margin: 0; min-width: 320px; min-height: 100vh; }"
    )

    Write-TextFile "$src\App.css" @(
        ".app {",
        "  max-width: 900px;",
        "  margin: 0 auto;",
        "  padding: 64px 24px;",
        "}",
        "",
        "h1 { margin-bottom: 8px; }",
        "",
        ".status-card {",
        "  margin-top: 32px;",
        "  padding: 24px;",
        "  background: white;",
        "  border: 1px solid #e5e7eb;",
        "  border-radius: 12px;",
        "  box-shadow: 0 4px 20px rgba(0,0,0,0.05);",
        "}",
        "",
        ".status-card strong { margin-left: 6px; }"
    )

    Write-TextFile "$FrontendDir\.gitignore" @(
        "node_modules/",
        "dist/",
        ".env.local",
        "*.log"
    )

    Write-TextFile "$FrontendDir\README.md" @(
        "# $ProjectName frontend",
        "",
        "React + Vite frontend.",
        "",
        "## Install",
        "",
        "```powershell",
        "npm install",
        "```",
        "",
        "## Start",
        "",
        "```powershell",
        "npm run dev",
        "```",
        "",
        "The Vite dev server proxies `/api` to:",
        "",
        "http://localhost:$BackendPort"
    )
}

function Write-RootFiles {
    param(
        [string]$RootDir,
        [string]$ProjectName,
        [string]$BootVersion,
        [int]$BackendPort,
        [int]$FrontendPort,
        [string]$Profile
    )

    Write-TextFile "$RootDir\.gitignore" @(
        "**/target/",
        "**/node_modules/",
        "**/dist/",
        ".idea/",
        "*.iml",
        "*.log",
        ".DS_Store"
    )

    Write-TextFile "$RootDir\README.md" @(
        "# $ProjectName",
        "",
        "Generated by Fullstack Project Creator v4.0",
        "",
        "## Stack",
        "",
        "- Java 21",
        "- Spring Boot $BootVersion",
        "- Maven",
        "- React 19",
        "- Vite 8",
        "- REST API",
        "- Vite development proxy",
        "- Global Spring CORS configuration",
        "",
        "## URLs",
        "",
        "| Component | URL |",
        "|---|---|",
        "| Frontend | http://localhost:$FrontendPort |",
        "| Backend | http://localhost:$BackendPort |",
        "| API health | http://localhost:$BackendPort/api/health |",
        "| Actuator health | http://localhost:$BackendPort/actuator/health |",
        "",
        "## Start backend",
        "",
        "```powershell",
        "cd $ProjectName-backend",
        "mvn spring-boot:run",
        "```",
        "",
        "## Start frontend",
        "",
        "```powershell",
        "cd $ProjectName-frontend",
        "npm install",
        "npm run dev",
        "```",
        "",
        "## How the connection works",
        "",
        "React calls `/api/health`.",
        "",
        "Vite proxies `/api` to the Spring Boot server.",
        "",
        "Spring Boot handles `/api/health`.",
        "",
        "No hard-coded backend URL is required in React.",
        "",
        "This avoids the common localhost:3000 -> localhost:8080 CORS problem during development."
    )

    Write-TextFile "$RootDir\start-backend.ps1" @(
        "Set-Location `"$RootDir\$ProjectName-backend`"",
        "mvn spring-boot:run"
    )

    Write-TextFile "$RootDir\start-frontend.ps1" @(
        "Set-Location `"$RootDir\$ProjectName-frontend`"",
        "if (-not (Test-Path node_modules)) { npm install }",
        "npm run dev"
    )

    Write-TextFile "$RootDir\start-fullstack.ps1" @(
        "Write-Host `"Starting $ProjectName backend...`" -ForegroundColor Cyan",
        "Start-Process powershell -ArgumentList `"-NoExit`", `"-ExecutionPolicy`", `"Bypass`", `"-File`", `"$RootDir\start-backend.ps1`"",
        "",
        "Write-Host `"Waiting for Spring Boot...`" -ForegroundColor DarkGray",
        "$healthUrl = `"http://localhost:$BackendPort/api/health`"",
        "$ready = $false",
        "for (`$i = 0; `$i -lt 60; `$i++) {",
        "    try {",
        "        `$response = Invoke-WebRequest -Uri `$healthUrl -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop",
        "        if (`$response.StatusCode -eq 200) { `$ready = `$true; break }",
        "    } catch {}",
        "    Start-Sleep -Seconds 2",
        "}",
        "",
        "if (-not `$ready) {",
        "    Write-Host `"Backend did not become ready within 120 seconds.`" -ForegroundColor Red",
        "    Write-Host `"Check the backend terminal for the Maven/Spring error.`" -ForegroundColor Yellow",
        "    exit 1",
        "}",
        "",
        "Write-Host `"Backend is ready. Starting frontend...`" -ForegroundColor Green",
        "Start-Process powershell -ArgumentList `"-NoExit`", `"-ExecutionPolicy`", `"Bypass`", `"-File`", `"$RootDir\start-frontend.ps1`"",
        "Start-Sleep -Seconds 3",
        "Start-Process `"http://localhost:$FrontendPort`""
    )
}

# ============================================================
# PRE-FLIGHT
# ============================================================

Clear-Host
Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host " FULLSTACK PROJECT CREATOR v4.0" -ForegroundColor Magenta
Write-Host " Spring Boot + React/Vite" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Command "java")) {
    Write-Host "ERROR: Java is not installed or not on PATH." -ForegroundColor Red
    Write-Host "Install Java 21 and reopen PowerShell." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Command "mvn")) {
    Write-Host "ERROR: Maven is not installed or not on PATH." -ForegroundColor Red
    Write-Host "Install Maven and reopen PowerShell." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Command "node")) {
    Write-Host "ERROR: Node.js is not installed or not on PATH." -ForegroundColor Red
    Write-Host "Install Node.js 20.19+ and reopen PowerShell." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Command "npm")) {
    Write-Host "ERROR: npm is not installed or not on PATH." -ForegroundColor Red
    exit 1
}

$javaVersion = (& java -version 2>&1 | Select-Object -First 1)
$nodeVersion = (& node --version)
$mavenVersion = (& mvn -version 2>&1 | Select-Object -First 1)

Write-Host "Java  : $javaVersion" -ForegroundColor DarkGray
Write-Host "Node  : $nodeVersion" -ForegroundColor DarkGray
Write-Host "Maven : $mavenVersion" -ForegroundColor DarkGray
Write-Host ""

# Vite 8 requires Node 20.19+ or 22.12+.
if ($nodeVersion -match 'v(\d+)\.(\d+)\.') {
    $nodeMajor = [int]$Matches[1]
    $nodeMinor = [int]$Matches[2]

    $nodeOkay = (
        ($nodeMajor -eq 20 -and $nodeMinor -ge 19) -or
        ($nodeMajor -eq 22 -and $nodeMinor -ge 12) -or
        ($nodeMajor -gt 22)
    )

    if (-not $nodeOkay) {
        Write-Host "ERROR: Your Node.js version is $nodeVersion." -ForegroundColor Red
        Write-Host "This starter uses Vite 8 and requires Node 20.19+ or 22.12+." -ForegroundColor Yellow
        exit 1
    }
}

# ============================================================
# PROJECT INPUT
# ============================================================

$rawName = (Read-Host "Project name (example: Conc01Basics)").Trim()

if ([string]::IsNullOrWhiteSpace($rawName)) {
    Write-Host "ERROR: Project name is required." -ForegroundColor Red
    exit 1
}

$projectName = Get-SafeName $rawName
$groupId = Get-GroupId $projectName
$dbName = Get-DbName $projectName

Write-Host ""
Write-Host "Project name : $projectName" -ForegroundColor Green
Write-Host "Group ID     : $groupId" -ForegroundColor Green
Write-Host ""

# ============================================================
# PROFILE
# ============================================================

Write-Host "Choose starter profile:" -ForegroundColor Yellow
Write-Host ""
Write-Host "[1] BASIC FULL STACK  - Spring REST + React/Vite (recommended)" -ForegroundColor White
Write-Host "    No database required. Backend/frontend connection works immediately." -ForegroundColor DarkGray
Write-Host ""
Write-Host "[2] FULL STACK + POSTGRESQL/JPA" -ForegroundColor White
Write-Host "    Adds PostgreSQL + Spring Data JPA. PostgreSQL must already be running." -ForegroundColor DarkGray
Write-Host ""
Write-Host "[3] FULL STACK + H2/JPA" -ForegroundColor White
Write-Host "    Adds JPA with an in-memory H2 database. No external database required." -ForegroundColor DarkGray
Write-Host ""

$profileChoice = (Read-Host "Choose 1 / 2 / 3 [Enter = 1]").Trim()
if ([string]::IsNullOrWhiteSpace($profileChoice)) {
    $profileChoice = "1"
}

switch ($profileChoice) {
    "1" {
        $profile = "basic"
        $dependencies = "web,actuator,validation"
        $usePostgres = $false
        $useH2 = $false
    }

    "2" {
        $profile = "postgresql"
        $dependencies = "web,actuator,validation,data-jpa,postgresql"
        $usePostgres = $true
        $useH2 = $false
    }

    "3" {
        $profile = "h2"
        $dependencies = "web,actuator,validation,data-jpa,h2"
        $usePostgres = $false
        $useH2 = $true
    }

    default {
        Write-Host "Invalid choice. Using BASIC FULL STACK." -ForegroundColor Yellow
        $profile = "basic"
        $dependencies = "web,actuator,validation"
        $usePostgres = $false
        $useH2 = $false
    }
}

$bootVersion = Get-BootVersion

$backendPort = Get-FreePort 8080
$frontendPort = Get-FreePort 3000

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Spring Boot : $bootVersion"
Write-Host "  Java        : 21"
Write-Host "  Profile     : $profile"
Write-Host "  Backend     : http://localhost:$backendPort"
Write-Host "  Frontend    : http://localhost:$frontendPort"
Write-Host "  API         : http://localhost:$backendPort/api/health"
if ($usePostgres) {
    Write-Host "  PostgreSQL  : $dbName (postgres/postgres)" -ForegroundColor Yellow
}
Write-Host ""

$confirm = (Read-Host "Create project? Y / N").Trim().ToUpper()
if ($confirm -ne "Y") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

$rootDir = Join-Path $PWD.Path $projectName
$backendDir = Join-Path $rootDir "$projectName-backend"
$frontendDir = Join-Path $rootDir "$projectName-frontend"

if (Test-Path $rootDir) {
    Write-Host "ERROR: Directory already exists: $rootDir" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $rootDir -Force | Out-Null

# ============================================================
# BACKEND
# ============================================================

Write-Host ""
Write-Host "1/5 Creating Spring Boot backend..." -ForegroundColor Cyan

Download-SpringBootProject `
    -BootVersion $bootVersion `
    -ProjectName $projectName `
    -GroupId $groupId `
    -BackendDir $backendDir `
    -Dependencies $dependencies

Write-BackendStarterFiles `
    -BackendDir $backendDir `
    -ProjectName $projectName `
    -GroupId $groupId `
    -BackendPort $backendPort `
    -FrontendPort $frontendPort `
    -UsePostgres $usePostgres `
    -UseH2 $useH2 `
    -DbName $dbName

Write-Host "  Backend files ready." -ForegroundColor Green

# ============================================================
# FRONTEND
# ============================================================

Write-Host ""
Write-Host "2/5 Creating React/Vite frontend..." -ForegroundColor Cyan

New-Item -ItemType Directory -Path $frontendDir -Force | Out-Null

Write-FrontendStarterFiles `
    -FrontendDir $frontendDir `
    -ProjectName $projectName `
    -FrontendPort $frontendPort `
    -BackendPort $backendPort

Write-Host "  Frontend files ready." -ForegroundColor Green

# ============================================================
# ROOT
# ============================================================

Write-Host ""
Write-Host "3/5 Writing root scripts and README..." -ForegroundColor Cyan

Write-RootFiles `
    -RootDir $rootDir `
    -ProjectName $projectName `
    -BootVersion $bootVersion `
    -BackendPort $backendPort `
    -FrontendPort $frontendPort `
    -Profile $profile

Write-Host "  Root files ready." -ForegroundColor Green

# ============================================================
# VERIFY BACKEND BUILD
# ============================================================

Write-Host ""
Write-Host "4/5 Verifying backend Maven build..." -ForegroundColor Cyan

Push-Location $backendDir
try {
    & mvn -q -DskipTests package
    if ($LASTEXITCODE -ne 0) {
        throw "Maven backend build failed."
    }
} finally {
    Pop-Location
}

Write-Host "  Backend build successful." -ForegroundColor Green

# ============================================================
# VERIFY FRONTEND INSTALL + BUILD
# ============================================================

Write-Host ""
Write-Host "5/5 Installing and verifying frontend..." -ForegroundColor Cyan

Push-Location $frontendDir
try {
    & npm install
    if ($LASTEXITCODE -ne 0) {
        throw "npm install failed."
    }

    & npm run build
    if ($LASTEXITCODE -ne 0) {
        throw "npm run build failed."
    }
} finally {
    Pop-Location
}

Write-Host "  Frontend install/build successful." -ForegroundColor Green

# ============================================================
# FINAL
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " PROJECT CREATED AND VERIFIED SUCCESSFULLY" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Project : $rootDir" -ForegroundColor White
Write-Host "Backend : http://localhost:$backendPort" -ForegroundColor White
Write-Host "API     : http://localhost:$backendPort/api/health" -ForegroundColor White
Write-Host "Frontend: http://localhost:$frontendPort" -ForegroundColor White
Write-Host ""
Write-Host "To start both:" -ForegroundColor Yellow
Write-Host "  .\start-fullstack.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Or manually:" -ForegroundColor Yellow
Write-Host "  Backend : .\start-backend.ps1" -ForegroundColor White
Write-Host "  Frontend: .\start-frontend.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Frontend calls /api/health -> Vite proxy -> Spring Boot." -ForegroundColor Cyan
Write-Host "No hard-coded localhost:8080 URL is used by React." -ForegroundColor Cyan
Write-Host ""

# Open the generated project in IntelliJ if the command is available.
if (Test-Command "idea64.exe") {
    try {
        Start-Process "idea64.exe" -ArgumentList "`"$rootDir`""
        Write-Host "IntelliJ IDEA opened." -ForegroundColor Green
    } catch {
        Write-Host "Could not open IntelliJ automatically." -ForegroundColor Yellow
    }
}

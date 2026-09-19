$ErrorActionPreference = "Stop"

# ==============================================================================
#  CREATE-SPRING-STABLE  v4.0
#  Spring Boot + React Full-Stack Project Generator
#  Java 21 | Maven | Vite | BOM-free UTF-8
# ==============================================================================

# ------------------------------------------------------------------------------
# LAYER 0 — UTILITIES
# ------------------------------------------------------------------------------

function Write-TextFile {
    param ([string]$Path, [string[]]$Lines)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false   # $false = NO BOM
    [System.IO.File]::WriteAllLines($Path, $Lines, $utf8)
}

function New-Dir {
    param ([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-SafeName {
    param ([string]$Raw)
    $s = $Raw.Trim().ToLower()
    $s = $s -replace '[_\s]+', '-'
    $s = $s -replace '[^a-z0-9\-]', ''
    return $s.Trim('-')
}

function Get-DbName      { param([string]$SafeName) return ($SafeName -replace '-','_') + '_db' }
function Get-GroupId     { param([string]$SafeName) return 'com.' + ($SafeName -replace '-','') }
function Get-ArtifactId  { param([string]$SafeName) return "$SafeName-backend" }
function Get-PackagePath { param([string]$SafeName) return ($SafeName -replace '-','') }

function Get-FreePort {
    param ([int]$Start)
    $p = $Start
    while ($p -lt ($Start + 50)) {
        if (-not (Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue)) { return $p }
        $p++
    }
    return $Start
}

function Open-IntelliJ {
    param ([string]$Path)
    $paths = @(
        'C:\Program Files\JetBrains\IntelliJ IDEA 2025.1\bin\idea64.exe',
        'C:\Program Files\JetBrains\IntelliJ IDEA 2024.3\bin\idea64.exe',
        'C:\Program Files\JetBrains\IntelliJ IDEA\bin\idea64.exe',
        'C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2025.1\bin\idea64.exe',
        'C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2024.3\bin\idea64.exe',
        'C:\Program Files\JetBrains\IntelliJ IDEA Community Edition\bin\idea64.exe'
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { Start-Process $p -ArgumentList "`"$Path`""; return }
    }
    try { Start-Process 'idea64.exe' -ArgumentList "`"$Path`"" } catch {}
}

function Get-VerifiedBootVersion {
    param ([string]$Version)
    try {
        $url = "https://start.spring.io/starter.zip?type=maven-project&language=java&javaVersion=21&bootVersion=$Version&groupId=com.test&artifactId=test&name=test&packageName=com.test&dependencies=web"
        $tmp = [System.IO.Path]::GetTempFileName() + '.zip'
        Invoke-WebRequest -Uri $url -OutFile $tmp -ErrorAction Stop
        $ok = (Get-Item $tmp).Length -gt 1000
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        return $ok
    } catch { return $false }
}

function Get-BestBootVersion {
    param ([string]$Preference)
    $latest = @('4.1.1','4.1.0','4.0.7','4.0.6','4.0.5','4.0.4','4.0.3','4.0.2','4.0.1','4.0.0')
    $stable = @('4.0.7','4.0.6','4.0.5','4.0.4','4.0.3','4.0.2','4.0.1','4.0.0')
    $list   = if ($Preference -eq 'latest') { $latest } else { $stable }
    foreach ($v in $list) {
        Write-Host "    Trying $v ..." -ForegroundColor DarkGray -NoNewline
        if (Get-VerifiedBootVersion -Version $v) {
            Write-Host ' OK' -ForegroundColor Green
            return $v
        }
        Write-Host ' skip' -ForegroundColor DarkGray
    }
    return $null
}

# ------------------------------------------------------------------------------
# LAYER 1 — SPRING BACKEND FILE WRITERS
# ------------------------------------------------------------------------------

function Write-HealthController {
    param ([string]$SrcDir, [string]$GroupId, [string]$ProjectName)
    $pkg  = $GroupId
    $file = "$SrcDir\controller\HealthController.java"
    Write-TextFile -Path $file -Lines @(
        "package ${pkg}.controller;",
        '',
        'import org.springframework.web.bind.annotation.GetMapping;',
        'import org.springframework.web.bind.annotation.RequestMapping;',
        'import org.springframework.web.bind.annotation.RestController;',
        'import java.util.Map;',
        '',
        '@RestController',
        '@RequestMapping("/api")',
        'public class HealthController {',
        '',
        '    @GetMapping("/health")',
        '    public Map<String, String> health() {',
        "        return Map.of(""status"", ""UP"", ""service"", ""$ProjectName"");",
        '    }',
        '}'
    )
}

function Write-CorsConfig {
    param ([string]$SrcDir, [string]$GroupId, [int]$FrontendPort)
    $pkg  = $GroupId
    $file = "$SrcDir\config\CorsConfig.java"
    $origin = "http://localhost:$FrontendPort"
    Write-TextFile -Path $file -Lines @(
        "package ${pkg}.config;",
        '',
        'import org.springframework.context.annotation.Configuration;',
        'import org.springframework.web.servlet.config.annotation.CorsRegistry;',
        'import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;',
        '',
        '@Configuration',
        'public class CorsConfig implements WebMvcConfigurer {',
        '',
        '    @Override',
        '    public void addCorsMappings(CorsRegistry registry) {',
        '        registry.addMapping("/api/**")',
        "                .allowedOrigins(""$origin"")",
        '                .allowedMethods("GET","POST","PUT","PATCH","DELETE","OPTIONS")',
        '                .allowedHeaders("*")',
        '                .allowCredentials(true);',
        '    }',
        '}'
    )
}

function Write-ApplicationYml {
    param (
        [string]$ResourcesDir,
        [string]$ProjectName,
        [string]$GroupId,
        [int]$BackendPort,
        [string]$DbKey,
        [string]$DbName
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('spring:')
    $lines.Add('  application:')
    $lines.Add("    name: $ProjectName-backend")
    $lines.Add('')

    if ($DbKey -eq '2') {   # H2
        $lines.Add('  datasource:')
        $lines.Add("    url: jdbc:h2:mem:$DbName")
        $lines.Add('    driver-class-name: org.h2.Driver')
        $lines.Add('    username: sa')
        $lines.Add("    password: ''")
        $lines.Add('')
        $lines.Add('  h2:')
        $lines.Add('    console:')
        $lines.Add('      enabled: true')
        $lines.Add('      path: /h2-console')
        $lines.Add('')
        $lines.Add('  jpa:')
        $lines.Add('    hibernate:')
        $lines.Add('      ddl-auto: create-drop')
        $lines.Add('    show-sql: true')
        $lines.Add('    open-in-view: false')
        $lines.Add('    database-platform: org.hibernate.dialect.H2Dialect')
    }
    elseif ($DbKey -eq '3' -or $DbKey -eq '4') {   # PostgreSQL
        $pgUrl = "jdbc:postgresql://localhost:5432/$DbName"
        $lines.Add('  datasource:')
        $lines.Add("    url: $pgUrl")
        $lines.Add('    username: postgres')
        $lines.Add('    password: postgres')
        $lines.Add('    driver-class-name: org.postgresql.Driver')
        $lines.Add('    hikari:')
        $lines.Add('      maximum-pool-size: 10')
        $lines.Add('      minimum-idle: 2')
        $lines.Add('')
        $lines.Add('  jpa:')
        $lines.Add('    hibernate:')
        $lines.Add('      ddl-auto: update')
        $lines.Add('    show-sql: true')
        $lines.Add('    open-in-view: false')
        $lines.Add('    properties:')
        $lines.Add('      hibernate:')
        $lines.Add('        format_sql: true')
        $lines.Add('        dialect: org.hibernate.dialect.PostgreSQLDialect')
    }

    if ($DbKey -eq '4' -or $DbKey -eq '5') {   # Security profiles
        $lines.Add('')
        $lines.Add('  # Security: configure your own AuthenticationManager or remove this block')
        $lines.Add('  # security:')
        $lines.Add('  #   oauth2: ...')
    }

    $lines.Add('')
    $lines.Add('server:')
    $lines.Add("  port: $BackendPort")
    $lines.Add('')
    $lines.Add('management:')
    $lines.Add('  endpoints:')
    $lines.Add('    web:')
    $lines.Add('      exposure:')
    $lines.Add('        include: health,metrics,info')
    $lines.Add('  endpoint:')
    $lines.Add('    health:')
    $lines.Add('      show-details: always')
    $lines.Add('')
    $lines.Add('logging:')
    $lines.Add('  level:')
    $lines.Add('    root: INFO')
    $lines.Add("    ${GroupId}: DEBUG")

    Write-TextFile -Path "$ResourcesDir\application.yml" -Lines $lines.ToArray()
}

# ------------------------------------------------------------------------------
# LAYER 2 — REACT FRONTEND FILE WRITERS
# ------------------------------------------------------------------------------

function Write-ReactApp {
    param (
        [string]$FrontendDir,
        [string]$ProjectName,
        [int]$FrontendPort,
        [int]$BackendPort
    )

    $src = "$FrontendDir\src"

    # --- index.html ---
    Write-TextFile -Path "$FrontendDir\index.html" -Lines @(
        '<!doctype html>',
        '<html lang="en">',
        '  <head>',
        '    <meta charset="UTF-8" />',
        '    <meta name="viewport" content="width=device-width, initial-scale=1.0" />',
        "    <title>$ProjectName</title>",
        '  </head>',
        '  <body>',
        '    <div id="root"></div>',
        '    <script type="module" src="/src/main.jsx"></script>',
        '  </body>',
        '</html>'
    )

    # --- src/main.jsx ---
    Write-TextFile -Path "$src\main.jsx" -Lines @(
        "import { StrictMode } from 'react'",
        "import { createRoot } from 'react-dom/client'",
        "import './index.css'",
        "import App from './App.jsx'",
        '',
        "createRoot(document.getElementById('root')).render(",
        '  <StrictMode>',
        '    <App />',
        '  </StrictMode>',
        ')'
    )

    # --- src/App.jsx ---
    # Uses /health which Axios resolves to /api/health via baseURL='/api'
    # Vite proxy forwards /api/* to Spring Boot
    Write-TextFile -Path "$src\App.jsx" -Lines @(
        "import { useState, useEffect } from 'react'",
        "import './App.css'",
        "import api from './api/api'",
        '',
        'function App() {',
        '  const [status, setStatus]   = useState(null)',
        '  const [loading, setLoading] = useState(true)',
        '',
        '  useEffect(() => {',
        "    api.get('/health')",
        '      .then(res => {',
        "        setStatus(res.data.status ?? 'UP')",
        '        setLoading(false)',
        '      })',
        '      .catch(() => {',
        "        setStatus('Backend not reachable')",
        '        setLoading(false)',
        '      })',
        '  }, [])',
        '',
        '  const color = status === null ? "#888"',
        '              : status === "UP"  ? "#22c55e"',
        '              : "#ef4444"',
        '',
        '  return (',
        '    <div className="card">',
        "      <h1>{import.meta.env.VITE_APP_NAME || '$ProjectName'}</h1>",
        '      <p>React frontend is running.</p>',
        '      <p>',
        '        Backend status:{" "}',
        '        <strong style={{ color }}>',
        "          {loading ? 'Checking...' : status}",
        '        </strong>',
        '      </p>',
        '      <hr />',
        '      <small>',
        "        API: <code>/api/health</code> &rarr;{' '}",
        "        <code>http://localhost:$BackendPort</code>",
        '      </small>',
        '    </div>',
        '  )',
        '}',
        '',
        'export default App'
    )

    # --- src/index.css ---
    Write-TextFile -Path "$src\index.css" -Lines @(
        ':root {',
        '  font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;',
        '  background: #f0f4f8;',
        '  color: #1e293b;',
        '}',
        'body { margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; }'
    )

    # --- src/App.css ---
    Write-TextFile -Path "$src\App.css" -Lines @(
        '.card {',
        '  background: #fff;',
        '  border-radius: 12px;',
        '  padding: 2.5rem 3rem;',
        '  box-shadow: 0 4px 24px rgba(0,0,0,0.08);',
        '  min-width: 340px;',
        '  text-align: center;',
        '}',
        'h1 { font-size: 1.8rem; margin-bottom: 0.5rem; }',
        'p  { font-size: 1rem; color: #475569; }',
        'hr { border: none; border-top: 1px solid #e2e8f0; margin: 1.2rem 0; }',
        'small { color: #94a3b8; font-size: 0.8rem; }',
        'code  { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; }'
    )

    # --- src/api/api.js ---
    # baseURL is /api (relative) — Vite proxy handles forwarding to Spring Boot
    # This is the critical fix vs the old VITE_API_BASE_URL=http://localhost:8080/api
    Write-TextFile -Path "$src\api\api.js" -Lines @(
        "import axios from 'axios'",
        '',
        'const api = axios.create({',
        "  baseURL: '/api',",
        '  timeout: 10000,',
        "  headers: { 'Content-Type': 'application/json' }",
        '})',
        '',
        'export default api'
    )

    # --- src/utils/constants.js ---
    Write-TextFile -Path "$src\utils\constants.js" -Lines @(
        "export const APP_NAME    = import.meta.env.VITE_APP_NAME || '$ProjectName'",
        "export const BACKEND_URL = 'http://localhost:$BackendPort'"
    )

    # --- vite.config.js ---
    $target = "http://localhost:$BackendPort"
    Write-TextFile -Path "$FrontendDir\vite.config.js" -Lines @(
        "import { defineConfig } from 'vite'",
        "import react from '@vitejs/plugin-react'",
        '',
        'export default defineConfig({',
        '  plugins: [react()],',
        '  server: {',
        "    port: $FrontendPort,",
        '    proxy: {',
        "      '/api': {",
        "        target: '$target',",
        '        changeOrigin: true,',
        '        secure: false',
        '      }',
        '    }',
        '  }',
        '})'
    )

    # --- .env ---
    # VITE_API_BASE_URL is /api (relative) so Vite proxy is used, not direct HTTP
    Write-TextFile -Path "$FrontendDir\.env" -Lines @(
        "VITE_APP_NAME=$ProjectName",
        '# API calls go through Vite proxy: /api -> Spring Boot',
        '# Do NOT set this to http://localhost:PORT — that bypasses the proxy',
        'VITE_API_BASE_URL=/api'
    )

    # --- package.json — pinned verified versions ---
    Write-TextFile -Path "$FrontendDir\package.json" -Lines @(
        '{',
        "  `"name`": `"$ProjectName-frontend`",",
        '  "private": true,',
        '  "version": "0.0.0",',
        '  "type": "module",',
        '  "scripts": {',
        '    "dev":     "vite",',
        '    "build":   "vite build",',
        '    "preview": "vite preview",',
        '    "lint":    "eslint ."',
        '  },',
        '  "dependencies": {',
        '    "axios":          "^1.7.9",',
        '    "react":          "^18.3.1",',
        '    "react-dom":      "^18.3.1",',
        '    "react-router-dom": "^6.28.0"',
        '  },',
        '  "devDependencies": {',
        '    "@vitejs/plugin-react": "^4.3.4",',
        '    "vite":                 "^6.3.5",',
        '    "@eslint/js":           "^9.28.0",',
        '    "eslint":               "^9.28.0",',
        '    "eslint-plugin-react-hooks":    "^5.2.0",',
        '    "eslint-plugin-react-refresh":  "^0.4.20",',
        '    "globals":              "^15.11.0"',
        '  }',
        '}'
    )

    # --- eslint.config.js ---
    Write-TextFile -Path "$FrontendDir\eslint.config.js" -Lines @(
        "import js from '@eslint/js'",
        "import globals from 'globals'",
        "import reactHooks from 'eslint-plugin-react-hooks'",
        "import reactRefresh from 'eslint-plugin-react-refresh'",
        '',
        'export default [',
        "  { ignores: ['dist'] },",
        '  {',
        "    files: ['**/*.{js,jsx}'],",
        '    languageOptions: {',
        '      ecmaVersion: 2020,',
        '      globals: globals.browser,',
        "      parserOptions: { ecmaVersion: 'latest', ecmaFeatures: { jsx: true }, sourceType: 'module' }",
        '    },',
        "    plugins: { 'react-hooks': reactHooks, 'react-refresh': reactRefresh },",
        '    rules: {',
        '      ...reactHooks.configs.recommended.rules,',
        "      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }]",
        '    }',
        '  }',
        ']'
    )

    # --- .gitignore ---
    Write-TextFile -Path "$FrontendDir\.gitignore" -Lines @(
        'node_modules/',
        'dist/',
        '.env.local',
        '*.log'
    )

    # Create empty placeholder dirs
    foreach ($d in @('components','hooks','pages','routes','context','assets')) {
        New-Dir "$src\$d"
        Write-TextFile -Path "$src\$d\.gitkeep" -Lines @('')
    }
    New-Dir "$FrontendDir\public"
}

# ------------------------------------------------------------------------------
# LAYER 3 — START SCRIPTS
# ------------------------------------------------------------------------------

function Write-StartScripts {
    param (
        [string]$RootDir,
        [string]$ProjectName,
        [int]$BackendPort,
        [int]$FrontendPort
    )

    $be = "$ProjectName-backend"
    $fe = "$ProjectName-frontend"
    $healthUrl = "http://localhost:$BackendPort/api/health"

    # start-backend.ps1
    Write-TextFile -Path "$RootDir\start-backend.ps1" -Lines @(
        "# Start the Spring Boot backend",
        "Set-Location `"$RootDir\$be`"",
        'Write-Host "Starting backend on port ' + $BackendPort + '..." -ForegroundColor Cyan',
        'mvn spring-boot:run'
    )

    # start-frontend.ps1
    Write-TextFile -Path "$RootDir\start-frontend.ps1" -Lines @(
        "# Start the React frontend",
        "Set-Location `"$RootDir\$fe`"",
        'Write-Host "Starting frontend on port ' + $FrontendPort + '..." -ForegroundColor Cyan',
        'npm run dev'
    )

    # start-fullstack.ps1
    # Starts backend in background, polls /api/health, then starts frontend
    Write-TextFile -Path "$RootDir\start-fullstack.ps1" -Lines @(
        '# Start full stack: backend first, wait for health, then frontend',
        '$ErrorActionPreference = "SilentlyContinue"',
        '',
        "# 1. Start backend in a new PowerShell window",
        'Write-Host ""',
        'Write-Host "  Starting backend..." -ForegroundColor Cyan',
        "Start-Process powershell -ArgumentList `"-NoExit -Command Set-Location '$RootDir\$be'; mvn spring-boot:run`"",
        '',
        "# 2. Poll /api/health until backend is ready",
        'Write-Host "  Waiting for backend at ' + $healthUrl + '" -ForegroundColor DarkGray',
        '$ready    = $false',
        '$attempts = 0',
        '$maxWait  = 120   # seconds',
        '',
        'while (-not $ready -and $attempts -lt $maxWait) {',
        '    try {',
        "        `$r = Invoke-WebRequest -Uri '$healthUrl' -UseBasicParsing -ErrorAction Stop",
        '        if ($r.StatusCode -eq 200) { $ready = $true }',
        '    } catch {}',
        '    if (-not $ready) {',
        "        Write-Host '    .' -NoNewline -ForegroundColor DarkGray",
        '        Start-Sleep -Seconds 1',
        '        $attempts++',
        '    }',
        '}',
        '',
        'if (-not $ready) {',
        '    Write-Host ""',
        '    Write-Host "  Backend did not start within $maxWait seconds." -ForegroundColor Red',
        '    Write-Host "  Start it manually: cd $be && mvn spring-boot:run" -ForegroundColor Yellow',
        '    exit 1',
        '}',
        '',
        'Write-Host ""',
        'Write-Host "  Backend is UP!" -ForegroundColor Green',
        '',
        "# 3. Start frontend in a new PowerShell window",
        'Write-Host "  Starting frontend..." -ForegroundColor Cyan',
        "Start-Process powershell -ArgumentList `"-NoExit -Command Set-Location '$RootDir\$fe'; npm run dev`"",
        '',
        'Start-Sleep -Seconds 3',
        '',
        "# 4. Open browser",
        "Start-Process `"http://localhost:$FrontendPort`"",
        '',
        'Write-Host ""',
        'Write-Host "  ============================================" -ForegroundColor Green',
        'Write-Host "   Full stack is running!" -ForegroundColor Green',
        'Write-Host "  ============================================" -ForegroundColor Green',
        'Write-Host "   Frontend : http://localhost:' + $FrontendPort + '" -ForegroundColor White',
        'Write-Host "   Backend  : http://localhost:' + $BackendPort  + '" -ForegroundColor White',
        'Write-Host "   Health   : ' + $healthUrl + '" -ForegroundColor White',
        'Write-Host ""'
    )
}

# ------------------------------------------------------------------------------
# LAYER 4 — README + ROOT GITIGNORE
# ------------------------------------------------------------------------------

function Write-Readme {
    param (
        [string]$RootDir,
        [string]$ProjectName,
        [string]$ProfileLabel,
        [string]$BootVersion,
        [int]$BackendPort,
        [int]$FrontendPort,
        [string]$DbType,
        [string]$DbName
    )

    $fe        = "http://localhost:$FrontendPort"
    $be        = "http://localhost:$BackendPort"
    $h2Line    = if ($DbType -eq 'H2') { "| H2 Console      | $be/h2-console |" } else { '' }
    $proxyLine = "  Vite proxy  (/api -> http://localhost:$BackendPort)"
    $svcLine   = '    -> { "status": "UP", "service": "' + $ProjectName + '" }'

    # Build lines as a list so no inline if is needed inside the array literal
    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add("# $ProjectName")
    $md.Add('')
    $md.Add('Generated by **create-spring-stable v4.0**')
    $md.Add('')
    $md.Add('## Stack')
    $md.Add('')
    $md.Add('| | |')
    $md.Add('|---|---|')
    $md.Add("| Profile     | $ProfileLabel |")
    $md.Add("| Spring Boot | $BootVersion |")
    $md.Add('| Java        | 21 |')
    $md.Add('| Build       | Maven |')
    $md.Add("| Backend     | $be |")
    $md.Add("| Frontend    | $fe |")
    $md.Add("| Database    | $DbType |")
    $md.Add('')
    $md.Add('## Run')
    $md.Add('')
    $md.Add('### Option 1 — Full stack in one command')
    $md.Add('```powershell')
    $md.Add("cd $RootDir")
    $md.Add('.\start-fullstack.ps1')
    $md.Add('```')
    $md.Add('')
    $md.Add('### Option 2 — Separate terminals')
    $md.Add('')
    $md.Add('**Terminal 1 — Backend**')
    $md.Add('```powershell')
    $md.Add("cd $ProjectName-backend")
    $md.Add('mvn spring-boot:run')
    $md.Add('```')
    $md.Add('')
    $md.Add('**Terminal 2 — Frontend**')
    $md.Add('```powershell')
    $md.Add("cd $ProjectName-frontend")
    $md.Add('npm run dev')
    $md.Add('```')
    $md.Add('')
    $md.Add('## Endpoints')
    $md.Add('')
    $md.Add('| | URL |')
    $md.Add('|---|---|')
    $md.Add("| Frontend        | $fe |")
    $md.Add("| Health (custom) | $be/api/health |")
    $md.Add("| Actuator        | $be/actuator/health |")
    if ($h2Line) { $md.Add($h2Line) }
    $md.Add('')
    $md.Add('## How the proxy works')
    $md.Add('')
    $md.Add('```')
    $md.Add('Browser')
    $md.Add("  http://localhost:$FrontendPort/api/health")
    $md.Add('    |')
    $md.Add($proxyLine)
    $md.Add('    |')
    $md.Add('  Spring Boot')
    $md.Add('    GET /api/health')
    $md.Add($svcLine)
    $md.Add('```')
    $md.Add('')
    $md.Add("React never calls \`http://localhost:$BackendPort\` directly.")
    $md.Add('All API calls use relative paths like `/api/health`.')
    $md.Add('')
    $md.Add('## Install as global command (optional)')
    $md.Add('')
    $md.Add('```powershell')
    $md.Add('# Run once to make create-spring-stable available anywhere:')
    $md.Add('notepad $PROFILE')
    $md.Add('# Add this line:')
    $md.Add("# function create-spring-stable { & 'C:\build-tools\create-spring-stable.ps1' }")
    $md.Add('# Save and restart PowerShell.')
    $md.Add('```')

    Write-TextFile -Path "$RootDir\README.md" -Lines $md.ToArray()
}



# ==============================================================================
# MAIN SCRIPT ENTRY POINT
# ==============================================================================

Clear-Host
Write-Host ''
Write-Host '  ============================================' -ForegroundColor Magenta
Write-Host '    CREATE-SPRING-STABLE  v4.0               ' -ForegroundColor Magenta
Write-Host '    Spring Boot + React Full-Stack Generator  ' -ForegroundColor Magenta
Write-Host '    Java 21  |  Maven  |  Vite               ' -ForegroundColor Magenta
Write-Host '  ============================================' -ForegroundColor Magenta
Write-Host ''

# ------------------------------------------------------------------------------
# STEP 0 — SPRING BOOT VERSION
# ------------------------------------------------------------------------------
Write-Host '  STEP 0 - Spring Boot Version' -ForegroundColor Yellow
Write-Host '  --------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  [1]  4.0.x  Stable  (best library compatibility)' -ForegroundColor White
Write-Host '  [2]  4.1.x  Latest  (newest features)' -ForegroundColor White
Write-Host ''

$vc = (Read-Host '  Choose 1 or 2  [Enter = 1]').Trim()
if ([string]::IsNullOrWhiteSpace($vc)) { $vc = '1' }

Write-Host ''
Write-Host '  Verifying version on start.spring.io...' -ForegroundColor Cyan

$pref        = if ($vc -eq '2') { 'latest' } else { 'stable' }
$bootVersion = Get-BestBootVersion -Preference $pref

if (-not $bootVersion) {
    Write-Host '  ERROR: Cannot reach start.spring.io. Check internet.' -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host "  Spring Boot $bootVersion confirmed." -ForegroundColor Green
Write-Host ''

# ------------------------------------------------------------------------------
# STEP 1 — PROJECT NAME
# ------------------------------------------------------------------------------
Write-Host '  STEP 1 - Project Name' -ForegroundColor Yellow
Write-Host '  --------------------------------------------' -ForegroundColor DarkGray
Write-Host '  Any case/spaces/underscores OK.' -ForegroundColor DarkGray
Write-Host '  Example: Conc01Basics  |  my-app  |  BankFlow_01' -ForegroundColor DarkGray
Write-Host ''

$rawName = (Read-Host '  Project name').Trim()
if ([string]::IsNullOrWhiteSpace($rawName)) {
    Write-Host '  ERROR: Name required.' -ForegroundColor Red; exit 1
}

$projectName = Get-SafeName  -Raw $rawName
$groupId     = Get-GroupId   -SafeName $projectName
$dbNameAuto  = Get-DbName    -SafeName $projectName
$pkgPath     = Get-PackagePath -SafeName $projectName

if ([string]::IsNullOrWhiteSpace($projectName)) {
    Write-Host '  ERROR: Name empty after sanitization.' -ForegroundColor Red; exit 1
}

Write-Host ''
Write-Host '  Auto-derived:' -ForegroundColor Green
Write-Host "    Project  : $projectName" -ForegroundColor White
Write-Host "    Group ID : $groupId" -ForegroundColor White
Write-Host "    DB name  : $dbNameAuto" -ForegroundColor White
Write-Host ''

# ------------------------------------------------------------------------------
# STEP 2 — PROFILE
# ------------------------------------------------------------------------------
Write-Host '  STEP 2 - Project Profile' -ForegroundColor Yellow
Write-Host '  --------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  [1]  Basic Full Stack              (web, actuator, devtools, lombok)' -ForegroundColor Cyan
Write-Host '       No database required. Start immediately.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  [2]  Full Stack + H2               (JPA + H2 in-memory)' -ForegroundColor Cyan
Write-Host '       No external DB. Great for JPA practice.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  [3]  Full Stack + PostgreSQL        (JPA + PostgreSQL)' -ForegroundColor Cyan
Write-Host '       Requires PostgreSQL running locally.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  [4]  PostgreSQL + Security          (JPA + PostgreSQL + Spring Security)' -ForegroundColor Cyan
Write-Host '       Adds Security config. JWT setup is manual.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  [5]  Full Enterprise                (PostgreSQL + Security + Kafka + Redis)' -ForegroundColor Cyan
Write-Host '       Requires PostgreSQL + Kafka + Redis running.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  --------------------------------------------' -ForegroundColor DarkGray

$profileChoice = (Read-Host '  Choose 1-5  [Enter = 1]').Trim()
if ([string]::IsNullOrWhiteSpace($profileChoice)) { $profileChoice = '1' }

switch ($profileChoice) {
    '1' {
        $profileLabel  = 'Basic Full Stack'
        $springDeps    = 'web,lombok,devtools,validation,actuator'
        $dbKey         = '1'   # no DB
        $dbName        = ''
        $needsJpa      = $false
        $needsSecurity = $false
        $needsKafka    = $false
        $needsRedis    = $false
    }
    '2' {
        $profileLabel  = 'Full Stack + H2'
        $springDeps    = 'web,data-jpa,h2,lombok,devtools,validation,actuator'
        $dbKey         = '2'
        $dbName        = $dbNameAuto
        $needsJpa      = $true
        $needsSecurity = $false
        $needsKafka    = $false
        $needsRedis    = $false
    }
    '3' {
        $profileLabel  = 'Full Stack + PostgreSQL'
        $springDeps    = 'web,data-jpa,postgresql,lombok,devtools,validation,actuator'
        $dbKey         = '3'
        $dbName        = $dbNameAuto
        $needsJpa      = $true
        $needsSecurity = $false
        $needsKafka    = $false
        $needsRedis    = $false
    }
    '4' {
        $profileLabel  = 'PostgreSQL + Security'
        $springDeps    = 'web,data-jpa,postgresql,security,lombok,devtools,validation,actuator'
        $dbKey         = '4'
        $dbName        = $dbNameAuto
        $needsJpa      = $true
        $needsSecurity = $true
        $needsKafka    = $false
        $needsRedis    = $false
    }
    '5' {
        $profileLabel  = 'Full Enterprise'
        $springDeps    = 'web,data-jpa,postgresql,security,kafka,data-redis,cache,lombok,devtools,validation,actuator'
        $dbKey         = '5'
        $dbName        = $dbNameAuto
        $needsJpa      = $true
        $needsSecurity = $true
        $needsKafka    = $true
        $needsRedis    = $true
    }
    default {
        Write-Host '  Invalid choice, using Basic Full Stack.' -ForegroundColor Yellow
        $profileLabel  = 'Basic Full Stack'
        $springDeps    = 'web,lombok,devtools,validation,actuator'
        $dbKey         = '1'
        $dbName        = ''
        $needsJpa      = $false
        $needsSecurity = $false
        $needsKafka    = $false
        $needsRedis    = $false
    }
}

# Auto-assign free ports
$backendPort  = Get-FreePort -Start 8080
$frontendPort = Get-FreePort -Start 3000

# ------------------------------------------------------------------------------
# CONFIRM
# ------------------------------------------------------------------------------
Write-Host ''
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host '   CONFIRM' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "   Project     : $projectName" -ForegroundColor White
Write-Host "   Profile     : $profileLabel" -ForegroundColor White
Write-Host "   Spring Boot : $bootVersion  (Java 21, Maven)" -ForegroundColor White
Write-Host "   Group ID    : $groupId" -ForegroundColor White
if ($dbName) {
    Write-Host "   Database    : $dbName" -ForegroundColor White
} else {
    Write-Host '   Database    : None' -ForegroundColor White
}
Write-Host "   Backend     : http://localhost:$backendPort" -ForegroundColor White
Write-Host "   Frontend    : http://localhost:$frontendPort" -ForegroundColor White
Write-Host ''

$ok = (Read-Host '  Create project? [Y/N]').Trim().ToUpper()
if ($ok -ne 'Y') { Write-Host '  Cancelled.' -ForegroundColor Yellow; exit 0 }

# ------------------------------------------------------------------------------
# BUILD PATHS
# ------------------------------------------------------------------------------
$rootDir     = "$($PWD.Path)\$projectName"
$backendDir  = "$rootDir\$projectName-backend"
$frontendDir = "$rootDir\$projectName-frontend"
$origLoc     = $PWD.Path

New-Dir $rootDir

# ------------------------------------------------------------------------------
# DOWNLOAD SPRING BOOT
# ------------------------------------------------------------------------------
Write-Host ''
Write-Host '  Downloading Spring Boot project...' -ForegroundColor Cyan

$deps    = $springDeps.Replace(',','%2C')
$initUrl = "https://start.spring.io/starter.zip?type=maven-project&language=java&javaVersion=21&bootVersion=$bootVersion&groupId=$groupId&artifactId=$projectName-backend&name=$projectName-backend&packageName=$groupId&dependencies=$deps"

$zip = "$rootDir\backend.zip"
try {
    Invoke-WebRequest -Uri $initUrl -OutFile $zip -ErrorAction Stop
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  URL: $initUrl" -ForegroundColor DarkGray
    exit 1
}

Expand-Archive -Path $zip -DestinationPath $backendDir -Force
Remove-Item $zip -Force
Write-Host '  Spring Boot downloaded.' -ForegroundColor Green

# ------------------------------------------------------------------------------
# FIND src/main/java
# ------------------------------------------------------------------------------
$appJava = Get-ChildItem -Path "$backendDir\src\main\java" -Filter '*Application.java' -Recurse |
           Select-Object -First 1
if (-not $appJava) {
    Write-Host '  ERROR: Application.java not found in downloaded project.' -ForegroundColor Red
    exit 1
}
$mainSrc   = $appJava.DirectoryName
$resources = "$backendDir\src\main\resources"

# Remove generated test file
Get-ChildItem "$backendDir\src\test" -Filter '*.java' -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item $_.FullName -Force }

# ------------------------------------------------------------------------------
# CREATE JAVA PACKAGES
# ------------------------------------------------------------------------------
Write-Host '  Creating Java packages...' -ForegroundColor Cyan

$packages = @('controller','service','dto','exception','config','utils')
if ($needsJpa)      { $packages += @('repository','entity','mapper') }
if ($needsSecurity) { $packages += @('security','filter') }
if ($needsKafka)    { $packages += @('event','producer','consumer') }
if ($needsRedis)    { $packages += @('cache') }

foreach ($pkg in $packages) {
    New-Dir "$mainSrc\$pkg"
    Write-TextFile -Path "$mainSrc\$pkg\.gitkeep" -Lines @('')
    Write-Host "    + $pkg" -ForegroundColor DarkGreen
}

# ------------------------------------------------------------------------------
# WRITE HealthController.java — always created
# ------------------------------------------------------------------------------
Write-HealthController -SrcDir $mainSrc -GroupId $groupId -ProjectName $projectName
Write-Host '  HealthController.java written  (GET /api/health)' -ForegroundColor Green

# ------------------------------------------------------------------------------
# WRITE CorsConfig.java — always created, uses exact frontendPort
# ------------------------------------------------------------------------------
Write-CorsConfig -SrcDir $mainSrc -GroupId $groupId -FrontendPort $frontendPort
Write-Host "  CorsConfig.java written  (allows http://localhost:$frontendPort)" -ForegroundColor Green

# ------------------------------------------------------------------------------
# DELETE application.properties, WRITE application.yml
# ------------------------------------------------------------------------------
$props = "$resources\application.properties"
if (Test-Path $props) { Remove-Item $props -Force }

Write-ApplicationYml `
    -ResourcesDir $resources `
    -ProjectName  $projectName `
    -GroupId      $groupId `
    -BackendPort  $backendPort `
    -DbKey        $dbKey `
    -DbName       $dbName

Write-Host '  application.yml written.' -ForegroundColor Green

# ------------------------------------------------------------------------------
# KAFKA / REDIS additions to yml if needed
# ------------------------------------------------------------------------------
if ($needsKafka -or $needsRedis) {
    $extra = [System.Collections.Generic.List[string]]::new()
    if ($needsKafka) {
        $extra.Add('')
        $extra.Add('# Kafka — add to spring: section in application.yml')
        $extra.Add('#   kafka:')
        $extra.Add('#     bootstrap-servers: localhost:9092')
    }
    if ($needsRedis) {
        $extra.Add('')
        $extra.Add('# Redis — add to spring: section in application.yml')
        $extra.Add('#   data:')
        $extra.Add('#     redis:')
        $extra.Add('#       host: localhost')
        $extra.Add('#       port: 6379')
    }
    Write-TextFile -Path "$resources\infrastructure-notes.yml" -Lines $extra.ToArray()
}

# ------------------------------------------------------------------------------
# DOCKERFILE
# ------------------------------------------------------------------------------
Write-TextFile -Path "$backendDir\Dockerfile" -Lines @(
    'FROM maven:3.9-eclipse-temurin-21 AS builder',
    'WORKDIR /app',
    'COPY pom.xml .',
    'RUN mvn dependency:go-offline -B',
    'COPY src ./src',
    'RUN mvn clean package -DskipTests -B',
    '',
    'FROM eclipse-temurin:21-jre-alpine',
    'WORKDIR /app',
    'COPY --from=builder /app/target/*.jar app.jar',
    "EXPOSE $backendPort",
    'ENTRYPOINT ["java","-jar","app.jar"]'
)

Write-TextFile -Path "$backendDir\.gitignore" -Lines @(
    'target/','.idea/','*.iml','*.log','.env'
)

Write-Host '  Backend files complete.' -ForegroundColor Green

# ------------------------------------------------------------------------------
# REACT FRONTEND
# ------------------------------------------------------------------------------
Write-Host ''
Write-Host '  Building React frontend...' -ForegroundColor Cyan

New-Dir $frontendDir
New-Dir "$frontendDir\src\api"
New-Dir "$frontendDir\src\utils"
New-Dir "$frontendDir\public"

Write-ReactApp `
    -FrontendDir  $frontendDir `
    -ProjectName  $projectName `
    -FrontendPort $frontendPort `
    -BackendPort  $backendPort

Write-Host '  React files written.' -ForegroundColor Green

# npm install
$hasNode = $false
try {
    $nodeVer = & node --version 2>&1
    if ($LASTEXITCODE -eq 0) { $hasNode = $true }
} catch {}

if ($hasNode) {
    Write-Host "  Node $nodeVer found. Running npm install..." -ForegroundColor Cyan
    Write-Host '  (first run takes 1-2 minutes)' -ForegroundColor DarkGray
    Push-Location $frontendDir

    # Use cmd /c so npm runs as a plain process — this prevents PowerShell from
    # intercepting npm's stderr and printing it as NativeCommandError warnings.
    # --loglevel=error suppresses all warn/notice/deprecated output from npm itself.
    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()

    $proc = Start-Process -FilePath 'cmd.exe' `
        -ArgumentList '/c', 'npm install --loglevel=error' `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $tmpOut `
        -RedirectStandardError  $tmpErr

    $exitCode = $proc.ExitCode
    $outLines = Get-Content $tmpOut -ErrorAction SilentlyContinue
    $errLines = Get-Content $tmpErr -ErrorAction SilentlyContinue

    Remove-Item $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue

    if ($exitCode -ne 0) {
        Write-Host '  npm install failed:' -ForegroundColor Red
        $errLines | Where-Object { $_ -match 'error|ERR!' } |
            ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        Write-Host "  Run manually inside: $frontendDir" -ForegroundColor Yellow
        Write-Host '  Command: npm install' -ForegroundColor Yellow
    } else {
        $summary = ($outLines + $errLines) |
            Where-Object { $_ -match 'added|changed|packages' } |
            Select-Object -Last 1
        if ($summary) { Write-Host "  $summary" -ForegroundColor DarkGray }
        Write-Host '  npm install complete. node_modules ready.' -ForegroundColor Green
    }

    Pop-Location
} else {
    Write-Host '  Node.js not found. Run npm install manually after installing Node.' -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# START SCRIPTS + README + ROOT GITIGNORE
# ------------------------------------------------------------------------------
Write-StartScripts `
    -RootDir      $rootDir `
    -ProjectName  $projectName `
    -BackendPort  $backendPort `
    -FrontendPort $frontendPort

Write-Readme `
    -RootDir      $rootDir `
    -ProjectName  $projectName `
    -ProfileLabel $profileLabel `
    -BootVersion  $bootVersion `
    -BackendPort  $backendPort `
    -FrontendPort $frontendPort `
    -DbType       $(if ($dbName) { $dbName } else { 'None' }) `
    -DbName       $dbName

Write-TextFile -Path "$rootDir\.gitignore" -Lines @(
    '**/target/',
    '**/node_modules/',
    '**/dist/',
    '**/.idea/',
    '**/*.iml',
    '**/*.log'
)

# ------------------------------------------------------------------------------
# OPEN INTELLIJ
# ------------------------------------------------------------------------------
Open-IntelliJ -Path $rootDir

# ------------------------------------------------------------------------------
# DONE
# ------------------------------------------------------------------------------
Write-Host ''
Write-Host '  ============================================' -ForegroundColor Green
Write-Host '   PROJECT CREATED SUCCESSFULLY!' -ForegroundColor Green
Write-Host '  ============================================' -ForegroundColor Green
Write-Host ''
Write-Host "   Project     : $projectName" -ForegroundColor White
Write-Host "   Profile     : $profileLabel" -ForegroundColor White
Write-Host "   Spring Boot : $bootVersion  (Java 21, Maven)" -ForegroundColor White
if ($dbName) { Write-Host "   Database    : $dbName" -ForegroundColor White }
Write-Host "   Backend     : http://localhost:$backendPort" -ForegroundColor White
Write-Host "   Frontend    : http://localhost:$frontendPort" -ForegroundColor White
Write-Host "   Health      : http://localhost:$backendPort/api/health" -ForegroundColor White
Write-Host "   Location    : $rootDir" -ForegroundColor White
Write-Host ''
Write-Host '   NEXT STEPS:' -ForegroundColor Yellow
Write-Host "   Option A:  cd $projectName" -ForegroundColor White
Write-Host '             .\start-fullstack.ps1' -ForegroundColor White
Write-Host ''
Write-Host '   Option B (two terminals):' -ForegroundColor White
Write-Host "             cd $projectName\$projectName-backend  &&  mvn spring-boot:run" -ForegroundColor White
Write-Host "             cd $projectName\$projectName-frontend &&  npm run dev" -ForegroundColor White
Write-Host ''
if ($dbName -and ($dbKey -eq '3' -or $dbKey -eq '4' -or $dbKey -eq '5')) {
    Write-Host "   DATABASE: Create PostgreSQL DB first:" -ForegroundColor Yellow
    Write-Host "             CREATE DATABASE $dbName;" -ForegroundColor White
    Write-Host ''
}
Write-Host '   INSTALL AS GLOBAL COMMAND (run once):' -ForegroundColor Yellow
Write-Host '   Add this to your PowerShell profile (notepad $PROFILE):' -ForegroundColor White
Write-Host "   function create-spring-stable { & 'C:\build-tools\create-spring-stable.ps1' }" -ForegroundColor DarkGray
Write-Host ''

Set-Location $origLoc
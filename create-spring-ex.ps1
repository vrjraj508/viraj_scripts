param (
    [string]$OutputDir = $PWD
)

$ErrorActionPreference = "Stop"

# ==============================
# PROFILES
# ==============================
$exerciseProfiles = @{
    "1" = @{ Name = "Spring Core";            Deps = "lombok,devtools";                                           Packages = @("config","beans","service","aop","events","utils") }
    "2" = @{ Name = "Spring REST API";        Deps = "web,lombok,devtools,validation";                            Packages = @("controller","service","dto","exception","config","utils") }
    "3" = @{ Name = "Spring MVC + Thymeleaf"; Deps = "web,thymeleaf,lombok,devtools,validation";                  Packages = @("controller","service","model","config","utils") }
    "4" = @{ Name = "Spring Data JPA";        Deps = "web,data-jpa,lombok,devtools,validation";                   Packages = @("controller","service","repository","entity","dto","mapper","exception","config") }
    "5" = @{ Name = "Spring Security";        Deps = "web,security,lombok,devtools,validation";                   Packages = @("controller","service","config","filter","dto","exception","utils") }
    "6" = @{ Name = "Spring AOP";             Deps = "web,aop,lombok,devtools";                                   Packages = @("aspect","service","controller","annotation","config","utils") }
    "7" = @{ Name = "Spring Batch";           Deps = "batch,lombok,devtools";                                     Packages = @("job","step","reader","processor","writer","config","utils") }
    "8" = @{ Name = "Spring Kafka/Messaging"; Deps = "web,kafka,lombok,devtools";                                 Packages = @("producer","consumer","config","dto","utils") }
    "9" = @{ Name = "Spring Full Stack";      Deps = "web,data-jpa,security,lombok,devtools,validation,actuator"; Packages = @("controller","service","repository","entity","dto","mapper","exception","config","filter","utils") }
}

$fullStackProfiles = @{
    "1" = @{ Name = "REST API Only";                   Deps = "web,lombok,devtools,validation,actuator" }
    "2" = @{ Name = "REST API + JPA";                  Deps = "web,data-jpa,lombok,devtools,validation,actuator" }
    "3" = @{ Name = "REST API + JPA + Security";       Deps = "web,data-jpa,security,lombok,devtools,validation,actuator" }
    "4" = @{ Name = "REST API + JPA + Kafka";          Deps = "web,data-jpa,kafka,lombok,devtools,validation,actuator" }
    "5" = @{ Name = "Full (JPA+Security+Kafka+Redis)"; Deps = "web,data-jpa,security,oauth2-resource-server,kafka,data-redis,cache,lombok,devtools,validation,actuator" }
}

$dbProfiles = @{
    "1" = @{ Name = "PostgreSQL";     Dep = "postgresql";   Driver = "org.postgresql.Driver";       Dialect = "org.hibernate.dialect.PostgreSQLDialect" }
    "2" = @{ Name = "MySQL";          Dep = "mysql";         Driver = "com.mysql.cj.jdbc.Driver";    Dialect = "org.hibernate.dialect.MySQLDialect" }
    "3" = @{ Name = "H2 (In-Memory)"; Dep = "h2";            Driver = "org.h2.Driver";               Dialect = "org.hibernate.dialect.H2Dialect" }
    "4" = @{ Name = "MongoDB";        Dep = "data-mongodb";  Driver = "";                            Dialect = "" }
    "5" = @{ Name = "No Database";    Dep = "";              Driver = "";                            Dialect = "" }
}

$exerciseSubPackages = @(
    "controller","service","service/impl","repository","entity",
    "dto/request","dto/response","mapper","config","exception","constants"
)

# ==============================
# HELPER FUNCTIONS
# ==============================
function Get-InitializrUrl {
    param ($GroupId, $ArtifactId, $Name, $EncodedDeps)
    $base = "https://start.spring.io/starter.zip"
    $q    = "type=maven-project&language=java&javaVersion=21&bootVersion=3.5.0"
    $q   += "&groupId=$GroupId&artifactId=$ArtifactId&name=$Name&packageName=$GroupId"
    $q   += "&dependencies=$EncodedDeps"
    return "$base`?$q"
}

function Show-Menu {
    param ([string]$Title, [hashtable]$Options)
    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "  ========================================" -ForegroundColor DarkGray
    foreach ($key in ($Options.Keys | Sort-Object)) {
        Write-Host "  [$key] $($Options[$key].Name)" -ForegroundColor Cyan
    }
    Write-Host ""
}

function Open-InIntelliJ {
    param ([string]$FolderPath)
    $ideaPaths = @(
        "C:\Program Files\JetBrains\IntelliJ IDEA 2025.3.1.1\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA 2025.1\bin\idea64.exe",
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

function Write-TextFile {
    param ([string]$FilePath, [string[]]$Lines)
    $dir = Split-Path $FilePath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $FilePath -Value $Lines -Encoding UTF8
}

function New-Package {
    param ([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    New-Item -ItemType File -Path "$Path\.gitkeep" -Force | Out-Null
}

function Get-MainSrcPath {
    param ([string]$ProjectDir)
    $appJava = Get-ChildItem -Path "$ProjectDir\src\main\java" -Filter "*Application.java" -Recurse |
               Select-Object -First 1
    if (-not $appJava) { throw "Could not find Application.java in $ProjectDir" }
    return $appJava.DirectoryName
}

function Download-SpringProject {
    param ($Url, $DestDir, $ProjectName)
    Write-Host "  Downloading from start.spring.io..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $Url -OutFile "$DestDir\$ProjectName.zip" -ErrorAction Stop
    Expand-Archive "$DestDir\$ProjectName.zip" -DestinationPath "$DestDir\$ProjectName" -Force
    Remove-Item "$DestDir\$ProjectName.zip" -Force
    Write-Host "  Extracted: $ProjectName" -ForegroundColor Green
}

function Write-PropertiesFile {
    param ($ResourcesPath, $ProjectName, $Port, $DbKey, $DbProfile, $DbName)
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# SERVER")
    $lines.Add("server.port=$Port")
    $lines.Add("spring.application.name=$ProjectName")
    $lines.Add("")

    if ($DbKey -eq "1") {
        $lines.Add("# DATABASE - PostgreSQL")
        $lines.Add("spring.datasource.url=jdbc:postgresql://localhost:5432/$DbName")
        $lines.Add("spring.datasource.username=postgres")
        $lines.Add("spring.datasource.password=postgres")
        $lines.Add("spring.datasource.driver-class-name=$($DbProfile.Driver)")
        $lines.Add("spring.jpa.hibernate.ddl-auto=update")
        $lines.Add("spring.jpa.show-sql=true")
        $lines.Add("spring.jpa.properties.hibernate.format_sql=true")
        $lines.Add("spring.jpa.database-platform=$($DbProfile.Dialect)")
    }
    elseif ($DbKey -eq "2") {
        $mysqlUrl = "jdbc:mysql://localhost:3306/" + $DbName + "?useSSL=false" + "`&serverTimezone=UTC`&allowPublicKeyRetrieval=true"
        $lines.Add("# DATABASE - MySQL")
        $lines.Add("spring.datasource.url=$mysqlUrl")
        $lines.Add("spring.datasource.username=root")
        $lines.Add("spring.datasource.password=root")
        $lines.Add("spring.datasource.driver-class-name=$($DbProfile.Driver)")
        $lines.Add("spring.jpa.hibernate.ddl-auto=update")
        $lines.Add("spring.jpa.show-sql=true")
        $lines.Add("spring.jpa.properties.hibernate.format_sql=true")
        $lines.Add("spring.jpa.database-platform=$($DbProfile.Dialect)")
    }
    elseif ($DbKey -eq "3") {
        $lines.Add("# DATABASE - H2")
        $lines.Add("spring.datasource.url=jdbc:h2:mem:$DbName")
        $lines.Add("spring.datasource.driver-class-name=$($DbProfile.Driver)")
        $lines.Add("spring.datasource.username=sa")
        $lines.Add("spring.datasource.password=")
        $lines.Add("spring.h2.console.enabled=true")
        $lines.Add("spring.h2.console.path=/h2-console")
        $lines.Add("spring.jpa.hibernate.ddl-auto=update")
        $lines.Add("spring.jpa.show-sql=true")
        $lines.Add("spring.jpa.properties.hibernate.format_sql=true")
        $lines.Add("spring.jpa.database-platform=$($DbProfile.Dialect)")
    }
    elseif ($DbKey -eq "4") {
        $lines.Add("# DATABASE - MongoDB")
        $lines.Add("spring.data.mongodb.host=localhost")
        $lines.Add("spring.data.mongodb.port=27017")
        $lines.Add("spring.data.mongodb.database=$DbName")
    }

    Set-Content -Path "$ResourcesPath\application.properties" -Value $lines -Encoding UTF8
    Write-Host "  application.properties written." -ForegroundColor Green
}

function Write-YmlFile {
    param ($ResourcesPath, $ProjectName, $BackendPort, $DbKey, $DbProfile, $DbName, $AllDeps)

    if (Test-Path "$ResourcesPath\application.properties") {
        Remove-Item "$ResourcesPath\application.properties" -Force
    }

    $yml = [System.Collections.Generic.List[string]]::new()
    $yml.Add("spring:")
    $yml.Add("  application:")
    $yml.Add("    name: $ProjectName-backend")
    $yml.Add("")

    if ($DbKey -eq "1") {
        $yml.Add("  datasource:")
        $yml.Add("    url: jdbc:postgresql://localhost:5432/$DbName")
        $yml.Add("    username: postgres")
        $yml.Add("    password: postgres")
        $yml.Add("    driver-class-name: org.postgresql.Driver")
        $yml.Add("    hikari:")
        $yml.Add("      maximum-pool-size: 10")
        $yml.Add("      minimum-idle: 2")
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
    elseif ($DbKey -eq "2") {
        $mysqlUrl = "jdbc:mysql://localhost:3306/" + $DbName + "?useSSL=false" + "`&serverTimezone=UTC`&allowPublicKeyRetrieval=true"
        $yml.Add("  datasource:")
        $yml.Add("    url: $mysqlUrl")
        $yml.Add("    username: root")
        $yml.Add("    password: root")
        $yml.Add("    driver-class-name: com.mysql.cj.jdbc.Driver")
        $yml.Add("    hikari:")
        $yml.Add("      maximum-pool-size: 10")
        $yml.Add("      minimum-idle: 2")
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
    elseif ($DbKey -eq "3") {
        $yml.Add("  datasource:")
        $yml.Add("    url: jdbc:h2:mem:$DbName")
        $yml.Add("    driver-class-name: org.h2.Driver")
        $yml.Add("    username: sa")
        $yml.Add("    password: ''")
        $yml.Add("  h2:")
        $yml.Add("    console:")
        $yml.Add("      enabled: true")
        $yml.Add("      path: /h2-console")
        $yml.Add("  jpa:")
        $yml.Add("    hibernate:")
        $yml.Add("      ddl-auto: create-drop")
        $yml.Add("    show-sql: true")
        $yml.Add("    open-in-view: false")
        $yml.Add("    database-platform: org.hibernate.dialect.H2Dialect")
    }
    elseif ($DbKey -eq "4") {
        $yml.Add("  data:")
        $yml.Add("    mongodb:")
        $yml.Add("      host: localhost")
        $yml.Add("      port: 27017")
        $yml.Add("      database: $DbName")
    }

    if ($AllDeps -like "*kafka*") {
        $yml.Add("")
        $yml.Add("  kafka:")
        $yml.Add("    bootstrap-servers: localhost:9092")
        $yml.Add("    producer:")
        $yml.Add("      key-serializer: org.apache.kafka.common.serialization.StringSerializer")
        $yml.Add("      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer")
        $yml.Add("    consumer:")
        $yml.Add("      group-id: $ProjectName-group")
        $yml.Add("      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer")
        $yml.Add("      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer")
        $yml.Add("      auto-offset-reset: earliest")
    }

    if ($AllDeps -like "*data-redis*") {
        $yml.Add("")
        $yml.Add("  data:")
        $yml.Add("    redis:")
        $yml.Add("      host: localhost")
        $yml.Add("      port: 6379")
        $yml.Add("  cache:")
        $yml.Add("    type: redis")
    }

    $yml.Add("")
    $yml.Add("server:")
    $yml.Add("  port: $BackendPort")
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
    $yml.Add("    com.$ProjectName`: DEBUG")

    Set-Content -Path "$ResourcesPath\application.yml" -Value $yml -Encoding UTF8
    Write-Host "  application.yml written." -ForegroundColor Green
}

# ==============================
# MAIN MENU
# ==============================
Clear-Host
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host "   SPRING CREATOR - MASTER TOOL            " -ForegroundColor Magenta
Write-Host "   All-in-one project generator            " -ForegroundColor Magenta
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  [1] Exercise Project     (Learning / practice)" -ForegroundColor Cyan
Write-Host "  [2] Full-Stack Project   (Spring Boot + React)" -ForegroundColor Cyan
Write-Host "  [3] Microservices        (Multiple services)"   -ForegroundColor Cyan
Write-Host "  [4] Maven Project        (Plain Java / DSA)"    -ForegroundColor Cyan
Write-Host ""

$mode = (Read-Host "  Select mode [1-4]").Trim()

# ==============================================================================
# MODE 1 - EXERCISE PROJECT
# ==============================================================================
if ($mode -eq "1") {
    Write-Host ""
    Write-Host "  -- EXERCISE PROJECT ---------------------------" -ForegroundColor Yellow

    $projectName = (Read-Host "  Project name").Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($projectName)) { Write-Host "  ERROR: Name required." -ForegroundColor Red; exit 1 }

    Show-Menu -Title "Spring Profile" -Options $exerciseProfiles
    $profileKey = (Read-Host "  Choose [1-9]").Trim()
    if (-not $exerciseProfiles.ContainsKey($profileKey)) { Write-Host "  ERROR: Invalid." -ForegroundColor Red; exit 1 }
    $selectedProfile = $exerciseProfiles[$profileKey]

    Show-Menu -Title "Database" -Options $dbProfiles
    $dbKey = (Read-Host "  Choose [1-5]").Trim()
    if (-not $dbProfiles.ContainsKey($dbKey)) { Write-Host "  ERROR: Invalid." -ForegroundColor Red; exit 1 }
    $selectedDb = $dbProfiles[$dbKey]

    $dbName = ""
    if ($dbKey -ne "5") {
        $dbName = (Read-Host "  Database name").Trim()
        if ([string]::IsNullOrWhiteSpace($dbName)) { Write-Host "  ERROR: DB name required." -ForegroundColor Red; exit 1 }
    }

    $scaffoldExercises = $false
    $exerciseNames = @()
    $exercisesFile = Join-Path $PSScriptRoot "exercises.txt"
    Write-Host ""
    $ans = (Read-Host "  Scaffold exercises from exercises.txt? [Y/N]").Trim()
    if ($ans -match "^[Yy]$") {
        if (-not (Test-Path $exercisesFile)) { Write-Host "  ERROR: exercises.txt not found at $exercisesFile" -ForegroundColor Red; exit 1 }
        $exerciseNames = Get-Content $exercisesFile | Where-Object { $_ -match '\S' }
        if ($exerciseNames.Count -eq 0) { Write-Host "  ERROR: exercises.txt is empty." -ForegroundColor Red; exit 1 }
        $scaffoldExercises = $true
        Write-Host "  Found $($exerciseNames.Count) exercises." -ForegroundColor Green
    }

    $groupId     = "com.learn.$projectName"
    $allDeps     = if ($selectedDb.Dep -ne "") { "$($selectedProfile.Deps),$($selectedDb.Dep)" } else { $selectedProfile.Deps }
    $encodedDeps = $allDeps.Replace(",", "%2C")
    $url         = Get-InitializrUrl -GroupId $groupId -ArtifactId $projectName -Name $projectName -EncodedDeps $encodedDeps

    try {
        Download-SpringProject -Url $url -DestDir $OutputDir -ProjectName $projectName

        $mainSrc = Get-MainSrcPath -ProjectDir "$OutputDir\$projectName"
        Get-ChildItem "$OutputDir\$projectName\src\test" -Filter "*.java" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Force }

        if ($scaffoldExercises) {
            Write-Host "  Scaffolding exercises..." -ForegroundColor Cyan
            $counter = 1
            foreach ($line in $exerciseNames) {
                $cleanName   = $line.Trim().ToLower() -replace '\s+', '_'
                $paddedNum   = $counter.ToString("D2")
                $exerciseDir = "ex${paddedNum}_${cleanName}"
                Write-Host "  [$paddedNum] $exerciseDir" -ForegroundColor Yellow
                foreach ($subPkg in $exerciseSubPackages) {
                    $subPath = $subPkg -replace '/', '\'
                    New-Package -Path "$mainSrc\$exerciseDir\$subPath"
                }
                $counter++
            }
        } else {
            Write-Host "  Creating packages..." -ForegroundColor Cyan
            foreach ($pkg in $selectedProfile.Packages) {
                New-Package -Path "$mainSrc\$pkg"
                Write-Host "  + $pkg" -ForegroundColor DarkGreen
            }
        }

        Write-PropertiesFile -ResourcesPath "$OutputDir\$projectName\src\main\resources" `
            -ProjectName $projectName -Port "8080" -DbKey $dbKey -DbProfile $selectedDb -DbName $dbName

        Open-InIntelliJ -FolderPath "$OutputDir\$projectName"

        Write-Host ""; Write-Host "  ==========================================" -ForegroundColor Green
        Write-Host "   PROJECT READY!" -ForegroundColor Green
        Write-Host "  ==========================================" -ForegroundColor Green
        Write-Host "   Name     : $projectName" -ForegroundColor White
        Write-Host "   Profile  : $($selectedProfile.Name)" -ForegroundColor White
        Write-Host "   Database : $($selectedDb.Name)" -ForegroundColor White
        if ($dbName -ne "") { Write-Host "   DB Name  : $dbName" -ForegroundColor White }
        if ($scaffoldExercises) { Write-Host "   Exercises: $($exerciseNames.Count) scaffolded" -ForegroundColor White }
        Write-Host "  ==========================================" -ForegroundColor Green
    }
    catch { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red }
}

# ==============================================================================
# MODE 2 - FULL-STACK PROJECT
# ==============================================================================
elseif ($mode -eq "2") {
    Write-Host ""
    Write-Host "  -- FULL-STACK PROJECT ------------------------" -ForegroundColor Yellow

    $projectName = (Read-Host "  Project name (e.g. bankflow)").Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($projectName)) { Write-Host "  ERROR: Name required." -ForegroundColor Red; exit 1 }

    Show-Menu -Title "Spring Profile" -Options $fullStackProfiles
    $profileKey = (Read-Host "  Choose [1-5]").Trim()
    if (-not $fullStackProfiles.ContainsKey($profileKey)) { Write-Host "  ERROR: Invalid." -ForegroundColor Red; exit 1 }
    $selectedProfile = $fullStackProfiles[$profileKey]

    Show-Menu -Title "Database" -Options $dbProfiles
    $dbKey = (Read-Host "  Choose [1-5]").Trim()
    if (-not $dbProfiles.ContainsKey($dbKey)) { Write-Host "  ERROR: Invalid." -ForegroundColor Red; exit 1 }
    $selectedDb = $dbProfiles[$dbKey]

    $dbName = ""
    if ($dbKey -ne "5") {
        $dbName = (Read-Host "  Database name").Trim()
        if ([string]::IsNullOrWhiteSpace($dbName)) { Write-Host "  ERROR: DB name required." -ForegroundColor Red; exit 1 }
    }

    $backendPort  = (Read-Host "  Backend port [8080]").Trim();  if ([string]::IsNullOrWhiteSpace($backendPort))  { $backendPort  = "8080" }
    $frontendPort = (Read-Host "  Frontend port [3000]").Trim(); if ([string]::IsNullOrWhiteSpace($frontendPort)) { $frontendPort = "3000" }

    $rootDir     = "$OutputDir\$projectName"
    $backendDir  = "$rootDir\$projectName-backend"
    $frontendDir = "$rootDir\$projectName-frontend"
    $groupId     = "com.$projectName"
    $allDeps     = if ($selectedDb.Dep -ne "") { "$($selectedProfile.Deps),$($selectedDb.Dep)" } else { $selectedProfile.Deps }
    $encodedDeps = $allDeps.Replace(",", "%2C")
    $artifactId  = "$projectName-backend"
    $url         = Get-InitializrUrl -GroupId $groupId -ArtifactId $artifactId -Name $artifactId -EncodedDeps $encodedDeps

    try {
        New-Item -ItemType Directory -Path $rootDir -Force | Out-Null

        Write-Host "  Downloading backend..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $url -OutFile "$rootDir\backend.zip" -ErrorAction Stop
        Expand-Archive "$rootDir\backend.zip" -DestinationPath $backendDir -Force
        Remove-Item "$rootDir\backend.zip" -Force

        $mainSrc = Get-MainSrcPath -ProjectDir $backendDir
        Get-ChildItem "$backendDir\src\test" -Filter "*.java" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Force }

        $pkgs = [System.Collections.Generic.List[string]]::new()
        $pkgs.AddRange([string[]]@("controller","service","dto","exception","config","utils"))
        if ($allDeps -like "*data-jpa*")   { $pkgs.AddRange([string[]]@("repository","entity","mapper")) }
        if ($allDeps -like "*security*")   { $pkgs.AddRange([string[]]@("security","filter")) }
        if ($allDeps -like "*kafka*")      { $pkgs.AddRange([string[]]@("event","producer","consumer")) }
        if ($allDeps -like "*data-redis*") { $pkgs.Add("cache") }

        Write-Host "  Creating packages..." -ForegroundColor Cyan
        foreach ($pkg in $pkgs) { New-Package -Path "$mainSrc\$pkg"; Write-Host "  + $pkg" -ForegroundColor DarkGreen }

        Write-YmlFile -ResourcesPath "$backendDir\src\main\resources" -ProjectName $projectName `
            -BackendPort $backendPort -DbKey $dbKey -DbProfile $selectedDb -DbName $dbName -AllDeps $allDeps

        Write-TextFile -FilePath "$backendDir\Dockerfile" -Lines @(
            "FROM maven:3.9-eclipse-temurin-21 AS builder"
            "WORKDIR /app"
            "COPY pom.xml ."
            "RUN mvn dependency:go-offline -B"
            "COPY src ./src"
            "RUN mvn clean package -DskipTests -B"
            ""
            "FROM eclipse-temurin:21-jre-alpine"
            "WORKDIR /app"
            'COPY --from=builder /app/target/*.jar app.jar'
            "EXPOSE $backendPort"
            'ENTRYPOINT ["java", "-jar", "app.jar"]'
        )

        New-Item -ItemType Directory -Path $frontendDir -Force | Out-Null
        Write-Host "  Setting up React frontend..." -ForegroundColor Cyan

        $hasNode = $false
        try { $nv = node --version 2>&1; if ($LASTEXITCODE -eq 0) { $hasNode = $true; Write-Host "  Node $nv found." -ForegroundColor Green } } catch {}

        if ($hasNode) {
            Push-Location $rootDir
            try {
                echo "y" | npm create vite@latest "$projectName-frontend" -- --template react
                Set-Location $frontendDir
                npm install
            } catch { Write-Host "  Vite scaffold failed, creating folders manually." -ForegroundColor Yellow }
            Pop-Location
        }

        $frontendFolders = @("src\api","src\assets","src\components","src\hooks","src\pages","src\routes","src\context","src\utils","public")
        foreach ($f in $frontendFolders) {
            $fp = "$frontendDir\$f"
            if (-not (Test-Path $fp)) { New-Item -ItemType Directory -Path $fp -Force | Out-Null }
            if (-not (Get-ChildItem $fp -ErrorAction SilentlyContinue)) { New-Item -ItemType File -Path "$fp\.gitkeep" -Force | Out-Null }
            Write-Host "  + $f" -ForegroundColor DarkGreen
        }

        Write-TextFile -FilePath "$frontendDir\.env" -Lines @(
            "VITE_API_BASE_URL=http://localhost:$backendPort/api"
            "VITE_APP_NAME=$projectName"
        )
        Write-TextFile -FilePath "$frontendDir\.gitignore" -Lines @("node_modules/","dist/",".env.local","*.log")
        Write-TextFile -FilePath "$frontendDir\src\api\api.js" -Lines @(
            "import axios from 'axios'"
            ""
            "const api = axios.create({ baseURL: import.meta.env.VITE_API_BASE_URL || '/api', timeout: 10000 })"
            ""
            "export default api"
        )

        Write-TextFile -FilePath "$rootDir\.gitignore" -Lines @("**/target/","**/node_modules/","**/dist/","**/.idea/","**/*.iml","**/*.log")
        Write-TextFile -FilePath "$rootDir\README.md" -Lines @(
            "# $projectName"
            ""
            "Backend:  http://localhost:$backendPort"
            "Frontend: http://localhost:$frontendPort"
        )

        Open-InIntelliJ -FolderPath $rootDir

        Write-Host ""; Write-Host "  ==========================================" -ForegroundColor Green
        Write-Host "   PROJECT READY!" -ForegroundColor Green
        Write-Host "  ==========================================" -ForegroundColor Green
        Write-Host "   Name     : $projectName" -ForegroundColor White
        Write-Host "   Backend  : http://localhost:$backendPort" -ForegroundColor White
        Write-Host "   Frontend : http://localhost:$frontendPort" -ForegroundColor White
        Write-Host "   Location : $rootDir" -ForegroundColor White
        Write-Host "  ==========================================" -ForegroundColor Green
    }
    catch { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red }
}

# ==============================================================================
# MODE 3 - MICROSERVICES
# ==============================================================================
elseif ($mode -eq "3") {
    Write-Host ""
    Write-Host "  -- MICROSERVICES -----------------------------" -ForegroundColor Yellow

    $appName = (Read-Host "  App name (e.g. ecommerce)").Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($appName)) { Write-Host "  ERROR: Name required." -ForegroundColor Red; exit 1 }

    $dbName = (Read-Host "  Database name").Trim()
    if ([string]::IsNullOrWhiteSpace($dbName)) { Write-Host "  ERROR: DB name required." -ForegroundColor Red; exit 1 }

    $services = @()
    Write-Host "  Enter service names one by one (blank line to finish):" -ForegroundColor Cyan
    while ($true) {
        $svc = (Read-Host "  Service name").Trim()
        if ([string]::IsNullOrWhiteSpace($svc)) { break }
        $services += $svc
        Write-Host "  + $svc added" -ForegroundColor DarkGreen
    }
    if ($services.Count -eq 0) { Write-Host "  ERROR: At least one service required." -ForegroundColor Red; exit 1 }

    $parentDir = "$OutputDir\$appName-microservice"
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null

    try {
        $port = 8081
        foreach ($svc in $services) {
            $fullName    = "$svc-service"
            $artifactId  = $fullName.ToLower() -replace '[^a-z0-9]', ''
            $groupId     = "com.basics.$artifactId"
            $deps        = "web,data-jpa,mysql,lombok"
            $encodedDeps = $deps.Replace(",", "%2C")
            $url         = Get-InitializrUrl -GroupId $groupId -ArtifactId $artifactId -Name $fullName -EncodedDeps $encodedDeps

            Write-Host "  Creating $fullName (port $port)..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $url -OutFile "$parentDir\$fullName.zip" -ErrorAction Stop
            Expand-Archive "$parentDir\$fullName.zip" -DestinationPath "$parentDir\$fullName" -Force
            Remove-Item "$parentDir\$fullName.zip" -Force

            $mainSrc = Get-MainSrcPath -ProjectDir "$parentDir\$fullName"
            foreach ($pkg in @("controller","service","repository","entity","dto","mapper","exception","config")) {
                New-Package -Path "$mainSrc\$pkg"
                Write-Host "    + $pkg" -ForegroundColor DarkGreen
            }

            $mysqlUrl = "jdbc:mysql://localhost:3306/" + $dbName + "?useSSL=false" + "`&serverTimezone=UTC"
            $props = @(
                "spring.application.name=$fullName"
                "server.port=$port"
                ""
                "spring.datasource.url=$mysqlUrl"
                "spring.datasource.username=root"
                "spring.datasource.password=root"
                "spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver"
                ""
                "spring.jpa.hibernate.ddl-auto=update"
                "spring.jpa.show-sql=true"
                "spring.jpa.properties.hibernate.format_sql=true"
                "spring.jpa.database-platform=org.hibernate.dialect.MySQLDialect"
                "spring.datasource.hikari.maximum-pool-size=10"
                "spring.datasource.hikari.minimum-idle=5"
            )
            Write-TextFile -FilePath "$parentDir\$fullName\src\main\resources\application.properties" -Lines $props
            Write-Host "  application.properties written for $fullName" -ForegroundColor Green
            $port++
        }

        $readme = "# $appName Microservices`n`n## Services`n`n"
        $p = 8081
        foreach ($svc in $services) { $readme += "- **$svc-service**: http://localhost:$p`n"; $p++ }
        $readme += "`n## Database`n``````sql`nCREATE DATABASE $dbName;`n``````"
        Set-Content -Path "$parentDir\README.md" -Value $readme -Encoding UTF8

        Open-InIntelliJ -FolderPath $parentDir

        Write-Host ""; Write-Host "  ==========================================" -ForegroundColor Green
        Write-Host "   MICROSERVICES READY!" -ForegroundColor Green
        Write-Host "  ==========================================" -ForegroundColor Green
        Write-Host "   App      : $appName" -ForegroundColor White
        Write-Host "   Services : $($services.Count)" -ForegroundColor White
        Write-Host "   Location : $parentDir" -ForegroundColor White
        Write-Host "  ==========================================" -ForegroundColor Green
    }
    catch { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red }
}

# ==============================================================================
# MODE 4 - MAVEN PROJECT
# ==============================================================================
elseif ($mode -eq "4") {
    Write-Host ""
    Write-Host "  -- MAVEN PROJECT ----------------------------" -ForegroundColor Yellow

    $projectName = (Read-Host "  Project name (e.g. DSAPractice)").Trim()
    if ([string]::IsNullOrWhiteSpace($projectName)) { Write-Host "  ERROR: Name required." -ForegroundColor Red; exit 1 }

    $groupId = (Read-Host "  Group ID [com.learning]").Trim()
    if ([string]::IsNullOrWhiteSpace($groupId)) { $groupId = "com.learning" }

    $artifactId = $projectName.ToLower() -replace '[^a-z0-9]', ''

    Write-Host ""
    Write-Host "  Available packages:" -ForegroundColor Yellow
    Write-Host "  [1] basics  [2] advanced  [3] medium  [4] dsatopics  [5] problems  [C] custom  [D] done" -ForegroundColor Cyan
    Write-Host ""

    $availPkgs    = @{ "1"="basics"; "2"="advanced"; "3"="medium"; "4"="dsatopics"; "5"="problems" }
    $selectedPkgs = @()

    while ($true) {
        $choice = (Read-Host "  Add package").Trim()
        if ($choice -eq "D" -or $choice -eq "d") { break }
        if ($choice -eq "C" -or $choice -eq "c") {
            $custom = (Read-Host "  Custom name").Trim().ToLower() -replace '[^a-z0-9]', ''
            if ($custom -ne "" -and $selectedPkgs -notcontains $custom) {
                $selectedPkgs += $custom
                Write-Host "  + $custom" -ForegroundColor DarkGreen
            }
        }
        elseif ($availPkgs.ContainsKey($choice) -and $selectedPkgs -notcontains $availPkgs[$choice]) {
            $selectedPkgs += $availPkgs[$choice]
            Write-Host "  + $($availPkgs[$choice])" -ForegroundColor DarkGreen
        }
    }

    try {
        Write-Host ""; Write-Host "  Generating Maven project..." -ForegroundColor Cyan
        Set-Location $OutputDir
        & mvn archetype:generate `
            "-DgroupId=$groupId" `
            "-DartifactId=$artifactId" `
            "-DarchetypeArtifactId=maven-archetype-quickstart" `
            "-DarchetypeVersion=1.4" `
            "-DinteractiveMode=false"

        if (-not (Test-Path "$OutputDir\$artifactId")) { throw "Maven generation failed." }

        # Patch pom.xml to use Java 25 instead of default Java 7
$pomPath = "$OutputDir\$artifactId\pom.xml"
$pomContent = Get-Content $pomPath -Raw
$pomContent = $pomContent -replace '<maven.compiler.source>1\.\d</maven.compiler.source>', '<maven.compiler.source>25</maven.compiler.source>'
$pomContent = $pomContent -replace '<maven.compiler.target>1\.\d</maven.compiler.target>', '<maven.compiler.target>25</maven.compiler.target>'
$pomContent = $pomContent -replace '<maven.compiler.source>\d+</maven.compiler.source>', '<maven.compiler.source>25</maven.compiler.source>'
$pomContent = $pomContent -replace '<maven.compiler.target>\d+</maven.compiler.target>', '<maven.compiler.target>25</maven.compiler.target>'
Set-Content -Path $pomPath -Value $pomContent -Encoding UTF8
Write-Host "  pom.xml patched to Java 25." -ForegroundColor Green

        if ($selectedPkgs.Count -gt 0) {
            $groupPath = $groupId -replace '\.', '\'
            $srcRoot   = "$OutputDir\$artifactId\src\main\java\$groupPath"
            foreach ($pkg in $selectedPkgs) {
                New-Package -Path "$srcRoot\$pkg"
                Write-Host "  + $pkg" -ForegroundColor DarkGreen
            }
        }

        Write-Host "  Running mvn compile..." -ForegroundColor Cyan
        Push-Location "$OutputDir\$artifactId"
        & mvn compile
        Pop-Location

        Open-InIntelliJ -FolderPath "$OutputDir\$artifactId"

        Write-Host ""; Write-Host "  ==========================================" -ForegroundColor Green
        Write-Host "   MAVEN PROJECT READY!" -ForegroundColor Green
        Write-Host "  ==========================================" -ForegroundColor Green
        Write-Host "   Name     : $projectName" -ForegroundColor White
        Write-Host "   Group    : $groupId" -ForegroundColor White
        Write-Host "   Location : $OutputDir\$artifactId" -ForegroundColor White
        Write-Host "  ==========================================" -ForegroundColor Green
    }
    catch { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red }
}
else {
    Write-Host "  ERROR: Invalid mode. Choose 1-4." -ForegroundColor Red
}
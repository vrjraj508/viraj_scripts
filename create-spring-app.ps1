$ErrorActionPreference = "Stop"

# ==============================
# SPRING LEARNING PROFILES
# ==============================
$profiles = @{
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

# ==============================
# DATABASE PROFILES
# ==============================
$dbProfiles = @{
    "1" = @{ Name = "MySQL";          Dep = "mysql";        Driver = "com.mysql.cj.jdbc.Driver";  Dialect = "org.hibernate.dialect.MySQLDialect" }
    "2" = @{ Name = "PostgreSQL";     Dep = "postgresql";   Driver = "org.postgresql.Driver";     Dialect = "org.hibernate.dialect.PostgreSQLDialect" }
    "3" = @{ Name = "MongoDB";        Dep = "data-mongodb"; Driver = "";                          Dialect = "" }
    "4" = @{ Name = "H2 (In-Memory)"; Dep = "h2";           Driver = "org.h2.Driver";             Dialect = "org.hibernate.dialect.H2Dialect" }
    "5" = @{ Name = "No Database";    Dep = "";             Driver = "";                          Dialect = "" }
}

# ==============================
# OPEN IN INTELLIJ
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
    foreach ($path in $ideaPaths) {
        if (Test-Path $path) {
            Start-Process -FilePath $path -ArgumentList "`"$folderPath`""
            return
        }
    }
    try { Start-Process "idea64.exe" -ArgumentList "`"$folderPath`"" }
    catch { Write-Host "Could not open IntelliJ. Open manually: $folderPath" -ForegroundColor Yellow }
}

# ==============================
# DISPLAY MENU HELPER
# ==============================
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

# ==============================
# HEADER
# ==============================
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host "    SPRING BOOT LEARNING PROJECT CREATOR   " -ForegroundColor Magenta
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host ""

# ==============================
# INPUT
# ==============================
$projectName = Read-Host "  Enter project name"
if ([string]::IsNullOrWhiteSpace($projectName)) {
    Write-Host "ERROR: Project name required!" -ForegroundColor Red
    exit 1
}

# ==============================
# SELECT SPRING PROFILE
# ==============================
Show-Menu -Title "Select Learning Profile" -Options $profiles
$profileKey = Read-Host "  Choose profile [1-9]"
if (-not $profiles.ContainsKey($profileKey)) {
    Write-Host "ERROR: Invalid profile!" -ForegroundColor Red
    exit 1
}
$selectedProfile = $profiles[$profileKey]

# ==============================
# SELECT DATABASE
# ==============================
Show-Menu -Title "Select Database" -Options $dbProfiles
$dbKey = Read-Host "  Choose database [1-5]"
if (-not $dbProfiles.ContainsKey($dbKey)) {
    Write-Host "ERROR: Invalid database choice!" -ForegroundColor Red
    exit 1
}
$selectedDb = $dbProfiles[$dbKey]

$dbName = ""
if ($dbKey -ne "5") {
    $dbName = Read-Host "  Enter DB name"
    if ([string]::IsNullOrWhiteSpace($dbName)) {
        Write-Host "ERROR: DB name required!" -ForegroundColor Red
        exit 1
    }
}

# ==============================
# BUILD DEPENDENCIES
# ==============================
$allDeps = $selectedProfile.Deps
if ($selectedDb.Dep -ne "") { $allDeps = $allDeps + "," + $selectedDb.Dep }
$encodedDeps = $allDeps.Replace(",", "%2C")

$basePackage = "com.learn.$($projectName.ToLower())"
$outputDir   = "$PWD"

# ==============================
# BUILD URL (safe concatenation)
# ==============================
$url = "https://start.spring.io/starter.zip?type=maven-project&language=java&javaVersion=21&groupId=com.learn&artifactId=$projectName&name=$projectName&packageName=$basePackage&dependencies=$encodedDeps"

try {
    Write-Host ""
    Write-Host "  Downloading Spring Boot project..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile "$outputDir\$projectName.zip" -ErrorAction Stop

    Write-Host "  Extracting..." -ForegroundColor Cyan
    Expand-Archive "$outputDir\$projectName.zip" -DestinationPath "$outputDir\$projectName" -Force
    Remove-Item "$outputDir\$projectName.zip" -Force

    # Find main class location
    $mainJavaFile = Get-ChildItem -Path "$outputDir\$projectName\src\main\java" `
                        -Filter "*Application.java" -Recurse | Select-Object -First 1
    if ($null -eq $mainJavaFile) {
        Write-Host "ERROR: Could not find Application.java" -ForegroundColor Red
        exit 1
    }
    $mainPath = $mainJavaFile.DirectoryName

    # Create packages
    Write-Host "  Creating packages..." -ForegroundColor Cyan
    foreach ($folder in $selectedProfile.Packages) {
        New-Item -ItemType Directory -Path "$mainPath\$folder" -Force | Out-Null
        New-Item -ItemType File -Path "$mainPath\$folder\.gitkeep" -Force | Out-Null
        Write-Host "     + $folder" -ForegroundColor DarkGreen
    }

    # Delete test files
    Get-ChildItem -Path "$outputDir\$projectName\src\test" -Filter "*.java" -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item $_.FullName -Force }

    # ==============================
    # BUILD application.properties
    # ==============================
    $resourcesPath = "$outputDir\$projectName\src\main\resources"
    $lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add("# ========================")
    $lines.Add("# SERVER")
    $lines.Add("# ========================")
    $lines.Add("server.port=8080")
    $lines.Add("spring.application.name=$projectName")
    $lines.Add("")

    if ($dbKey -eq "1") {
        $jdbcUrl = "jdbc:mysql://localhost:3306/" + $dbName + "?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true"
        $lines.Add("# ========================")
        $lines.Add("# DATABASE - MySQL")
        $lines.Add("# ========================")
        $lines.Add("spring.datasource.url=$jdbcUrl")
        $lines.Add("spring.datasource.username=root")
        $lines.Add("spring.datasource.password=viraj@123")
        $lines.Add("spring.datasource.driver-class-name=$($selectedDb.Driver)")
        $lines.Add("")
        $lines.Add("# ========================")
        $lines.Add("# JPA / Hibernate")
        $lines.Add("# ========================")
        $lines.Add("spring.jpa.hibernate.ddl-auto=update")
        $lines.Add("spring.jpa.show-sql=true")
        $lines.Add("spring.jpa.properties.hibernate.format_sql=true")
        $lines.Add("spring.jpa.database-platform=$($selectedDb.Dialect)")
    }
    elseif ($dbKey -eq "2") {
        $lines.Add("# ========================")
        $lines.Add("# DATABASE - PostgreSQL")
        $lines.Add("# ========================")
        $lines.Add("spring.datasource.url=jdbc:postgresql://localhost:5432/$dbName")
        $lines.Add("spring.datasource.username=postgres")
        $lines.Add("spring.datasource.password=postgres")
        $lines.Add("spring.datasource.driver-class-name=$($selectedDb.Driver)")
        $lines.Add("")
        $lines.Add("# ========================")
        $lines.Add("# JPA / Hibernate")
        $lines.Add("# ========================")
        $lines.Add("spring.jpa.hibernate.ddl-auto=update")
        $lines.Add("spring.jpa.show-sql=true")
        $lines.Add("spring.jpa.properties.hibernate.format_sql=true")
        $lines.Add("spring.jpa.database-platform=$($selectedDb.Dialect)")
    }
    elseif ($dbKey -eq "3") {
        $lines.Add("# ========================")
        $lines.Add("# DATABASE - MongoDB")
        $lines.Add("# ========================")
        $lines.Add("spring.data.mongodb.host=localhost")
        $lines.Add("spring.data.mongodb.port=27017")
        $lines.Add("spring.data.mongodb.database=$dbName")
    }
    elseif ($dbKey -eq "4") {
        $lines.Add("# ========================")
        $lines.Add("# DATABASE - H2 In-Memory")
        $lines.Add("# ========================")
        $lines.Add("spring.datasource.url=jdbc:h2:mem:$dbName")
        $lines.Add("spring.datasource.driver-class-name=$($selectedDb.Driver)")
        $lines.Add("spring.datasource.username=sa")
        $lines.Add("spring.datasource.password=")
        $lines.Add("spring.h2.console.enabled=true")
        $lines.Add("spring.h2.console.path=/h2-console")
        $lines.Add("")
        $lines.Add("# ========================")
        $lines.Add("# JPA / Hibernate")
        $lines.Add("# ========================")
        $lines.Add("spring.jpa.hibernate.ddl-auto=update")
        $lines.Add("spring.jpa.show-sql=true")
        $lines.Add("spring.jpa.properties.hibernate.format_sql=true")
        $lines.Add("spring.jpa.database-platform=$($selectedDb.Dialect)")
    }

    Set-Content -Path "$resourcesPath\application.properties" -Value $lines -Encoding UTF8

    # Open in IntelliJ
    Open-InIntelliJ -folderPath "$outputDir\$projectName"

    # ==============================
    # SUMMARY
    # ==============================
    Write-Host ""
    Write-Host "  ==========================================" -ForegroundColor Green
    Write-Host "   PROJECT READY!" -ForegroundColor Green
    Write-Host "  ==========================================" -ForegroundColor Green
    Write-Host "   Project  : $projectName" -ForegroundColor White
    Write-Host "   Profile  : $($selectedProfile.Name)" -ForegroundColor White
    Write-Host "   Database : $($selectedDb.Name)" -ForegroundColor White
    if ($dbName -ne "") { Write-Host "   DB Name  : $dbName" -ForegroundColor White }
    Write-Host "   Package  : $basePackage" -ForegroundColor White
    Write-Host "   Java     : 21  |  Build: Maven" -ForegroundColor White
    Write-Host "   Packages : $($selectedProfile.Packages -join ', ')" -ForegroundColor DarkGray
    Write-Host "  ==========================================" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path "$outputDir\$projectName.zip") { Remove-Item "$outputDir\$projectName.zip" -Force }
}
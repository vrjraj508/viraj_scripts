param(
    [string]$ProjectName = ""
)

$ErrorActionPreference = "Stop"

# ============================================================
# Profile Definitions
# ============================================================
$Profiles = @{
    "1" = @{ Name = "core";            JavaVersion = "21"; Packages = @("basics","dsatopics","problems") }
    "2" = @{ Name = "advanced-java";   JavaVersion = "21"; Packages = @("advanced","medium","concurrency") }
    "3" = @{ Name = "jdbc";            JavaVersion = "21"; Packages = @("jdbc","connection","dao","model") }
    "4" = @{ Name = "latest-features"; JavaVersion = "25"; Packages = @("previewfeatures","records","patterns") }
    "5" = @{ Name = "latest";          JavaVersion = "DYNAMIC"; Packages = @("basics","dsatopics","problems") }
    "6" = @{ Name = "custom";          JavaVersion = "CUSTOM"; Packages = @() }
}

# ============================================================
# Fetch latest Java LTS version dynamically from Adoptium API
# ============================================================
function Get-LatestJavaLTS {
    Write-Host "Fetching latest Java LTS version from Adoptium API..." -ForegroundColor Cyan
    try {
        $response = Invoke-RestMethod -Uri "https://api.adoptium.net/v3/info/available_releases" -Method Get -TimeoutSec 10
        $lts = $response.most_recent_lts
        Write-Host "Latest Java LTS detected: $lts" -ForegroundColor Green
        return $lts.ToString()
    } catch {
        Write-Host "WARNING: Could not reach Adoptium API. Falling back to Java 21." -ForegroundColor Yellow
        return "21"
    }
}

# ============================================================
# Open project in a NEW IntelliJ window reliably
# ============================================================
function Open-InIntelliJ {
    param ([string]$folderPath)

    # Prefer idea.bat (command-line launcher) over idea64.exe -
    # idea.bat is more reliable for opening a NEW window when an
    # instance is already running.
    $ideaBatPaths = @(
        "C:\Program Files\JetBrains\IntelliJ IDEA 2025.3.1.1\bin\idea.bat",
        "C:\Program Files\JetBrains\IntelliJ IDEA 2024.3\bin\idea.bat",
        "C:\Program Files\JetBrains\IntelliJ IDEA\bin\idea.bat",
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2024.3\bin\idea.bat",
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition\bin\idea.bat"
    )

    $ideaExePaths = @(
        "C:\Program Files\JetBrains\IntelliJ IDEA 2025.3.1.1\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA 2024.3\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2024.3\bin\idea64.exe",
        "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition\bin\idea64.exe"
    )

    $opened = $false

    # 1. Try idea.bat first (reliable new-window behavior)
    foreach ($path in $ideaBatPaths) {
        if (Test-Path $path) {
            Write-Host "Opening IntelliJ (new window) from: $path" -ForegroundColor Cyan
            Start-Process -FilePath $path -ArgumentList "`"$folderPath`""
            $opened = $true
            break
        }
    }

    # 2. Try Toolbox install
    if (-not $opened) {
        $toolboxPattern = "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\IDEA*\*\*\bin\idea.bat"
        $bat = Get-ChildItem $toolboxPattern -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1
        if ($bat) {
            Write-Host "Opening IntelliJ (new window) from Toolbox: $($bat.FullName)" -ForegroundColor Cyan
            Start-Process -FilePath $bat.FullName -ArgumentList "`"$folderPath`""
            $opened = $true
        }
    }

    # 3. Fallback to idea64.exe directly
    if (-not $opened) {
        foreach ($path in $ideaExePaths) {
            if (Test-Path $path) {
                Write-Host "Opening IntelliJ from: $path" -ForegroundColor Cyan
                Start-Process -FilePath $path -ArgumentList "`"$folderPath`""
                $opened = $true
                break
            }
        }
    }

    # 4. Fallback to CLI 'idea' command
    if (-not $opened) {
        if (Get-Command idea -ErrorAction SilentlyContinue) {
            Write-Host "Opening IntelliJ via CLI..." -ForegroundColor Cyan
            & idea $folderPath
            $opened = $true
        }
    }

    if (-not $opened) {
        Write-Host "WARNING: Could not open IntelliJ automatically." -ForegroundColor Yellow
        Write-Host "Open manually: $folderPath" -ForegroundColor Yellow
    } else {
        Write-Host "IntelliJ launch triggered (new window)!" -ForegroundColor Green
    }
}

# ============================================================
# Create package folders (auto, based on profile) or prompt (custom)
# ============================================================
function New-PackageFolders {
    param (
        [string]$groupId,
        [string]$srcRoot,
        [string[]]$packages
    )

    $groupPath = $groupId -replace '\.', '\'

    Write-Host ""
    Write-Host "Creating package folders..." -ForegroundColor Cyan
    foreach ($pkg in $packages) {
        $fullPath = Join-Path $srcRoot "$groupPath\$pkg"
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            Write-Host "  Created: src\main\java\$groupPath\$pkg" -ForegroundColor Green
        } else {
            Write-Host "  Already exists: $pkg" -ForegroundColor Yellow
        }
    }
    Write-Host "Packages created successfully!" -ForegroundColor Green
}

function Select-PackagesCustom {
    param ([string]$groupId, [string]$srcRoot)

    $availablePackages = @("basics", "advanced", "medium", "dsatopics", "problems")
    Write-Host ""
    Write-Host "Available packages:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $availablePackages.Length; $i++) {
        Write-Host "  [$($i + 1)] $($availablePackages[$i])"
    }
    Write-Host "  [C] Custom package name"
    Write-Host "  [D] Done - no more packages"
    Write-Host ""

    $selectedPackages = @()
    while ($true) {
        $choice = Read-Host "Select package to add (1-$($availablePackages.Length) / C / D)"
        if ($choice -eq "D" -or $choice -eq "d") { break }
        if ($choice -eq "C" -or $choice -eq "c") {
            $customPkg = Read-Host "Enter custom package name"
            if (-not [string]::IsNullOrWhiteSpace($customPkg)) {
                $customPkg = $customPkg.ToLower() -replace '[^a-z0-9]', ''
                if ($selectedPackages -notcontains $customPkg) {
                    $selectedPackages += $customPkg
                    Write-Host "  Added: $customPkg" -ForegroundColor Green
                }
            }
            continue
        }
        $index = 0
        if ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $availablePackages.Length) {
            $pkg = $availablePackages[$index - 1]
            if ($selectedPackages -notcontains $pkg) {
                $selectedPackages += $pkg
                Write-Host "  Added: $pkg" -ForegroundColor Green
            }
        } else {
            Write-Host "  Invalid choice, try again." -ForegroundColor Red
        }
    }

    New-PackageFolders -groupId $groupId -srcRoot $srcRoot -packages $selectedPackages
}

# ============================================================
# Update pom.xml with the chosen Java version
# ============================================================
function Set-PomJavaVersion {
    param ([string]$pomFilePath, [string]$javaVersion)

    $pom = Get-Content $pomFilePath -Raw

    $pom = $pom -replace '<maven\.compiler\.source>[^<]+</maven\.compiler\.source>', "<maven.compiler.source>$javaVersion</maven.compiler.source>"
    $pom = $pom -replace '<maven\.compiler\.target>[^<]+</maven\.compiler\.target>', "<maven.compiler.target>$javaVersion</maven.compiler.target>"

    if ($pom -notmatch '<maven\.compiler\.source>') {
        $pom = $pom -replace '(<properties>)', "<properties>`n    <maven.compiler.source>$javaVersion</maven.compiler.source>`n    <maven.compiler.target>$javaVersion</maven.compiler.target>"
    }

    if ($pom -notmatch '<properties>') {
        $pom = $pom -replace '(<version>[^<]+</version>)', "<version>1.0-SNAPSHOT</version>`n  <properties>`n    <maven.compiler.source>$javaVersion</maven.compiler.source>`n    <maven.compiler.target>$javaVersion</maven.compiler.target>`n    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>`n  </properties>"
    }

    $pom = $pom -replace '<artifactId>maven-compiler-plugin</artifactId>\s*<version>[^<]+</version>', "<artifactId>maven-compiler-plugin</artifactId>`n                <version>3.13.0</version>"

    Set-Content $pomFilePath $pom -Encoding UTF8
    Write-Host "pom.xml updated to Java $javaVersion" -ForegroundColor Green
}

# ============================================================
# MAIN
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Maven Project Generator Tool" -ForegroundColor Cyan
Write-Host "   Profile-Based Java Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {

    # ---- Project Name ----
    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        $ProjectName = Read-Host "Enter Project Name"
    }
    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        Write-Host "ERROR: Project name cannot be empty" -ForegroundColor Red
        exit 1
    }

    $artifactId = $ProjectName.ToLower() -replace '[^a-z0-9]', ''

    # ---- Profile Selection ----
    Write-Host ""
    Write-Host "Select a profile:" -ForegroundColor Yellow
    Write-Host "  [1] core             - Java 21 LTS  (basics, dsatopics, problems)"
    Write-Host "  [2] advanced-java    - Java 21 LTS  (advanced, medium, concurrency)"
    Write-Host "  [3] jdbc             - Java 21 LTS  (jdbc, connection, dao, model)"
    Write-Host "  [4] latest-features  - Java 25 LTS  (previewfeatures, records, patterns)"
    Write-Host "  [5] latest           - DYNAMIC (fetched from Adoptium API at run time)"
    Write-Host "  [6] custom           - Manual entry (Java version + packages)"
    Write-Host ""

    $profileChoice = Read-Host "Enter profile number (1-6)"
    if (-not $Profiles.ContainsKey($profileChoice)) {
        Write-Host "ERROR: Invalid profile selection" -ForegroundColor Red
        exit 1
    }
    $selectedProfile = $Profiles[$profileChoice]

    # ---- Resolve Java Version ----
    $javaVersion = $selectedProfile.JavaVersion
    if ($javaVersion -eq "DYNAMIC") {
        $javaVersion = Get-LatestJavaLTS
    } elseif ($javaVersion -eq "CUSTOM") {
        $javaVersion = Read-Host "Enter Java version (e.g. 17, 21, 25)"
        if ([string]::IsNullOrWhiteSpace($javaVersion)) { $javaVersion = "21" }
    }

    # ---- Group ID (auto-derived, overridable) ----
    $groupId = Read-Host "Group ID [com.learning] (press Enter to accept default)"
    if ([string]::IsNullOrWhiteSpace($groupId)) { $groupId = "com.learning" }

    Write-Host ""
    Write-Host "Project Details:" -ForegroundColor Cyan
    Write-Host "  Name     : $ProjectName"
    Write-Host "  Profile  : $($selectedProfile.Name)"
    Write-Host "  Group    : $groupId"
    Write-Host "  Artifact : $artifactId"
    Write-Host "  Java     : $javaVersion"
    Write-Host ""

    # ---- Check Maven ----
    Write-Host "Checking Maven..." -ForegroundColor Cyan
    try {
        $mvnVersion = & mvn -version 2>&1
        Write-Host "$mvnVersion" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Maven is not installed or not in PATH" -ForegroundColor Red
        exit 1
    }

    if (Test-Path $artifactId) {
        Write-Host ""
        Write-Host "Removing existing project folder: $artifactId" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $artifactId
    }

    # ---- Generate Project ----
    Write-Host ""
    Write-Host "Generating Maven project..." -ForegroundColor Cyan

    & mvn archetype:generate `
        "-DgroupId=$groupId" `
        "-DartifactId=$artifactId" `
        "-DarchetypeArtifactId=maven-archetype-quickstart" `
        "-DarchetypeVersion=1.4" `
        "-DinteractiveMode=false"

    if (-not (Test-Path $artifactId)) {
        Write-Host "ERROR: Project generation failed" -ForegroundColor Red
        exit 1
    }

    $parentPath  = (Get-Location).Path
    $lowercasePath = Join-Path $parentPath $artifactId
    $correctPath   = Join-Path $parentPath $ProjectName

    if ($artifactId -ne $ProjectName) {
        $tempPath = Join-Path $parentPath ($artifactId + "_temp_rename")
        Rename-Item -Path $lowercasePath -NewName ($artifactId + "_temp_rename")
        Rename-Item -Path $tempPath -NewName $ProjectName
        Write-Host "Project folder set to: $ProjectName" -ForegroundColor Green
    }

    Set-Location $correctPath
    $projectPath = (Get-Location).Path

    Write-Host ""
    Write-Host "Project created at: $projectPath" -ForegroundColor Green

    # ---- Configure pom.xml ----
    Write-Host ""
    Write-Host "Configuring pom.xml for Java $javaVersion..." -ForegroundColor Cyan
    $pomPath = Join-Path $projectPath "pom.xml"
    Set-PomJavaVersion -pomFilePath $pomPath -javaVersion $javaVersion

    # ---- Create Packages ----
    $srcRoot = Join-Path $projectPath "src\main\java"
    if ($selectedProfile.Name -eq "custom") {
        Select-PackagesCustom -groupId $groupId -srcRoot $srcRoot
    } else {
        New-PackageFolders -groupId $groupId -srcRoot $srcRoot -packages $selectedProfile.Packages
    }

    # ---- Build ----
    Write-Host ""
    Write-Host "Building project (mvn compile)..." -ForegroundColor Cyan
    & mvn compile

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Maven build failed. Check pom.xml and JDK installation." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "Build completed successfully!" -ForegroundColor Green

    # ---- Open in IntelliJ (new window) ----
    Write-Host ""
    Write-Host "Opening project in IntelliJ (new window)..." -ForegroundColor Cyan
    Open-InIntelliJ -folderPath $projectPath

    # ---- Summary ----
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "   PROJECT READY" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Project Location : $projectPath" -ForegroundColor Cyan
    Write-Host "Profile          : $($selectedProfile.Name)" -ForegroundColor Cyan
    Write-Host "Java Version     : $javaVersion" -ForegroundColor Cyan
    Write-Host "Group ID         : $groupId" -ForegroundColor Cyan
    Write-Host "Artifact ID      : $artifactId" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Useful Commands:" -ForegroundColor Cyan
    Write-Host "  mvn compile"
    Write-Host "  mvn test"
    Write-Host "  mvn package"
    Write-Host "  mvn exec:java -Dexec.mainClass=$groupId.App"
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "ERROR OCCURRED:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
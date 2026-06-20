param(
    [string]$ProjectName = ""
)

$ErrorActionPreference = "Stop"

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
            Write-Host "Opening IntelliJ from: $path" -ForegroundColor Cyan
            Start-Process -FilePath $path -ArgumentList "`"$folderPath`""
            $opened = $true
            break
        }
    }

    if (-not $opened) {
        $toolboxPattern = "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\IDEA*\*\*\bin\idea64.exe"
        $exe = Get-ChildItem $toolboxPattern -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1
        if ($exe) {
            Write-Host "Opening IntelliJ from Toolbox: $($exe.FullName)" -ForegroundColor Cyan
            Start-Process -FilePath $exe.FullName -ArgumentList "`"$folderPath`""
            $opened = $true
        }
    }

    if (-not $opened) {
        if (Get-Command idea -ErrorAction SilentlyContinue) {
            Write-Host "Opening IntelliJ via CLI..." -ForegroundColor Cyan
            & idea $folderPath
            $opened = $true
        }
    }

    if (-not $opened) {
        try {
            Start-Process "idea64.exe" -ArgumentList "`"$folderPath`""
            $opened = $true
        } catch {
            Write-Host "WARNING: Could not open IntelliJ automatically." -ForegroundColor Yellow
            Write-Host "Open manually: $folderPath" -ForegroundColor Yellow
        }
    }

    if ($opened) {
        Write-Host "IntelliJ launched successfully!" -ForegroundColor Green
    }
}

function Select-Packages {
    param (
        [string]$groupId,
        [string]$srcRoot
    )

    $availablePackages = @("basics", "advanced", "medium", "dsatopics", "problems")

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   Package Selection" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
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

        if ($choice -eq "D" -or $choice -eq "d") {
            break
        }

        if ($choice -eq "C" -or $choice -eq "c") {
            $customPkg = Read-Host "Enter custom package name"
            if (-not [string]::IsNullOrWhiteSpace($customPkg)) {
                $customPkg = $customPkg.ToLower() -replace '[^a-z0-9]', ''
                if ($selectedPackages -notcontains $customPkg) {
                    $selectedPackages += $customPkg
                    Write-Host "  Added: $customPkg" -ForegroundColor Green
                } else {
                    Write-Host "  Already added: $customPkg" -ForegroundColor Yellow
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
            } else {
                Write-Host "  Already added: $pkg" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Invalid choice, try again." -ForegroundColor Red
        }
    }

    if ($selectedPackages.Length -gt 0) {
        Write-Host ""
        Write-Host "Creating package folders..." -ForegroundColor Cyan

        $groupPath = $groupId -replace '\.', '\'

        foreach ($pkg in $selectedPackages) {
            $fullPath = Join-Path $srcRoot "$groupPath\$pkg"
            if (-not (Test-Path $fullPath)) {
                New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                Write-Host "  Created: src\main\java\$groupPath\$pkg" -ForegroundColor Green
            } else {
                Write-Host "  Already exists: $pkg" -ForegroundColor Yellow
            }
        }

        Write-Host ""
        Write-Host "Packages created successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "No packages selected." -ForegroundColor Yellow
    }
}

function Set-PomToJava25 {
    param ([string]$pomFilePath)

    $pom = Get-Content $pomFilePath -Raw

    $pom = $pom -replace '<maven\.compiler\.source>[^<]+</maven\.compiler\.source>', '<maven.compiler.source>25</maven.compiler.source>'
    $pom = $pom -replace '<maven\.compiler\.target>[^<]+</maven\.compiler\.target>', '<maven.compiler.target>25</maven.compiler.target>'

    if ($pom -notmatch '<maven\.compiler\.source>') {
        $pom = $pom -replace '(<properties>)', "<properties>`n    <maven.compiler.source>25</maven.compiler.source>`n    <maven.compiler.target>25</maven.compiler.target>"
    }

    if ($pom -notmatch '<properties>') {
        $pom = $pom -replace '(<version>[^<]+</version>)', "<version>1.0-SNAPSHOT</version>`n  <properties>`n    <maven.compiler.source>25</maven.compiler.source>`n    <maven.compiler.target>25</maven.compiler.target>`n    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>`n  </properties>"
    }

    $pom = $pom -replace '<artifactId>maven-compiler-plugin</artifactId>\s*<version>[^<]+</version>', "<artifactId>maven-compiler-plugin</artifactId>`n                <version>3.13.0</version>"

    Set-Content $pomFilePath $pom -Encoding UTF8
    Write-Host "pom.xml updated to Java 25 LTS" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Maven Project Generator Tool" -ForegroundColor Cyan
Write-Host "   Java 25 LTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {

    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        $ProjectName = Read-Host "Enter Project Name"
    }

    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        Write-Host "ERROR: Project name cannot be empty" -ForegroundColor Red
        exit 1
    }

    $artifactId = $ProjectName.ToLower() -replace '[^a-z0-9]', ''

    $groupId = Read-Host "Group ID [com.learning]"
    if ([string]::IsNullOrWhiteSpace($groupId)) { $groupId = "com.learning" }

    Write-Host ""
    Write-Host "Project Details:" -ForegroundColor Cyan
    Write-Host "  Name     : $ProjectName"
    Write-Host "  Group    : $groupId"
    Write-Host "  Artifact : $artifactId"
    Write-Host "  Java     : 25 LTS"
    Write-Host ""

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

    $parentPath    = (Get-Location).Path
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

    Write-Host ""
    Write-Host "Configuring pom.xml for Java 25 LTS..." -ForegroundColor Cyan
    $pomPath = Join-Path $projectPath "pom.xml"
    Set-PomToJava25 -pomFilePath $pomPath

    $srcRoot = Join-Path $projectPath "src\main\java"
    Select-Packages -groupId $groupId -srcRoot $srcRoot

    Write-Host ""
    Write-Host "Building project (mvn compile)..." -ForegroundColor Cyan

    & mvn compile

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Maven build failed. Check pom.xml and JDK installation." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "Build completed successfully!" -ForegroundColor Green

    Write-Host ""
    Write-Host "Opening project in IntelliJ..." -ForegroundColor Cyan
    Open-InIntelliJ -folderPath $projectPath

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "   PROJECT READY - Java 25 LTS" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Project Location : $projectPath" -ForegroundColor Cyan
    Write-Host "Java Version     : 25 LTS" -ForegroundColor Cyan
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
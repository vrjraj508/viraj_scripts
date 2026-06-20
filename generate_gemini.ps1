$ErrorActionPreference = "Stop" # This ensures the try/catch block catches everything

$projectName = Read-Host "Enter project name"
$basePackage = "com.example.$projectName"

# Removed hardcoded bootVersion to prevent 400 Bad Request errors in the future
$url = "https://start.spring.io/starter.zip?type=maven-project&language=java&groupId=com.example&artifactId=$projectName&name=$projectName&packageName=$basePackage&dependencies=web%2Cdata-jpa%2Cmysql%2Clombok"

try {
    Write-Host "Downloading project..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile "$projectName.zip"

    Write-Host "Extracting project..." -ForegroundColor Cyan
    Expand-Archive -Path "$projectName.zip" -DestinationPath "$projectName" -Force
    Remove-Item "$projectName.zip"

    # Convert package to path (com.example.demo -> com\example\demo)
    $packagePath = $basePackage.Replace('.', '\')
    $mainPath = "$projectName\src\main\java\$packagePath"

    Write-Host "Creating package structure..." -ForegroundColor Cyan
    $folders = @("controller", "service", "repository", "entity", "dto", "mapper", "exception", "config")
    
    foreach ($folder in $folders) {
        New-Item -ItemType Directory -Path "$mainPath\$folder" -Force | Out-Null
    }

    Write-Host "Adding sample Controller..." -ForegroundColor Cyan
    $controllerContent = @"
package $basePackage.controller;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class TestController {

    @GetMapping("/hello")
    public String hello() {
        return "Hello from $projectName!";
    }
}
"@
    $controllerPath = "$mainPath\controller\TestController.java"
    Set-Content -Path $controllerPath -Value $controllerContent

    Write-Host "Adding application.properties..." -ForegroundColor Cyan
    $propertiesPath = "$projectName\src\main\resources\application.properties"
    
    Add-Content $propertiesPath @"
spring.datasource.url=jdbc:mysql://localhost:3306/rest01basics
spring.datasource.username=root
spring.datasource.password=viraj@123
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
"@

    Write-Host "✅ Project fully ready: $projectName" -ForegroundColor Green
    Write-Host "Opening project in IntelliJ IDEA..." -ForegroundColor Cyan

    # 1. Grab the absolute path of the new project folder
    $fullProjectPath = "$PWD\$projectName"

    # 2. Your IntelliJ path
   $ideaPath = "C:\Program Files\JetBrains\IntelliJ IDEA 2025.3.1.1\bin\idea64.exe"

    # 3. Open IntelliJ using the absolute path wrapped in quotes
    if (Test-Path $ideaPath) {
        Start-Process -FilePath $ideaPath -ArgumentList "`"$fullProjectPath`""
    } else {
        Write-Host "⚠️ Could not find IntelliJ IDEA at $ideaPath. Attempting to open via system PATH instead..." -ForegroundColor Yellow
        Start-Process "idea64.exe" -ArgumentList "`"$fullProjectPath`""
    }

} catch {
    Write-Host "❌ An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    
    # Clean up the zip file if the script failed halfway through
    if (Test-Path "$projectName.zip") { 
        Remove-Item "$projectName.zip" -Force 
    }
}
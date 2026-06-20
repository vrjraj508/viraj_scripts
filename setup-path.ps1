# Run this ONCE as Administrator to register the commands globally
# After this you can use: create-spring-app  and  create-spring-ms  from anywhere

$toolsDir = "C:\build-tools"

# Create the folder if it doesn't exist
if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    Write-Host "Created folder: $toolsDir" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Copy the following files into C:\build-tools\" -ForegroundColor Yellow
Write-Host "   create-spring-app.ps1"
Write-Host "   create-spring-app.cmd"
Write-Host "   create-spring-ms.ps1"
Write-Host "   create-spring-ms.cmd"
Write-Host ""

# Add C:\build-tools to system PATH permanently
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

if ($currentPath -notlike "*$toolsDir*") {
    [System.Environment]::SetEnvironmentVariable(
        "Path",
        "$currentPath;$toolsDir",
        "Machine"
    )
    Write-Host "SUCCESS: C:\build-tools added to system PATH" -ForegroundColor Green
    Write-Host "Restart your terminal and you can run:" -ForegroundColor Green
    Write-Host ""
    Write-Host "   create-spring-app" -ForegroundColor Cyan
    Write-Host "   create-spring-ms" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "C:\build-tools is already in PATH" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can already run:" -ForegroundColor Green
    Write-Host "   create-spring-app" -ForegroundColor Cyan
    Write-Host "   create-spring-ms" -ForegroundColor Cyan
    Write-Host ""
}
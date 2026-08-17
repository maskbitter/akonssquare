# AkonsAutomation Portal Update Script
$source = "E:\AkonsAutomation\Flutter\flutterapps\AkonsSquare"
$destination = "E:\AkonsAutomation\Flutter\flutterapps\AkonsAutomation"

Write-Host ">>> Starting sync from AkonsSquare to AkonsAutomation..." -ForegroundColor Yellow

# 1. Folders to sync
$folders = @("lib\Common", "lib\Admin", "lib\Operator", "lib\Viewer", "lib\Users", "assets", "ios\Runner\Assets.xcassets")

foreach ($folder in $folders) {
    $srcPath = Join-Path $source $folder
    $destPath = Join-Path $destination $folder

    if (Test-Path $srcPath) {
        Write-Host ">>> Syncing $folder..." -ForegroundColor Cyan
        Copy-Item -Path $srcPath -Destination (Split-Path $destPath -Parent) -Recurse -Force
    }
}

# 2. Fix imports and class names in the destination lib folder
Write-Host ">>> Fixing imports and class names in destination..." -ForegroundColor Cyan
$destLib = Join-Path $destination "lib"
if (Test-Path $destLib) {
    $files = Get-ChildItem -Path $destLib -Filter *.dart -Recurse
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw
        $content = $content -replace 'package:akons_square/', 'package:akons_automation/'
        $content = $content -replace 'package:akonssquare/', 'package:akons_automation/'
        $content = $content -replace 'package:akons_automation/main.dart', 'package:akons_automation/Portal/portal_login.dart'
        $content = $content -replace '(?<!Portal)LoginPage', 'PortalLoginPage'

        # Save with UTF8 to ensure cross-platform compatibility
        $content | Set-Content -Path $file.FullName -Encoding utf8
    }
}

Write-Host ">>> AkonsAutomation updated successfully!" -ForegroundColor Green

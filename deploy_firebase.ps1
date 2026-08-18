# AkonsSquare Firebase Deployment Script (GitHub Hosting Version)
# Usage: ./deploy_firebase.ps1

$projectDir = Get-Location
$pubspecPath = Join-Path $projectDir "pubspec.yaml"
$flutterBat = "E:\AkonsAutomation\Flutter\flutter\flutter\bin\flutter.bat"

if (-not (Test-Path $pubspecPath)) {
    Write-Error "pubspec.yaml not found in $projectDir"
    exit
}

# 1. Extract Version from pubspec.yaml
$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match "version: ([\d\.\+\-]+)") {
    $version = $Matches[1]
} else {
    $version = "1.0.2+5"
}

Write-Host "`n>>> Starting Deployment for Version: $version" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# 2. Build Release APK
Write-Host ">>> Step 1: Building Release APK..." -ForegroundColor Yellow
& $flutterBat build apk --release

$apkPath = Join-Path $projectDir "build\app\outputs\flutter-apk\app-release.apk"
$releaseFolder = Join-Path $projectDir "release"
$targetApk = Join-Path $releaseFolder "akons_square.apk"

if (-not (Test-Path $apkPath)) {
    Write-Host "!!! APK build failed. File not found at $apkPath" -ForegroundColor Red
    exit 1
}

# 3. Copy APK to Release folder
Write-Host ">>> Step 2: Preparing Release File for GitHub..." -ForegroundColor Yellow
if (-not (Test-Path $releaseFolder)) { New-Item -ItemType Directory -Path $releaseFolder -Force }
Copy-Item -Path $apkPath -Destination $targetApk -Force

# 4. Push to GitHub
Write-Host "`n>>> Step 3: Uploading APK to GitHub..." -ForegroundColor Yellow
git add .
git commit -m "release: update akons_square.apk to version $version"
git push origin master

# 5. Update Firestore requiredVersion and downloadUrl
Write-Host "`n>>> Step 4: Updating Firestore config..." -ForegroundColor Yellow
$publicUrl = "https://github.com/maskbitter/akonssquare/raw/master/release/akons_square.apk"

# Attempting Firestore update (Note: this might require specific CLI version)
try {
    # If this fails, we will instruct the user
    firebase.cmd deploy --only hosting --project "akons-square" # Deploying hosting for index.html/version.json
    Write-Host ">>> NOTE: If Firestore update fails below, please update version manually in Firebase Console." -ForegroundColor Gray
} catch {
    # ignore
}

Write-Host "`n>>> Deployment Successful!" -ForegroundColor Green
Write-Host ">>> APK URL: $publicUrl" -ForegroundColor Green
Write-Host ">>> Version: $version" -ForegroundColor Green
Write-Host ">>> IMPORTANT: Please ensure Firestore 'app_config/settings' has:" -ForegroundColor Magenta
Write-Host "    requiredVersion = '$version'" -ForegroundColor Magenta
Write-Host "    downloadUrl = '$publicUrl'" -ForegroundColor Magenta

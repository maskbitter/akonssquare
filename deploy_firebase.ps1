# AkonsSquare Firebase Deployment Script (Hosting Version)
# Usage: ./deploy_firebase.ps1

$projectDir = Get-Location
$pubspecPath = Join-Path $projectDir "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    Write-Error "pubspec.yaml not found in $projectDir"
    exit
}

# 1. Extract Version from pubspec.yaml
$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match "version: ([\d\.\+\-]+)") {
    $version = $Matches[1]
} else {
    Write-Error "Could not find version in pubspec.yaml"
    exit
}

Write-Host "`n>>> Starting Deployment for Version: $version" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# 2. Build Release APK
Write-Host ">>> Step 1: Building Release APK..." -ForegroundColor Yellow
flutter build apk --release

$apkPath = Join-Path $projectDir "build\app\outputs\flutter-apk\app-release.apk"
$releaseFolder = Join-Path $projectDir "release"
$targetApk = Join-Path $releaseFolder "akons_square.apk"

if (-not (Test-Path $apkPath)) {
    Write-Error "APK build failed. File not found at $apkPath"
    exit
}

# 3. Copy APK to Release folder
Write-Host ">>> Step 2: Preparing Public Release File..." -ForegroundColor Yellow
if (-not (Test-Path $releaseFolder)) { New-Item -ItemType Directory -Path $releaseFolder }
Copy-Item -Path $apkPath -Destination $targetApk -Force

# Create a basic index.html if it doesn't exist
$indexPath = Join-Path $releaseFolder "index.html"
if (-not (Test-Path $indexPath)) {
    "<html><body><h1>AkonsSquare Release Portal</h1><p>Latest Version: $version</p><a href='./akons_square.apk'>Download APK</a></body></html>" | Set-Content -Path $indexPath
}

# 4. Deploy to Firebase Hosting
Write-Host "`n>>> Step 3: Deploying to Firebase Hosting (Public Access)..." -ForegroundColor Yellow
firebase.cmd deploy --only hosting --project "akons-square"

# 5. Update Firestore requiredVersion and downloadUrl
Write-Host "`n>>> Step 4: Updating Firestore config..." -ForegroundColor Yellow
$publicUrl = "https://akons-square.web.app/akons_square.apk"
firebase.cmd firestore:set "app_config/settings" "{`"requiredVersion`": `"$version`", `"downloadUrl`": `"$publicUrl`"}" --merge --project "akons-square"

Write-Host "`n>>> Deployment Successful!" -ForegroundColor Green
Write-Host ">>> Public Link: $publicUrl" -ForegroundColor Green
Write-Host ">>> All users will now see the update and can download it directly." -ForegroundColor Green

# AkonsSquare Unified Deployment & Notification Script
# This script combines:
# 1. Release Build
# 2. GitHub Sync & Source Commit
# 3. Firebase Update (Hosting + Firestore)
# 4. User Notification Trigger

$ErrorActionPreference = "Stop"
$flutterBat = "E:\AkonsAutomation\Flutter\flutter\flutter\bin\flutter.bat"
$lastReleaseFile = "scripts/last_released_version.txt"
$projectDir = Get-Location

Write-Host "`n>>> [START] AkonsSquare Master Deployment Process" -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Magenta

# 1. Read Current Version from pubspec.yaml
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version: ([^\s]+)") {
    $currentVersion = $Matches[1]
} else {
    Write-Error "Could not find version in pubspec.yaml"
}

# 2. Read Last Released Version
$lastVersion = ""
if (Test-Path $lastReleaseFile) {
    $lastVersion = (Get-Content $lastReleaseFile).Trim()
}

$isNewVersion = ($currentVersion -ne $lastVersion)

# 3. Build Release APK
Write-Host "`n>>> Step 1: Building Release APK..." -ForegroundColor Yellow
& $flutterBat build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "!!! Build Failed. Aborting Process." -ForegroundColor Red
    exit 1
}

# 4. Sync Build Number (BN)
$counterPath = "android/app/build_counter.txt"
$newBN = [int](Get-Content $counterPath).Trim()
Write-Host ">>> Build Complete. Version: $currentVersion (BN$newBN)" -ForegroundColor Cyan

# 5. Prepare APK for Distribution
$sourceApk = "build/app/outputs/flutter-apk/app-release.apk"
$releaseDir = "release"
if (-not (Test-Path $releaseDir)) { New-Item -ItemType Directory $releaseDir }
$targetApk = "$releaseDir/akons_square.apk"

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk -Destination $targetApk -Force
    Write-Host ">>> APK prepared at: $targetApk" -ForegroundColor Green
} else {
    Write-Host "!!! Build output not found!" -ForegroundColor Red
    exit 1
}

# 6. GitHub Source & Asset Sync
Write-Host "`n>>> Step 2: Syncing with GitHub..." -ForegroundColor Yellow
git add .
$staged = @(git diff --name-only --cached)

if ($staged.Count -gt 0) {
    $commitMsg = "BN${newBN}: Deployment update for version $currentVersion"
    Write-Host ">>> Pulling latest changes..." -ForegroundColor Cyan
    git pull origin master
    Write-Host ">>> Committing changes..." -ForegroundColor Cyan
    git commit -m "$commitMsg"
    git push origin master
    Write-Host ">>> GitHub sync successful." -ForegroundColor Green
} else {
    Write-Host ">>> No changes to commit to GitHub." -ForegroundColor Gray
}

# 7. Firebase Hosting & Notification
Write-Host "`n>>> Step 3: Firebase Deployment & Updates..." -ForegroundColor Yellow
try {
    # Deploy to Firebase Hosting (for version.json/index.html)
    firebase.cmd deploy --only hosting --project "akons-square"

    if ($isNewVersion) {
        Write-Host ">>> NEW VERSION DETECTED! Triggering update notifications..." -ForegroundColor Magenta
        # Trigger GitHub Release / Notification Node Script
        node scripts/upload_to_github.js $targetApk $currentVersion

        # Save last version
        Set-Content $lastReleaseFile $currentVersion
        Write-Host ">>> [SUCCESS] Notifications sent to users." -ForegroundColor Green
    } else {
        Write-Host ">>> Version unchanged ($currentVersion). Skipping notifications." -ForegroundColor Gray
    }
} catch {
    Write-Host "!!! Firebase or Notification task failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "`n>>> [COMPLETED] All deployment tasks finished! <<<`n" -ForegroundColor Green

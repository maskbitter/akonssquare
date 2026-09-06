# AkonsSquare Unified Master Build, Sync & Deploy Script
# Optimized for Firebase-only distribution

# Force UTF-8 encoding for Bangla support
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Fix for AndroidLocationsBuildService error (conflicting environment variables)
$env:ANDROID_USER_HOME = $null
$env:ANDROID_PREFS_ROOT = $null
$env:ANDROID_SDK_HOME = $null
$env:JAVA_HOME = "E:\AkonsAutomation\AndroidStudio\jbr"

$ErrorActionPreference = "Stop"
$flutterBat = "E:\AkonsAutomation\Flutter\flutter\flutter\bin\flutter.bat"
$lastReleaseFile = "scripts/last_released_version.txt"
$counterPath = "android/app/build_counter.txt"

Write-Host "`n>>> [START] AkonsSquare Unified Automation Process" -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Magenta

# 1. Read Current Version from build_config.dart
function Get-FullVersion {
    $config = Get-Content "lib/Common/build_config.dart" -Raw
    if ($config -match "const String appVersion = `"([^`"]+)`"") {
        return $Matches[1]
    }
    return ""
}

$currentVersion = Get-FullVersion
if (-not $currentVersion) {
    Write-Error "Could not parse version from lib/Common/build_config.dart."
}

# 2. Get Latest Build Number (BN) from Firebase
Write-Host ">>> Syncing Build Number with Firebase..." -ForegroundColor Cyan
$bnFullOutput = node scripts/get_latest_bn.js 2>$null
$bnOutput = ($bnFullOutput | Out-String).Split("`n") | Where-Object { $_.Trim() -ne "" } | Select-Object -Last 1
if ($bnOutput -match "^\d+$") {
    $oldBN = [int]($bnOutput.Trim())
} else {
    Write-Host "!!! Could not fetch BN from Firebase, checking local counter..." -ForegroundColor Yellow
    $oldBN = [int](Get-Content $counterPath).Trim()
}
$newBN = $oldBN + 1
Set-Content $counterPath $newBN.ToString()

# Update local build_config.dart with new BN
$configContent = Get-Content "lib/Common/build_config.dart" -Raw
$newConfig = $configContent -replace 'const int buildNumber = \d+;', "const int buildNumber = $newBN;"
Set-Content "lib/Common/build_config.dart" $newConfig

Write-Host ">>> Preparing Build: Version $currentVersion (BN$newBN)" -ForegroundColor Cyan

# 3. Build Release APK
Write-Host "`n>>> Step 1: Building Release APK..." -ForegroundColor Yellow
& $flutterBat build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "!!! Build Failed. Aborting." -ForegroundColor Red
    exit 1
}

# 4. Organize and Rename APK
$releaseDir = "release"
if (-not (Test-Path $releaseDir)) { New-Item -ItemType Directory $releaseDir -Force }

$sourceApk = "build/app/outputs/flutter-apk/app-release.apk"
$targetApkName = "AkonsSquare_V$($currentVersion.Replace('+', '_'))_BN${newBN}_release.apk"
$targetApkPath = "$releaseDir/$targetApkName"

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk -Destination $targetApkPath -Force
    Write-Host ">>> Success: APK prepared at: $targetApkPath" -ForegroundColor Green
} else {
    Write-Host "!!! Build output not found!" -ForegroundColor Red
    exit 1
}

# 5. GitHub Source Sync (Backup Only)
Write-Host "`n>>> Step 2: Syncing Source Code with GitHub..." -ForegroundColor Yellow

# Ensure we are on master branch
$currentBranch = git rev-parse --abbrev-ref HEAD
if ($currentBranch -ne "master") {
    Write-Host ">>> Switching to master branch..." -ForegroundColor Cyan
    git checkout master
}

git add .
$stagedFiles = @(git diff --name-only --cached)

if ($stagedFiles.Count -gt 0) {
    # Categorize changes
    $prefixes = @()
    if ($stagedFiles -match "\.dart") { $prefixes += "[CODE]" }
    if ($stagedFiles -match "pubspec\.yaml") { $prefixes += "[DEPS]" }
    if ($stagedFiles -match "build_counter\.txt|build_config\.dart") { $prefixes += "[BUILD]" }
    if ($stagedFiles -match "\.ps1|\.js") { $prefixes += "[SCRIPT]" }

    $prefix = if ($prefixes.Count -gt 0) { ($prefixes | Select-Object -Unique) -join " " } else { "[UPDATE]" }
    $fileList = $stagedFiles | ForEach-Object { [System.IO.Path]::GetFileName($_) }
    $purpose = "Deployment BN${newBN}: " + ($fileList -join ", ")
    if ($purpose.Length -gt 100) { $purpose = $purpose.Substring(0, 97) + "..." }

    $fullMsg = "Build: $newBN | App: V$currentVersion | $prefix $purpose"

    Write-Host ">>> Committing changes..." -ForegroundColor Cyan
    git commit -m "$fullMsg"

    Write-Host ">>> Pulling latest changes (Rebase)..." -ForegroundColor Gray
    git pull origin master --rebase
    if ($LASTEXITCODE -ne 0) {
        Write-Host "!!! Git Pull failed. Attempting to continue..." -ForegroundColor Yellow
    }

    Write-Host ">>> Pushing to GitHub..." -ForegroundColor Gray
    git push origin master
    if ($LASTEXITCODE -ne 0) {
        Write-Host "!!! Git Push failed. Source not synced, but continuing with Firebase..." -ForegroundColor Yellow
    } else {
        Write-Host ">>> GitHub sync successful." -ForegroundColor Green
    }
} else {
    Write-Host ">>> No source changes to sync." -ForegroundColor Yellow
}

# 6. Firebase Deployment (Hosting + Storage for APK)
Write-Host "`n>>> Step 3: Firebase Deployment & Storage Upload..." -ForegroundColor Yellow
try {
    # Firebase Hosting
    Write-Host ">>> Deploying to Firebase Hosting..." -ForegroundColor Cyan
    firebase.cmd deploy --only hosting --project "akons-square"

    # Firebase Storage (The actual update distribution)
    Write-Host ">>> Uploading APK to Firebase Storage (Latest Release)..." -ForegroundColor Cyan
    node scripts/upload_to_firebase_storage.js $targetApkPath $currentVersion

    # Update local last release record
    Set-Content $lastReleaseFile $currentVersion

    Write-Host "`n>>> [SUCCESS] Version $currentVersion (BN$newBN) is now LIVE!" -ForegroundColor Green
    Write-Host ">>> Users will receive the update notification via Firebase metadata." -ForegroundColor Green

    # Open release folder
    explorer.exe (Get-Item $releaseDir).FullName
} catch {
    Write-Host "!!! Firebase Deployment Task failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "`n>>> [COMPLETED] ALL PROCESSES FINISHED! <<<`n" -ForegroundColor Green

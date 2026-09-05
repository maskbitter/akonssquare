param(
    [string]$customMsg
)

# AkonsSquare Master Build & Sync Script
# This script handles:
# 1. Building the App
# 2. Syncing Source Code with GitHub
# 3. Automated App Updates (Releases) if version changed.

$ErrorActionPreference = "Stop"
$flutterBat = "E:\AkonsAutomation\Flutter\flutter\flutter\bin\flutter.bat"
$lastReleaseFile = "scripts/last_released_version.txt"

Write-Host ">>> Starting AkonsSquare Master Sync Process..." -ForegroundColor Magenta

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

$isNewRelease = ($currentVersion -ne $lastVersion)

# 3. Build Release APK for AkonsSquare
Write-Host ">>> Step 1: Building Release APK..." -ForegroundColor Yellow
& $flutterBat build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "!!! AkonsSquare Build Failed. Aborting Sync." -ForegroundColor Red
    exit 1
}

# 4. Get the new Build Number (BN)
$counterPath = "android/app/build_counter.txt"
$newBN = [int](Get-Content $counterPath).Trim()

Write-Host ">>> Build Complete. Version: $currentVersion (BN$newBN)" -ForegroundColor Cyan

# 5. Organize Local Release Files
$sourceApk = "build/app/outputs/flutter-apk/app-release.apk"
# Search for renamed APK if standard one not found
if (-not (Test-Path $sourceApk)) {
   $renamedApk = Get-ChildItem "build/app/outputs/flutter-apk/*.apk" | Where-Object { $_.Name -like "*BN$($newBN)*" } | Select-Object -First 1
   if ($renamedApk) { $sourceApk = $renamedApk.FullName }
}

$releaseDir = "release"
if (-not (Test-Path $releaseDir)) { New-Item -ItemType Directory $releaseDir }
$cleanApk = "$releaseDir/akons_square.apk"

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk -Destination $cleanApk -Force
    Write-Host ">>> Local APK prepared in: $cleanApk" -ForegroundColor Green
} else {
    Write-Host "!!! Build output not found!" -ForegroundColor Red
    exit 1
}

# 6. GitHub Source Code Sync
Write-Host "`n>>> Step 2: Syncing Source Code with GitHub..." -ForegroundColor Yellow
git add .

$stagedFiles = @(git diff --name-only --cached)
if ($stagedFiles.Count -eq 0) {
    Write-Host ">>> No source code changes to commit." -ForegroundColor Yellow
} else {
    if ($customMsg) {
        $fullMsg = "BN${newBN}: $customMsg"
    } else {
        $fileNames = $stagedFiles | ForEach-Object { [System.IO.Path]::GetFileName($_) }
        $fileSummary = $fileNames -join ", "
        if ($fileSummary.Length -gt 120) {
            $fileSummary = $fileSummary.Substring(0, 117) + "..."
        }
        $fullMsg = "BN${newBN}: updated $fileSummary"
    }

    Write-Host ">>> Pulling latest changes..." -ForegroundColor Cyan
    git pull origin master

    Write-Host ">>> Committing with message: $fullMsg" -ForegroundColor Cyan
    git commit -m "$fullMsg"
    git push origin master
    Write-Host ">>> Source code synced successfully." -ForegroundColor Green
}

# 7. Automated App Update / Release (ONLY IF VERSION CHANGED)
if ($isNewRelease) {
    Write-Host "`n>>> Step 3: NEW VERSION DETECTED ($currentVersion)! Creating GitHub Release..." -ForegroundColor Magenta
    try {
        # Call the GitHub Upload script
        node scripts/upload_to_github.js $cleanApk $currentVersion

        # Save this as the new last released version
        Set-Content $lastReleaseFile $currentVersion
        Write-Host ">>> [UPDATE] Users will now receive the update notification." -ForegroundColor Green
    } catch {
        Write-Host "!!! GitHub Release or Firestore update failed." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
} else {
    Write-Host "`n>>> Step 3: No Version Change Detected. Skipping GitHub Release." -ForegroundColor Yellow
    Write-Host "User update notification will NOT be sent." -ForegroundColor Gray
}

Write-Host "`n>>> [MASTER SYNC] ALL PROCESSES COMPLETED! <<<" -ForegroundColor Green

param(
    [string]$customMsg
)

# AkonsSquare Master Build & Sync Script (CLEANED)

# 1. Build Release APK for AkonsSquare
Write-Host ">>> Starting AkonsSquare Flutter Build Release..." -ForegroundColor Yellow
$flutterBat = "E:\AkonsAutomation\Flutter\flutter\flutter\bin\flutter.bat"
& $flutterBat build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "!!! AkonsSquare Build Failed. Aborting Sync." -ForegroundColor Red
    exit 1
}

# 2. Get the new Build Number and Version after build
$counterPath = "android/app/build_counter.txt"
$newBN = [int](Get-Content $counterPath).Trim()

$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version: ([\d\.\+]+)") {
    $appVersion = $Matches[1]
} else {
    $appVersion = "1.0.0+1"
}
$verForName = $appVersion.Replace("+", "_")

Write-Host ">>> Build Complete. New Version: $appVersion (BN$newBN)" -ForegroundColor Cyan

# 3. Rename and Move APK
$sourceApk = "build/app/outputs/flutter-apk/app-release.apk"
$destName = "AkonsSquare_V${verForName}_BN${newBN}_release.apk"
$destPath = "release/$destName"

if (-not (Test-Path "release")) { New-Item -ItemType Directory -Path "release" -Force }

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk -Destination $destPath -Force
    Write-Host ">>> AkonsSquare APK generated and moved to: $destPath" -ForegroundColor Green
} else {
    Write-Host "!!! Build output not found!" -ForegroundColor Red
    exit 1
}

# 4. GitHub Sync for AkonsSquare
Write-Host ">>> Syncing AkonsSquare with GitHub..." -ForegroundColor Yellow
git add .

$stagedFiles = @(git diff --name-only --cached)
if ($stagedFiles.Count -eq 0) {
    Write-Host ">>> No changes to commit for AkonsSquare." -ForegroundColor Yellow
} else {
    if ($customMsg) {
        $fullMsg = "app build no ${newBN}: $customMsg"
    } else {
        $fileNames = $stagedFiles | ForEach-Object { [System.IO.Path]::GetFileName($_) }
        $fileSummary = $fileNames -join ", "
        if ($fileSummary.Length -gt 120) {
            $fileSummary = $fileSummary.Substring(0, 117) + "..."
        }
        $fullMsg = "app build no ${newBN}: updated $fileSummary"
    }

    Write-Host ">>> Pulling latest changes..." -ForegroundColor Cyan
    git pull origin master

    Write-Host ">>> Committing AkonsSquare with message: $fullMsg" -ForegroundColor Cyan
    git commit -m "$fullMsg"
    git push origin master
}

Write-Host "`n>>> [MASTER SYNC] All processes completed successfully!" -ForegroundColor Green

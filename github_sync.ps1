param(
    [string]$customMsg,
    [switch]$SkipPortal
)

# AkonsSquare Master Build & Sync Script

# 0. Sync changes to Portal first
if (-not $SkipPortal) {
    Write-Host ">>> Orchestrating Portal Update..." -ForegroundColor Yellow
    if (Test-Path ".\update_portal.ps1") {
        & ".\update_portal.ps1"
    } else {
        Write-Host "!!! update_portal.ps1 not found. Skipping sync." -ForegroundColor Red
    }
}

# 1. Increment Build Number for AkonsSquare
$counterPath = "android/app/build_counter.txt"
if (-not (Test-Path $counterPath)) {
    "1" | Out-File -FilePath $counterPath -Encoding utf8 -NoNewline
}
$currentBN = [int](Get-Content $counterPath).Trim()
$newBN = $currentBN + 1
$newBN | Out-File -FilePath $counterPath -Encoding utf8 -NoNewline

Write-Host ">>> AkonsSquare Build Number incremented to: $newBN" -ForegroundColor Cyan

# 2. Update build_config.dart
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version: ([\d\.\+]+)") {
    $appVersion = $Matches[1]
} else {
    $appVersion = "1.0.0+1"
}
$verForName = $appVersion.Replace("+", "_")

$configPath = "lib/Common/build_config.dart"
# Fixed quote escaping for Dart string
$configContent = "const int buildNumber = $newBN;`nconst String appVersion = `"$appVersion`";`n"
$configContent | Out-File -FilePath $configPath -Encoding utf8

Write-Host ">>> build_config.dart updated with version $appVersion" -ForegroundColor Cyan

# 3. Build Release APK for AkonsSquare
Write-Host ">>> Starting AkonsSquare Flutter Build Release..." -ForegroundColor Yellow
$flutterBat = "E:\AkonsAutomation\Flutter\flutter\flutter\bin\flutter.bat"
& $flutterBat build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "!!! AkonsSquare Build Failed. Aborting Sync." -ForegroundColor Red
    exit 1
}

# 4. Rename and Move APK
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

# 5. GitHub Sync for AkonsSquare
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

# 6. Trigger AkonsAutomation Build & Sync
if (-not $SkipPortal) {
    Write-Host "`n>>> Starting Master Portal (AkonsAutomation) Workflow..." -ForegroundColor Yellow
    $portalPath = "E:\AkonsAutomation\Flutter\flutterapps\AkonsAutomation"

    if (Test-Path $portalPath) {
        Push-Location $portalPath
        try {
            Write-Host ">>> Running Portal Build Script..." -ForegroundColor Cyan
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\github_sync.ps1" $customMsg
        } catch {
            Write-Host "!!! Portal Build Script failed." -ForegroundColor Red
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "!!! Portal path not found at $portalPath" -ForegroundColor Red
    }
}

Write-Host "`n>>> [MASTER SYNC] All processes completed successfully!" -ForegroundColor Green

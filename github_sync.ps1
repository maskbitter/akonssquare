param(
    [string]$customMsg,
    [switch]$SkipPortal
)

# akonssquare Master Build & Sync Script

# 0. Sync changes to Portal first
if (-not $SkipPortal) {
    Write-Host ">>> Orchestrating Portal Update..." -ForegroundColor Yellow
    if (Test-Path ".\update_portal.ps1") {
        & ".\update_portal.ps1"
    } else {
        Write-Host "!!! update_portal.ps1 not found. Skipping sync." -ForegroundColor Red
    }
}

# 1. Increment Build Number for akonssquare
$counterPath = "android/app/build_counter.txt"
$currentBN = [int](Get-Content $counterPath).Trim()
$newBN = $currentBN + 1
$newBN | Out-File -FilePath $counterPath -Encoding ascii -NoNewline

Write-Host ">>> akonssquare Build Number incremented to: $newBN" -ForegroundColor Cyan

# 2. Update build_config.dart
$pubspec = Get-Content "pubspec.yaml" -Raw
$versionLine = $pubspec -match "version: ([\d\.\+]+)"
$appVersion = $Matches[1]
$verForName = $appVersion.Replace("+", "_")

$configPath = "lib/Common/build_config.dart"
$configContent = "const int buildNumber = $newBN;`nconst String appVersion = `"$appVersion`";"
$configContent | Out-File -FilePath $configPath -Encoding ascii

Write-Host ">>> build_config.dart updated with version $appVersion" -ForegroundColor Cyan

# 3. Build Release APK for akonssquare
Write-Host ">>> Starting akonssquare Flutter Build Release..." -ForegroundColor Yellow
$flutterBat = "E:\AkonsAutomation\Flutter\flutter\flutter\bin\flutter.bat"
& $flutterBat build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "!!! akonssquare Build Failed. Aborting Sync." -ForegroundColor Red
    exit 1
}

# 4. Rename and Move APK
$sourceApk = "build/app/outputs/flutter-apk/app-release.apk"
$destName = "akonssquare_V${verForName}_BN${newBN}_release.apk"
$destPath = "release/$destName"

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk -Destination $destPath -Force
    Write-Host ">>> akonssquare APK generated and moved to: $destPath" -ForegroundColor Green
} else {
    Write-Host "!!! Build output not found!" -ForegroundColor Red
    exit 1
}

# 5. GitHub Sync for akonssquare
Write-Host ">>> Syncing akonssquare with GitHub..." -ForegroundColor Yellow
git add .

$stagedFiles = git diff --name-only --cached
if ($null -eq $stagedFiles -or $stagedFiles.Count -eq 0) {
    Write-Host ">>> No changes to commit for akonssquare." -ForegroundColor Yellow
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

    Write-Host ">>> Committing akonssquare with message: $fullMsg" -ForegroundColor Cyan
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
            powershell.exe -ExecutionPolicy Bypass -File ".\github_sync.ps1" $customMsg
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

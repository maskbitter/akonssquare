# akonssquare Build & Sync Script

# 1. Increment Build Number
$counterPath = "android/app/build_counter.txt"
$currentBN = [int](Get-Content $counterPath).Trim()
$newBN = $currentBN + 1
$newBN | Out-File -FilePath $counterPath -Encoding ascii -NoNewline

Write-Host ">>> Build Number incremented to: $newBN" -ForegroundColor Cyan

# 2. Update build_config.dart
$pubspec = Get-Content "pubspec.yaml" -Raw
$versionLine = $pubspec -match "version: ([\d\.\+]+)"
$appVersion = $Matches[1]
$verForName = $appVersion.Replace("+", "_")

$configPath = "lib/Common/build_config.dart"
$configContent = "const int buildNumber = $newBN;`nconst String appVersion = `"$appVersion`";"
$configContent | Out-File -FilePath $configPath -Encoding ascii

Write-Host ">>> build_config.dart updated with version $appVersion" -ForegroundColor Cyan

# 3. Build Release APK
Write-Host ">>> Starting Flutter Build Release..." -ForegroundColor Yellow
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "!!! Build Failed. Aborting Sync." -ForegroundColor Red
    exit 1
}

# 4. Rename and Move APK
$sourceApk = "build/app/outputs/flutter-apk/app-release.apk"
$destName = "akonssquare_V${verForName}_BN${newBN}_release.apk"
$destPath = "release/$destName"

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk -Destination $destPath -Force
    Write-Host ">>> APK generated and moved to: $destPath" -ForegroundColor Green
} else {
    Write-Host "!!! Build output not found!" -ForegroundColor Red
    exit 1
}

# 5. GitHub Sync
Write-Host ">>> Enter extra commit message details (optional): " -NoNewline
$extraMsg = Read-Host
$fullMsg = "app build no ${newBN}: $extraMsg"

Write-Host ">>> Syncing with GitHub..." -ForegroundColor Yellow
git add .
git commit -m "$fullMsg"
git push

Write-Host ">>> Process Completed Successfully!" -ForegroundColor Green

param(
    [string]$Comment = "Internal updates and version increment"
)

$COUNTER_FILE = "android/app/build_counter.txt"
$CONFIG_FILE = "lib/Common/build_config.dart"

# Step 1: Build App (Gradle handles BN increment)
Write-Host "Building Release APK..." -ForegroundColor Cyan
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Build failed. Aborting Git sync." -ForegroundColor Red
    exit 1
}

# Step 2: Read current BN (incremented by build process)
if (Test-Path $COUNTER_FILE) {
    $newBN = [int](Get-Content $COUNTER_FILE)
} else {
    $newBN = "unknown"
}

# Step 3: Git Sync
Write-Host "Saving changes to GitHub (Version: BN$newBN)..." -ForegroundColor Cyan
git add .
$msg = "app build no ${newBN}: $Comment"
git commit -m "$msg"
git push origin HEAD:master

Write-Host "Sync and Build Complete! Version: BN$newBN" -ForegroundColor Green
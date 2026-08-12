param(
    [string]$Comment = "Auto-sync update"
)

$COUNTER_FILE = "android/app/build_counter.txt"
$CONFIG_FILE = "lib/Common/build_config.dart"

# Step 1: Update Version
if (Test-Path $COUNTER_FILE) {
    $currentBN = [int](Get-Content $COUNTER_FILE)
    $newBN = $currentBN + 1
    $newBN | Out-File -FilePath $COUNTER_FILE -Encoding utf8 -NoNewline

    $configContent = "const int buildNumber = $newBN;"
    $configContent | Out-File -FilePath $CONFIG_FILE -Encoding utf8 -NoNewline

    Write-Host "Build version updated to: $newBN" -ForegroundColor Green
} else {
    Write-Host "Warning: Build counter file not found." -ForegroundColor Yellow
    $newBN = "unknown"
}

# Step 2: Git Sync
Write-Host "Saving changes to GitHub..." -ForegroundColor Cyan
git add .
$msg = "build #${newBN}: $Comment"
git commit -m "$msg"
git push origin HEAD:master

Write-Host "Sync Complete! Version: BN$newBN" -ForegroundColor Green

# Akons Square - Total Release Automation Script
# Steps: Versioning -> Git Commit -> Release Build -> Telegram Delivery

$BOT_TOKEN = "8616599582:AAFkYYhnFX9hGVQ0WMgSvI5BO2aV3HWJaI0" # <--- REPLACE WITH YOUR TOKEN
$CHAT_ID = "-5529302228"
$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"
$COUNTER_FILE = "android/app/build_counter.txt"
$CONFIG_FILE = "lib/Common/build_config.dart"

Write-Host "--- Step 1: Updating Version ---" -ForegroundColor Cyan
if (Test-Path $COUNTER_FILE) {
    $currentBN = [int](Get-Content $COUNTER_FILE)
    $newBN = $currentBN + 1
    $newBN | Out-File -FilePath $COUNTER_FILE -Encoding utf8 -NoNewline

    # Update build_config.dart
    $configContent = "const int buildNumber = $newBN;"
    $configContent | Out-File -FilePath $CONFIG_FILE -Encoding utf8 -NoNewline

    Write-Host "Version updated to BN$newBN" -ForegroundColor Green
} else {
    Write-Error "Counter file not found!"
    exit 1
}

Write-Host "--- Step 2: Git Automation ---" -ForegroundColor Cyan
git add .
git commit -m "build: auto-deployment release build #$newBN"
git push origin HEAD:master

Write-Host "--- Step 3: Starting Release Build ---" -ForegroundColor Cyan
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build Successful! Sending to Telegram..." -ForegroundColor Green

    if (Test-Path $APK_PATH) {
        # Send Notification Message
        $msgUrl = "https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
        $msgBody = @{
            chat_id = $CHAT_ID
            text = "🚀 *New Release Build Ready!*\n\nBuild Number: BN$newBN\nTime: $(Get-Date -Format 'dd-MM-yyyy HH:mm')\nStatus: Pushed to GitHub & Delivered."
            parse_mode = "Markdown"
        }
        Invoke-RestMethod -Uri $msgUrl -Method Post -Body $msgBody | Out-Null

        # Send APK Document
        $docUrl = "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"
        $fileBytes = [System.IO.File]::ReadAllBytes($APK_PATH)
        $fileName = "AkonsSquare_BN$newBN.apk"

        $body = "--$boundary" + $LF
        $body += "Content-Disposition: form-data; name=`"chat_id`"" + $LF + $LF
        $body += $CHAT_ID + $LF
        $body += "--$boundary" + $LF
        $body += "Content-Disposition: form-data; name=`"document`"; filename=`"$fileName`"" + $LF
        $body += "Content-Type: application/vnd.android.package-archive" + $LF + $LF

        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        $footerBytes = [System.Text.Encoding]::UTF8.GetBytes($LF + "--$boundary--" + $LF)

        $fullBody = New-Object byte[] ($headerBytes.Length + $fileBytes.Length + $footerBytes.Length)
        [System.Buffer]::BlockCopy($headerBytes, 0, $fullBody, 0, $headerBytes.Length)
        [System.Buffer]::BlockCopy($fileBytes, 0, $fullBody, $headerBytes.Length, $fileBytes.Length)
        [System.Buffer]::BlockCopy($footerBytes, 0, $fullBody, ($headerBytes.Length + $fileBytes.Length), $footerBytes.Length)

        Invoke-RestMethod -Uri $docUrl -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $fullBody

        Write-Host "All done! APK delivered to Telegram." -ForegroundColor Green
    }
} else {
    Write-Error "Flutter build failed."
}

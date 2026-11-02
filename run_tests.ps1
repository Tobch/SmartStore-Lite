# SmartStore Lite Automated Test Execution Script
# Runs unit, widget, and integration tests via adb & flutter test

$LogFile = "test_execution_log.txt"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

"========================================" | Out-File -FilePath $LogFile -Encoding utf8
"SmartStore Lite Automated Test Run" | Out-File -FilePath $LogFile -Append -Encoding utf8
"Timestamp: $Timestamp" | Out-File -FilePath $LogFile -Append -Encoding utf8
"========================================" | Out-File -FilePath $LogFile -Append -Encoding utf8

Write-Host "Running Flutter Unit & Widget Tests..." -ForegroundColor Cyan

# Execute flutter test and append output to log
flutter test --reporter expanded | Out-File -FilePath $LogFile -Append -Encoding utf8

if ($LASTEXITCODE -eq 0) {
    Write-Host "All tests passed successfully!" -ForegroundColor Green
    "`nRESULT: SUCCESS" | Out-File -FilePath $LogFile -Append -Encoding utf8
} else {
    Write-Host "Some tests failed. Check $LogFile for details." -ForegroundColor Red
    "`nRESULT: FAILED" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

Write-Host "Test execution logs saved to $LogFile" -ForegroundColor Yellow

# Download Real Human Face Photos
# Using thispersondoesnotexist.com API for AI-generated human faces

Write-Host "Downloading real human face photos..." -ForegroundColor Cyan
Write-Host "Using AI-generated faces from thispersondoesnotexist.com" -ForegroundColor Gray
Write-Host "This may take several minutes...`n" -ForegroundColor Gray

$outputDir = ".\test_images\human"

# Download 50 unique human face photos
for ($i = 1; $i -le 50; $i++) {
    $outputPath = Join-Path $outputDir "human_$($i.ToString('D2')).jpg"
    
    # Add a random query parameter to get different images each time
    $randomParam = Get-Random -Minimum 1000 -Maximum 9999
    $url = "https://thispersondoesnotexist.com/?$randomParam"
    
    try {
        # Download the image
        Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
        Write-Host "  ✓ Downloaded human_$($i.ToString('D2')).jpg" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to download human_$($i.ToString('D2')).jpg : $_" -ForegroundColor Red
    }
    
    # Add delay to be respectful to the API
    Start-Sleep -Seconds 2
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
$humanCount = (Get-ChildItem $outputDir -File).Count
Write-Host "Downloaded $humanCount human face photos" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

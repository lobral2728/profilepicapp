# Download Adult Human Face Photos
# Using Pexels API for curated adult portrait photos
# Note: You'll need a free Pexels API key from https://www.pexels.com/api/

param(
    [string]$ApiKey = ""
)

if ([string]::IsNullOrEmpty($ApiKey)) {
    Write-Host "This script requires a Pexels API key." -ForegroundColor Yellow
    Write-Host "Get a free API key at: https://www.pexels.com/api/" -ForegroundColor Cyan
    Write-Host "`nAlternatively, manually download 50 adult face photos and place them in:" -ForegroundColor Yellow
    Write-Host "  .\test_images\human\" -ForegroundColor White
    Write-Host "Name them: human_01.jpg, human_02.jpg, ... human_50.jpg`n" -ForegroundColor White
    
    Write-Host "Or run with API key: .\Download-HumanFaces.ps1 -ApiKey 'YOUR_KEY_HERE'" -ForegroundColor Cyan
    exit
}

Write-Host "Downloading adult portrait photos from Pexels..." -ForegroundColor Cyan
Write-Host "This may take several minutes...`n" -ForegroundColor Gray

$outputDir = ".\test_images\human"
$headers = @{
    "Authorization" = $ApiKey
}

$counter = 1
$page = 1

while ($counter -le 50) {
    try {
        # Search for adult portraits
        $url = "https://api.pexels.com/v1/search?query=adult%20portrait%20face&per_page=15&page=$page&orientation=square"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        
        foreach ($photo in $response.photos) {
            if ($counter -gt 50) { break }
            
            # Download the medium-sized square image (good for profile pictures)
            $imageUrl = $photo.src.medium
            $outputPath = Join-Path $outputDir "human_$($counter.ToString('D2')).jpg"
            
            try {
                Invoke-WebRequest -Uri $imageUrl -OutFile $outputPath -ErrorAction Stop
                Write-Host "  ✓ Downloaded human_$($counter.ToString('D2')).jpg" -ForegroundColor Green
                $counter++
            }
            catch {
                Write-Host "  ✗ Failed to download human_$($counter.ToString('D2')).jpg" -ForegroundColor Red
            }
            
            Start-Sleep -Milliseconds 500
        }
        
        $page++
        Start-Sleep -Seconds 1
    }
    catch {
        Write-Host "Error fetching photos: $_" -ForegroundColor Red
        break
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
$humanCount = (Get-ChildItem $outputDir -File).Count
Write-Host "Downloaded $humanCount adult portrait photos" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

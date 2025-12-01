# Copy Celebrity Faces to Test Images
# Copies 50 celebrity face photos from the downloaded dataset

$sourceDir = "C:\Users\lobra\Downloads\celebrity\Celebrity_Faces_Dataset"
$destDir = ".\test_images\human"

Write-Host "Copying celebrity face photos..." -ForegroundColor Cyan
Write-Host "Source: $sourceDir" -ForegroundColor Gray
Write-Host "Destination: $destDir`n" -ForegroundColor Gray

# Check if source directory exists
if (-not (Test-Path $sourceDir)) {
    Write-Host "Error: Source directory not found: $sourceDir" -ForegroundColor Red
    exit
}

# Get 50 random celebrity images
$allImages = Get-ChildItem $sourceDir -File -Include *.jpg,*.jpeg,*.png -Recurse | Where-Object { $_.Length -gt 0 }
$selectedImages = $allImages | Get-Random -Count 50

if ($selectedImages.Count -lt 50) {
    Write-Host "Warning: Only found $($selectedImages.Count) images in the dataset" -ForegroundColor Yellow
}

# Copy and rename the images
$counter = 1
foreach ($image in $selectedImages) {
    $destPath = Join-Path $destDir "human_$($counter.ToString('D2')).jpg"
    
    try {
        Copy-Item $image.FullName -Destination $destPath -Force
        Write-Host "  ✓ Copied human_$($counter.ToString('D2')).jpg ($($image.Name))" -ForegroundColor Green
        $counter++
    }
    catch {
        Write-Host "  ✗ Failed to copy $($image.Name): $_" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
$humanCount = (Get-ChildItem $destDir -File).Count
Write-Host "Copied $humanCount celebrity face photos" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

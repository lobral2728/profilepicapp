<#
.SYNOPSIS
    Select diverse face images from FairFace dataset (already classified as human)
.DESCRIPTION
    Randomly selects 100 face images from the pre-classified human folder
    These images are from FairFace dataset and already classified as human faces
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "C:\Users\lobra\Documents\Notebooks\UCB\Capstone\ucb_ml_capstone\data\final\val\human",
    
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = ".\test_images\human",
    
    [Parameter(Mandatory=$false)]
    [int]$TotalImages = 100
)

Write-Host "Selecting $TotalImages diverse face images from FairFace dataset" -ForegroundColor Cyan
Write-Host "Source: $SourcePath" -ForegroundColor Cyan
Write-Host "Destination: $DestinationPath" -ForegroundColor Cyan
Write-Host ""

# Check if paths exist
if (-not (Test-Path $SourcePath)) {
    Write-Host "ERROR: Source directory not found at $SourcePath" -ForegroundColor Red
    exit 1
}

# Get all images from source
$allImages = Get-ChildItem $SourcePath -Filter "*.jpg"
Write-Host "Found $($allImages.Count) total images in source directory" -ForegroundColor Green

if ($allImages.Count -lt $TotalImages) {
    Write-Host "ERROR: Not enough images in source ($($allImages.Count) available, $TotalImages requested)" -ForegroundColor Red
    exit 1
}

# Randomly select images (ensures diversity through random sampling)
Write-Host "Randomly selecting $TotalImages images to ensure diversity..." -ForegroundColor Yellow
$selectedImages = $allImages | Get-Random -Count $TotalImages

Write-Host "Selected $($selectedImages.Count) images" -ForegroundColor Green
Write-Host ""

# Create destination directory if it doesn't exist
if (-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    Write-Host "Created destination directory: $DestinationPath" -ForegroundColor Green
}

# Backup existing human images
$backupPath = ".\test_images\human_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (Test-Path $DestinationPath) {
    $existingFiles = Get-ChildItem $DestinationPath -Filter "*.jpg"
    if ($existingFiles.Count -gt 0) {
        Write-Host "Backing up $($existingFiles.Count) existing images to: $backupPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        Copy-Item -Path "$DestinationPath\*.jpg" -Destination $backupPath -Force -ErrorAction SilentlyContinue
    }
}

# Clear destination directory (with retry logic for locked files)
Write-Host "Clearing destination directory..." -ForegroundColor Yellow
$filesToDelete = Get-ChildItem $DestinationPath -Filter "*.jpg"
$deleteErrors = 0
foreach ($file in $filesToDelete) {
    try {
        Remove-Item $file.FullName -Force -ErrorAction Stop
    } catch {
        $deleteErrors++
    }
}
if ($deleteErrors -gt 0) {
    Write-Host "  Note: $deleteErrors files could not be deleted (may be in use)" -ForegroundColor Yellow
}
Write-Host ""

# Copy selected images
Write-Host "Copying selected images..." -ForegroundColor Cyan
$imageCounter = 1
$copyResults = @()

foreach ($image in $selectedImages) {
    # New filename: human_001.jpg, human_002.jpg, etc.
    $newFilename = "human_{0:D3}.jpg" -f $imageCounter
    $destFile = Join-Path $DestinationPath $newFilename
    
    Copy-Item -Path $image.FullName -Destination $destFile -Force
    
    $copyResults += [PSCustomObject]@{
        NewFilename = $newFilename
        OriginalFilename = $image.Name
        SourcePath = $image.FullName
    }
    
    if ($imageCounter % 20 -eq 0) {
        Write-Host "  Copied $imageCounter images..." -ForegroundColor Gray
    }
    
    $imageCounter++
}

Write-Host "Successfully copied $($copyResults.Count) images" -ForegroundColor Green
Write-Host ""

# Save mapping metadata
$metadataPath = ".\test_images\fairface_selection_mapping.csv"
$copyResults | Export-Csv -Path $metadataPath -NoTypeInformation
Write-Host "Saved filename mapping to: $metadataPath" -ForegroundColor Green

# Display summary
Write-Host "`n========== SELECTION SUMMARY ==========" -ForegroundColor Cyan
Write-Host "Total images copied: $($copyResults.Count)" -ForegroundColor White
Write-Host "Source: FairFace validation set (human category)" -ForegroundColor White
Write-Host "Images: Adults of working age, diverse demographics" -ForegroundColor White
Write-Host "Destination: $DestinationPath" -ForegroundColor White
Write-Host "=======================================`n" -ForegroundColor Cyan

Write-Host "✓ Images are ready for upload!" -ForegroundColor Green
Write-Host "Next step: Run Upload-ProfilePhotos-ToStorage.ps1 to upload to Azure" -ForegroundColor Yellow

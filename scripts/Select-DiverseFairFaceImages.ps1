<#
.SYNOPSIS
    Select diverse face images from FairFace dataset for profile pictures
.DESCRIPTION
    Selects 100 diverse adult face images from FairFace validation set
    - Adults of working age (20-59 years)
    - Balanced gender (50 male, 50 female)
    - Diverse ethnicities: White (European), Indian, Black (African), East Asian, Southeast Asian
    - Approximately 20 images per ethnic group, 10 male and 10 female each
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$FairFaceRawPath = "C:\Users\lobra\Documents\Notebooks\UCB\Capstone\ucb_ml_capstone\data\raw\fairface",
    
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = ".\test_images\human",
    
    [Parameter(Mandatory=$false)]
    [int]$TotalImages = 100
)

# Paths
$csvPath = Join-Path $FairFaceRawPath "fairface_label_val.csv"
$imageBasePath = $FairFaceRawPath

Write-Host "Loading FairFace metadata from: $csvPath" -ForegroundColor Cyan
Write-Host "Source images from: $imageBasePath" -ForegroundColor Cyan
Write-Host ""

# Check if paths exist
if (-not (Test-Path $csvPath)) {
    Write-Host "ERROR: CSV file not found at $csvPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $imageBasePath)) {
    Write-Host "ERROR: Image base directory not found at $imageBasePath" -ForegroundColor Red
    exit 1
}

# Load CSV
$fairfaceData = Import-Csv $csvPath

Write-Host "Total images in FairFace validation set: $($fairfaceData.Count)" -ForegroundColor Green

# Filter for adults of working age (20-59)
$workingAgeGroups = @('20-29', '30-39', '40-49', '50-59')
$adults = $fairfaceData | Where-Object { $workingAgeGroups -contains $_.age }

Write-Host "Adults of working age (20-59): $($adults.Count)" -ForegroundColor Green

# Define target distribution
# 100 images: 5 ethnicities × 2 genders × 10 images = 100
$targetRaces = @{
    'White' = 20          # European
    'Indian' = 20         # Indian
    'Black' = 20          # African
    'East Asian' = 20     # East Asian
    'Southeast Asian' = 20 # Southeast Asian
}

$targetPerGender = 10  # 10 male + 10 female per race

# Select images
$selectedImages = @()

foreach ($race in $targetRaces.Keys) {
    $targetCount = $targetRaces[$race]
    
    Write-Host "`nSelecting $targetCount images for $race..." -ForegroundColor Yellow
    
    # Get males for this race
    $males = $adults | Where-Object { $_.race -eq $race -and $_.gender -eq 'Male' }
    $selectedMales = $males | Get-Random -Count $targetPerGender
    
    # Get females for this race
    $females = $adults | Where-Object { $_.race -eq $race -and $_.gender -eq 'Female' }
    $selectedFemales = $females | Get-Random -Count $targetPerGender
    
    Write-Host "  Selected: $($selectedMales.Count) males, $($selectedFemales.Count) females" -ForegroundColor Cyan
    
    $selectedImages += $selectedMales
    $selectedImages += $selectedFemales
}

Write-Host "`nTotal selected: $($selectedImages.Count) images" -ForegroundColor Green
Write-Host ""

# Create destination directory if it doesn't exist
if (-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    Write-Host "Created destination directory: $DestinationPath" -ForegroundColor Green
}

# Backup existing human images
$backupPath = ".\test_images\human_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (Test-Path $DestinationPath) {
    Write-Host "Backing up existing images to: $backupPath" -ForegroundColor Yellow
    Copy-Item -Path $DestinationPath -Destination $backupPath -Recurse -Force
}

# Clear destination directory
Get-ChildItem $DestinationPath -Filter "*.jpg" | Remove-Item -Force
Write-Host "Cleared existing images from destination" -ForegroundColor Yellow
Write-Host ""

# Copy selected images
Write-Host "Copying selected images..." -ForegroundColor Cyan
$imageCounter = 1
$copyResults = @()

foreach ($image in $selectedImages) {
    # Extract filename from path (e.g., "val/1.jpg" -> "val\1.jpg")
    $relativeImagePath = $image.file
    $sourceFile = Join-Path $imageBasePath $relativeImagePath
    
    if (Test-Path $sourceFile) {
        # New filename: human_001.jpg, human_002.jpg, etc.
        $newFilename = "human_{0:D3}.jpg" -f $imageCounter
        $destFile = Join-Path $DestinationPath $newFilename
        
        Copy-Item -Path $sourceFile -Destination $destFile -Force
        
        $copyResults += [PSCustomObject]@{
            NewFilename = $newFilename
            OriginalFile = $image.file
            Age = $image.age
            Gender = $image.gender
            Race = $image.race
        }
        
        if ($imageCounter % 20 -eq 0) {
            Write-Host "  Copied $imageCounter images..." -ForegroundColor Gray
        }
        
        $imageCounter++
    } else {
        Write-Host "  WARNING: Source file not found: $sourceFile" -ForegroundColor Yellow
    }
}

Write-Host "Successfully copied $($copyResults.Count) images" -ForegroundColor Green
Write-Host ""

# Save metadata
$metadataPath = ".\test_images\fairface_selection_metadata.csv"
$copyResults | Export-Csv -Path $metadataPath -NoTypeInformation
Write-Host "Saved metadata to: $metadataPath" -ForegroundColor Green

# Display summary statistics
Write-Host "`n========== SELECTION SUMMARY ==========" -ForegroundColor Cyan
Write-Host "Total images copied: $($copyResults.Count)" -ForegroundColor White

Write-Host "`nBy Race:" -ForegroundColor Yellow
$copyResults | Group-Object Race | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-20} : {1,3} images" -f $_.Name, $_.Count) -ForegroundColor White
}

Write-Host "`nBy Gender:" -ForegroundColor Yellow
$copyResults | Group-Object Gender | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-20} : {1,3} images" -f $_.Name, $_.Count) -ForegroundColor White
}

Write-Host "`nBy Age Group:" -ForegroundColor Yellow
$copyResults | Group-Object Age | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-20} : {1,3} images" -f $_.Name, $_.Count) -ForegroundColor White
}

Write-Host "`nBy Race and Gender:" -ForegroundColor Yellow
$copyResults | Group-Object Race,Gender | Sort-Object Name | ForEach-Object {
    $raceName = $_.Group[0].Race
    $genderName = $_.Group[0].Gender
    Write-Host ("  {0,-20} {1,-10} : {2,3} images" -f $raceName, $genderName, $_.Count) -ForegroundColor White
}

Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "`nDone! Images are ready in: $DestinationPath" -ForegroundColor Green
Write-Host "Next step: Run Upload-ProfilePhotos-ToStorage.ps1 to upload to Azure Blob Storage" -ForegroundColor Yellow

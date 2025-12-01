<#
.SYNOPSIS
    Reorganize profile pictures with correct distribution and add no-picture users
.DESCRIPTION
    - 51 human faces (50 FairFace + 1 for lobral@icloud.com)
    - 25 cartoon avatars (human faces from cartoonset)
    - 25 cat/dog images
    - 20 users with no picture
    Total: 121 users (101 with pictures + 20 without)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$FairFaceSource = "C:\Users\lobra\Documents\Notebooks\UCB\Capstone\ucb_ml_capstone\data\raw\fairface\val",
    
    [Parameter(Mandatory=$false)]
    [string]$CartoonSource = "C:\Users\lobra\Documents\Notebooks\UCB\Capstone\ucb_ml_capstone\data\raw\avatars\cartoonset100k_jpg",
    
    [Parameter(Mandatory=$false)]
    [string]$AnimalSource = ".\test_images\animal",
    
    [Parameter(Mandatory=$false)]
    [string]$DestinationBase = ".\test_images",
    
    [Parameter(Mandatory=$false)]
    [string]$UserCsv = ".\test_images\testusers_only.csv"
)

Write-Host "Profile Picture Reorganization" -ForegroundColor Cyan
Write-Host "==============================`n" -ForegroundColor Cyan

# Load existing users
$users = Import-Csv $UserCsv
Write-Host "Loaded $($users.Count) existing users" -ForegroundColor Green

# Create 20 additional users without pictures
Write-Host "Need to create 20 additional users for no-picture accounts" -ForegroundColor Yellow
Write-Host ""

# Step 1: Select 50 diverse FairFace images
Write-Host "Step 1: Selecting 50 diverse FairFace human images..." -ForegroundColor Cyan
$fairfaceMetadata = Import-Csv "C:\Users\lobra\Documents\Notebooks\UCB\Capstone\ucb_ml_capstone\data\raw\fairface\fairface_label_val.csv"
$workingAgeGroups = @('20-29', '30-39', '40-49', '50-59')
$adults = $fairfaceMetadata | Where-Object { $workingAgeGroups -contains $_.age }

# Select 50 images with diversity
$targetRaces = @('White', 'Indian', 'Black', 'East Asian', 'Southeast Asian')
$selectedHumans = @()

foreach ($race in $targetRaces) {
    $males = $adults | Where-Object { $_.race -eq $race -and $_.gender -eq 'Male' } | Get-Random -Count 5
    $females = $adults | Where-Object { $_.race -eq $race -and $_.gender -eq 'Female' } | Get-Random -Count 5
    $selectedHumans += $males
    $selectedHumans += $females
}

Write-Host "Selected $($selectedHumans.Count) diverse human faces" -ForegroundColor Green

# Backup and clear human directory
$humanDest = Join-Path $DestinationBase "human"
$backupPath = Join-Path $DestinationBase "human_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (Test-Path $humanDest) {
    Write-Host "Backing up existing human images..." -ForegroundColor Yellow
    Copy-Item -Path $humanDest -Destination $backupPath -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem $humanDest -Filter "*.jpg" | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Copy selected human images
Write-Host "Copying human images..." -ForegroundColor Yellow
$humanCounter = 1
foreach ($img in $selectedHumans) {
    # Extract just the filename (e.g., "val/1.jpg" -> "1.jpg")
    $filename = Split-Path $img.file -Leaf
    $sourceFile = Join-Path $FairFaceSource $filename
    if (Test-Path $sourceFile) {
        $destFile = Join-Path $humanDest ("human_{0:D3}.jpg" -f $humanCounter)
        Copy-Item -Path $sourceFile -Destination $destFile -Force
        $humanCounter++
    }
}
Write-Host "Copied $($humanCounter - 1) human images" -ForegroundColor Green
Write-Host ""

# Step 2: Select 25 cartoon avatars
Write-Host "Step 2: Selecting 25 cartoon avatar images..." -ForegroundColor Cyan
$avatarDest = Join-Path $DestinationBase "avatar"

# Clear avatar directory
if (Test-Path $avatarDest) {
    Get-ChildItem $avatarDest -Filter "*.jpg" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem $avatarDest -Filter "*.png" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Get random cartoon images from subdirectories
$cartoonImages = @()
$subdirs = Get-ChildItem $CartoonSource -Directory | Get-Random -Count 5
foreach ($subdir in $subdirs) {
    $images = Get-ChildItem $subdir.FullName -Filter "*.jpg" | Get-Random -Count 5
    $cartoonImages += $images
}

Write-Host "Copying avatar images..." -ForegroundColor Yellow
$avatarCounter = 1
foreach ($img in $cartoonImages) {
    $destFile = Join-Path $avatarDest ("avatar_{0:D2}.jpg" -f $avatarCounter)
    Copy-Item -Path $img.FullName -Destination $destFile -Force
    $avatarCounter++
}
Write-Host "Copied $($avatarCounter - 1) avatar images" -ForegroundColor Green
Write-Host ""

# Step 3: Keep only 25 cat/dog images
Write-Host "Step 3: Limiting animal images to 25..." -ForegroundColor Cyan
$animalDest = Join-Path $DestinationBase "animal"
$existingAnimals = Get-ChildItem $animalDest -Filter "*.jpg"

if ($existingAnimals.Count -gt 25) {
    Write-Host "Removing extra animal images (have $($existingAnimals.Count), need 25)..." -ForegroundColor Yellow
    $toKeep = $existingAnimals | Get-Random -Count 25
    $toRemove = $existingAnimals | Where-Object { $_.Name -notin $toKeep.Name }
    $toRemove | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Rename to sequential numbering
$animals = Get-ChildItem $animalDest -Filter "*.jpg" | Select-Object -First 25
$animalCounter = 1
foreach ($animal in $animals) {
    $newName = "animal_{0:D2}.jpg" -f $animalCounter
    if ($animal.Name -ne $newName) {
        Rename-Item -Path $animal.FullName -NewName $newName -Force -ErrorAction SilentlyContinue
    }
    $animalCounter++
}
Write-Host "Set up $($animalCounter - 1) animal images" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========== IMAGE SUMMARY ==========" -ForegroundColor Cyan
Write-Host "Human faces: $(Get-ChildItem $humanDest -Filter '*.jpg' | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
Write-Host "Avatars: $(Get-ChildItem $avatarDest -Filter '*.jpg' | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
Write-Host "Animals: $(Get-ChildItem $animalDest -Filter '*.jpg' | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
Write-Host "===================================`n" -ForegroundColor Cyan

Write-Host "✓ Images reorganized successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Create 20 additional test users in Entra ID (testuser101-120)" -ForegroundColor White
Write-Host "2. Run the shuffle/upload script with no-picture support" -ForegroundColor White

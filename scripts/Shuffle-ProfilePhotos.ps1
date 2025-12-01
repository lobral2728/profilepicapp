<#
.SYNOPSIS
    Randomly shuffle profile photo assignments
.DESCRIPTION
    Randomly reassigns profile photos to users while maintaining the CSV mapping
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".\test_images\testusers_only.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$ImagePath = ".\test_images",
    
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName = "profilepicsto7826",
    
    [Parameter(Mandatory=$false)]
    [string]$ContainerName = "profile-photos"
)

Write-Host "Profile Photo Shuffle and Upload" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Load users
Write-Host "Loading users from CSV..." -ForegroundColor Yellow
if (-not (Test-Path $CsvPath)) {
    Write-Host "ERROR: CSV file not found at $CsvPath" -ForegroundColor Red
    exit 1
}

$users = Import-Csv $CsvPath
Write-Host "Found $($users.Count) users in CSV" -ForegroundColor Green
Write-Host ""

# Collect all images by category
Write-Host "Collecting images..." -ForegroundColor Yellow
$humanImages = Get-ChildItem (Join-Path $ImagePath "human") -Filter "*.jpg" | Select-Object -ExpandProperty Name
$avatarImages = Get-ChildItem (Join-Path $ImagePath "avatar") -Filter "*.png" | Select-Object -ExpandProperty Name
$animalImages = Get-ChildItem (Join-Path $ImagePath "animal") -Filter "*.jpg" | Select-Object -ExpandProperty Name

Write-Host "Found $($humanImages.Count + $avatarImages.Count + $animalImages.Count) images" -ForegroundColor Green
Write-Host "  - Human: $($humanImages.Count)" -ForegroundColor Cyan
Write-Host "  - Avatar: $($avatarImages.Count)" -ForegroundColor Cyan
Write-Host "  - Animal: $($animalImages.Count)" -ForegroundColor Cyan
Write-Host ""

# Shuffle the images
Write-Host "Shuffling images..." -ForegroundColor Yellow
$shuffledHuman = $humanImages | Get-Random -Count $humanImages.Count
$shuffledAvatar = $avatarImages | Get-Random -Count $avatarImages.Count
$shuffledAnimal = $animalImages | Get-Random -Count $animalImages.Count

# Create all shuffled images array
$allShuffledImages = @()
$shuffledHuman | ForEach-Object { $allShuffledImages += @{File = $_; Category = "human"; Folder = "human"} }
$shuffledAvatar | ForEach-Object { $allShuffledImages += @{File = $_; Category = "avatar"; Folder = "avatar"} }
$shuffledAnimal | ForEach-Object { $allShuffledImages += @{File = $_; Category = "animal"; Folder = "animal"} }

# Shuffle the combined array to randomly distribute categories
$allShuffledImages = $allShuffledImages | Get-Random -Count $allShuffledImages.Count

Write-Host "Images shuffled successfully" -ForegroundColor Green
Write-Host ""

# Check Azure login
Write-Host "Checking Azure login..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "ERROR: Not logged into Azure. Please run 'az login'" -ForegroundColor Red
    exit 1
}
Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host ""

# Setup Azure Storage
Write-Host "Setting up Azure Storage..." -ForegroundColor Yellow
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Cyan
Write-Host "Container: $ContainerName" -ForegroundColor Cyan

# Check if container exists
$containerExists = az storage container exists --account-name $StorageAccountName --name $ContainerName --auth-mode login | ConvertFrom-Json
if ($containerExists.exists) {
    Write-Host "Container already exists" -ForegroundColor Green
} else {
    Write-Host "Creating container..." -ForegroundColor Yellow
    az storage container create --account-name $StorageAccountName --name $ContainerName --public-access blob --auth-mode login | Out-Null
    Write-Host "Container created" -ForegroundColor Green
}
Write-Host ""

# Upload images and create mapping
Write-Host "Uploading shuffled images and creating mapping..." -ForegroundColor Yellow
$uploadResults = @()
$successCount = 0
$failCount = 0

# Add your personal account first
$personalUser = [PSCustomObject]@{
    UserPrincipalName = "lobral_icloud.com#EXT#@lobralicloud.onmicrosoft.com"
    DisplayName = "Allen Long"
}

# Upload personal account photo (keep existing human_050.jpg)
$personalImagePath = Join-Path $ImagePath "human\human_050.jpg"
$personalBlobName = $personalUser.UserPrincipalName -replace '@', '_at_' -replace '#', '_' -replace '\.', '_'
$personalBlobName = "$personalBlobName.jpg"

try {
    az storage blob upload `
        --account-name $StorageAccountName `
        --container-name $ContainerName `
        --name $personalBlobName `
        --file $personalImagePath `
        --overwrite `
        --auth-mode login `
        --output none 2>&1 | Out-Null
    
    $personalBlobUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$personalBlobName"
    
    $uploadResults += [PSCustomObject]@{
        UserPrincipalName = $personalUser.UserPrincipalName
        DisplayName = $personalUser.DisplayName
        ImageFileName = "human_050.jpg"
        BlobName = $personalBlobName
        BlobUrl = $personalBlobUrl
        Category = "human"
        UploadDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    
    Write-Host " ✓ Uploaded personal account photo (human)" -ForegroundColor Green
    $successCount++
} catch {
    Write-Host " ✗ Failed to upload personal account photo" -ForegroundColor Red
    $failCount++
}

# Process each user with shuffled images
for ($i = 0; $i -lt $users.Count -and $i -lt $allShuffledImages.Count; $i++) {
    $user = $users[$i]
    $imageInfo = $allShuffledImages[$i]
    
    # Determine file extension
    $extension = if ($imageInfo.Category -eq "avatar") { ".png" } else { ".jpg" }
    $imagePath = Join-Path $ImagePath "$($imageInfo.Folder)\$($imageInfo.File)"
    
    # Create blob name (sanitize UPN for blob storage)
    $blobName = $user.UserPrincipalName -replace '@', '_at_' -replace '\.', '_'
    $blobName = "$blobName$extension"
    
    try {
        # Upload to Azure Blob Storage with correct content type
        $contentType = if ($extension -eq ".png") { "image/png" } else { "image/jpeg" }
        az storage blob upload `
            --account-name $StorageAccountName `
            --container-name $ContainerName `
            --name $blobName `
            --file $imagePath `
            --content-type $contentType `
            --overwrite `
            --auth-mode login `
            --output none 2>&1 | Out-Null
        
        $blobUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$blobName"
        
        # Store result
        $uploadResults += [PSCustomObject]@{
            UserPrincipalName = $user.UserPrincipalName
            DisplayName = $user.DisplayName
            ImageFileName = $imageInfo.File
            BlobName = $blobName
            BlobUrl = $blobUrl
            Category = $imageInfo.Category
            UploadDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        Write-Host " ✓ Uploaded ($($imageInfo.Category))" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host " ✗ Failed: $($user.UserPrincipalName)" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""

# Save mapping to CSV
Write-Host "Saving mapping to CSV..." -ForegroundColor Yellow
$mappingPath = ".\test_images\profile_upload_map.csv"
$uploadResults | Export-Csv -Path $mappingPath -NoTypeInformation
Write-Host "Mapping saved to: $mappingPath" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Upload Summary" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Successfully uploaded: $successCount images" -ForegroundColor Green
Write-Host "Failed: $failCount images" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Cyan
Write-Host "Container: $ContainerName" -ForegroundColor Cyan
Write-Host "Mapping CSV: $mappingPath" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Display category distribution
Write-Host "Category Distribution:" -ForegroundColor Yellow
$uploadResults | Group-Object Category | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-15} : {1,3} images" -f $_.Name, $_.Count) -ForegroundColor White
}
Write-Host ""

Write-Host "✓ Shuffle complete! Photos randomly reassigned." -ForegroundColor Green
Write-Host "Next step: Deploy the updated CSV to Azure" -ForegroundColor Yellow

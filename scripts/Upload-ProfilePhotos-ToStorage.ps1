# Upload Profile Photos to Azure Blob Storage
# Creates a CSV mapping of userPrincipalName to image filename

param(
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$ContainerName = "profile-photos",
    
    [string]$ImagesRoot = ".\test_images",
    
    [string]$UserCsv = ".\test_images\testusers_only.csv",
    
    [string]$OutputCsv = ".\test_images\profile_upload_map.csv"
)

Write-Host "Profile Photo Upload to Azure Storage" -ForegroundColor Cyan
Write-Host "======================================`n" -ForegroundColor Cyan

# Check if Azure CLI is logged in
Write-Host "Checking Azure login..." -ForegroundColor Yellow
$account = az account show 2>$null
if (-not $account) {
    Write-Host "Not logged in to Azure. Please run: az login" -ForegroundColor Red
    exit 1
}

# Load users from CSV
Write-Host "Loading users from CSV..." -ForegroundColor Yellow
if (-not (Test-Path $UserCsv)) {
    Write-Host "Error: CSV file not found: $UserCsv" -ForegroundColor Red
    exit 1
}

$users = Import-Csv $UserCsv
Write-Host "Found $($users.Count) users in CSV`n" -ForegroundColor Green

# Get all images from subdirectories
Write-Host "Collecting images..." -ForegroundColor Yellow
$allImages = @()

$subdirs = @('human', 'avatar', 'animal')
foreach ($subdir in $subdirs) {
    $dirPath = Join-Path $ImagesRoot $subdir
    if (Test-Path $dirPath) {
        $images = Get-ChildItem $dirPath -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|png)$' }
        foreach ($img in $images) {
            $allImages += [PSCustomObject]@{
                FullPath = $img.FullName
                FileName = $img.Name
                Category = $subdir
            }
        }
    }
}

Write-Host "Found $($allImages.Count) images" -ForegroundColor Green
Write-Host "  - Human: $($allImages.Where({$_.Category -eq 'human'}).Count)" -ForegroundColor Gray
Write-Host "  - Avatar: $($allImages.Where({$_.Category -eq 'avatar'}).Count)" -ForegroundColor Gray
Write-Host "  - Animal: $($allImages.Where({$_.Category -eq 'animal'}).Count)`n" -ForegroundColor Gray

# Check if we have enough images
if ($allImages.Count -lt $users.Count) {
    Write-Host "Warning: Only $($allImages.Count) images for $($users.Count) users" -ForegroundColor Yellow
}

# Create storage container if it doesn't exist
Write-Host "Setting up Azure Storage..." -ForegroundColor Yellow
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Gray
Write-Host "Container: $ContainerName" -ForegroundColor Gray

# Check if container exists
$containerExists = az storage container exists `
    --account-name $StorageAccountName `
    --name $ContainerName `
    --auth-mode login `
    --query "exists" -o tsv 2>$null

if ($containerExists -ne "true") {
    Write-Host "Creating container..." -ForegroundColor Yellow
    az storage container create `
        --account-name $StorageAccountName `
        --name $ContainerName `
        --public-access blob `
        --auth-mode login | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to create container" -ForegroundColor Red
        exit 1
    }
    Write-Host "Container created successfully" -ForegroundColor Green
} else {
    Write-Host "Container already exists" -ForegroundColor Green
}

# Create mapping and upload images
Write-Host "`nUploading images and creating mapping..." -ForegroundColor Cyan
$mapping = @()
$successCount = 0
$failCount = 0

for ($i = 0; $i -lt [Math]::Min($users.Count, $allImages.Count); $i++) {
    $user = $users[$i]
    $image = $allImages[$i]
    $upn = $user.userPrincipalName
    
    # Create a safe blob name (replace @ and special chars)
    $safeName = $upn -replace '@', '_at_' -replace '\.', '_'
    $extension = [System.IO.Path]::GetExtension($image.FileName)
    $blobName = "$safeName$extension"
    
    Write-Host "[$($i+1)/$($users.Count)] $upn..." -NoNewline
    
    try {
        # Upload to blob storage with correct content type
        $contentType = if ($extension -eq ".png") { "image/png" } else { "image/jpeg" }
        az storage blob upload `
            --account-name $StorageAccountName `
            --container-name $ContainerName `
            --name $blobName `
            --file $image.FullPath `
            --content-type $contentType `
            --auth-mode login `
            --overwrite `
            --only-show-errors | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            # Get blob URL
            $blobUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$blobName"
            
            $mapping += [PSCustomObject]@{
                UserPrincipalName = $upn
                DisplayName = $user.displayName
                ImageFileName = $image.FileName
                BlobName = $blobName
                BlobUrl = $blobUrl
                Category = $image.Category
                UploadDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            
            Write-Host " ✓ Uploaded ($($image.Category))" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host " ✗ Failed" -ForegroundColor Red
            $failCount++
        }
    }
    catch {
        Write-Host " ✗ Error: $_" -ForegroundColor Red
        $failCount++
    }
    
    # Small delay to avoid throttling
    Start-Sleep -Milliseconds 100
}

# Export mapping to CSV
Write-Host "`nSaving mapping to CSV..." -ForegroundColor Yellow
$mapping | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Mapping saved to: $OutputCsv" -ForegroundColor Green

# Summary
Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "Upload Summary" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Successfully uploaded: $successCount images" -ForegroundColor Green
Write-Host "Failed: $failCount images" -ForegroundColor $(if($failCount -gt 0){"Red"}else{"Green"})
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Gray
Write-Host "Container: $ContainerName" -ForegroundColor Gray
Write-Host "Mapping CSV: $OutputCsv" -ForegroundColor Gray
Write-Host "======================================`n" -ForegroundColor Cyan

if ($successCount -gt 0) {
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Update your Flask app to read from the CSV and serve images from blob storage" -ForegroundColor White
    Write-Host "2. Test accessing images at: https://$StorageAccountName.blob.core.windows.net/$ContainerName/{blobName}" -ForegroundColor White
}

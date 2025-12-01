# Upload Local Profile Photos to Entra ID Users
# Uploads profile pictures from local test_images directory to the 100 test users

# Configuration
$TenantDomain = "lobralicloud.onmicrosoft.com"
$ImagesBaseDir = ".\test_images"

# Ensure we're logged in to Azure
Write-Host "Checking Azure login..." -ForegroundColor Cyan
$account = az account show 2>$null
if (-not $account) {
    Write-Host "Not logged in. Please run: az login" -ForegroundColor Red
    exit
}

# Function to upload profile picture
function Set-UserProfilePicture {
    param(
        [string]$UserPrincipalName,
        [string]$ImagePath
    )
    
    # Verify file exists and has content
    if (-not (Test-Path $ImagePath)) {
        Write-Host " (file not found)" -ForegroundColor DarkYellow -NoNewline
        return $false
    }
    
    $fileSize = (Get-Item $ImagePath).Length
    if ($fileSize -eq 0) {
        Write-Host " (empty file)" -ForegroundColor DarkYellow -NoNewline
        return $false
    }
    
    if ($fileSize -gt 4MB) {
        Write-Host " (file too large: $([math]::Round($fileSize/1MB, 2))MB)" -ForegroundColor DarkYellow -NoNewline
        return $false
    }
    
    try {
        $result = az rest --method PUT `
            --url "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/photo/`$value" `
            --headers "Content-Type=image/jpeg" `
            --body "@$ImagePath" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

# Build upload list
Write-Host "`nPreparing upload list..." -ForegroundColor Cyan

$uploadList = @()

# Get human images
$humanImages = Get-ChildItem (Join-Path $ImagesBaseDir "human") -File | Sort-Object Name
foreach ($image in $humanImages) {
    $userNum = $uploadList.Count + 1
    if ($userNum -le 100) {
        $uploadList += @{
            UPN = "testuser$('{0:D3}' -f $userNum)@$TenantDomain"
            ImagePath = $image.FullName
            Type = "human"
        }
    }
}

# Get avatar images
$avatarImages = Get-ChildItem (Join-Path $ImagesBaseDir "avatar") -File | Sort-Object Name
foreach ($image in $avatarImages) {
    $userNum = $uploadList.Count + 1
    if ($userNum -le 100) {
        $uploadList += @{
            UPN = "testuser$('{0:D3}' -f $userNum)@$TenantDomain"
            ImagePath = $image.FullName
            Type = "avatar"
        }
    }
}

# Get animal images
$animalImages = Get-ChildItem (Join-Path $ImagesBaseDir "animal") -File | Sort-Object Name
foreach ($image in $animalImages) {
    $userNum = $uploadList.Count + 1
    if ($userNum -le 100) {
        $uploadList += @{
            UPN = "testuser$('{0:D3}' -f $userNum)@$TenantDomain"
            ImagePath = $image.FullName
            Type = "animal"
        }
    }
}

Write-Host "Prepared upload list for $($uploadList.Count) users" -ForegroundColor Green
Write-Host "  - $($uploadList.Where({$_.Type -eq 'human'}).Count) with human photos" -ForegroundColor Gray
Write-Host "  - $($uploadList.Where({$_.Type -eq 'avatar'}).Count) with avatar images" -ForegroundColor Gray
Write-Host "  - $($uploadList.Where({$_.Type -eq 'animal'}).Count) with animal images" -ForegroundColor Gray

# Prompt for confirmation
Write-Host "`nThis will upload profile photos for $($uploadList.Count) users in tenant: $TenantDomain" -ForegroundColor Yellow
$confirmation = Read-Host "Do you want to proceed? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit
}

# Upload photos
$successCount = 0
$failCount = 0

Write-Host "`nUploading profile photos..." -ForegroundColor Cyan
Write-Host "This may take several minutes...`n" -ForegroundColor Gray

foreach ($item in $uploadList) {
    $upn = $item.UPN
    $imagePath = $item.ImagePath
    $type = $item.Type
    
    Write-Host "Uploading photo for: $upn [$type]..." -NoNewline
    
    if (Set-UserProfilePicture -UserPrincipalName $upn -ImagePath $imagePath) {
        Write-Host " ✓ Success" -ForegroundColor Green
        $successCount++
    }
    else {
        Write-Host " ✗ Failed" -ForegroundColor Yellow
        $failCount++
    }
    
    # Small delay to avoid rate limiting
    Start-Sleep -Milliseconds 500
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Photo Upload Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Successfully uploaded: $successCount photos" -ForegroundColor Green
Write-Host "Failed: $failCount photos" -ForegroundColor $(if($failCount -gt 0){"Red"}else{"Green"})
Write-Host "========================================" -ForegroundColor Cyan

if ($successCount -gt 0) {
    Write-Host "`nYou can now test the app at: https://profilepicapp-c2p7wl.azurewebsites.net" -ForegroundColor Cyan
    Write-Host "Sign in with any test user (testuser001@$TenantDomain through testuser100@$TenantDomain)" -ForegroundColor Gray
    Write-Host "Password: TestPassword123!" -ForegroundColor Gray
}

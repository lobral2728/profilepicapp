param(
    [string]$StorageAccountName = "profilepicsto7826",
    [string]$ContainerName = "profile-photos",
    [string]$TenantDomain = "lobralicloud.onmicrosoft.com",
    [string]$CsvPath = ".\test_images\profile_upload_map.csv"
)

# Get all users except the personal account
Write-Host "Fetching test users from Entra ID..."
$users = az ad user list --query "[?starts_with(userPrincipalName, 'testuser')].{userPrincipalName:userPrincipalName, displayName:displayName}" --output json | ConvertFrom-Json | Sort-Object userPrincipalName

# Add personal account
$personalAccount = az ad user show --id "lobral_icloud.com#EXT#@lobralicloud.onmicrosoft.com" --query "{userPrincipalName:userPrincipalName, displayName:displayName}" --output json | ConvertFrom-Json
$allUsers = @($personalAccount) + $users

Write-Host "Total users: $($allUsers.Count)"

# Get images
Write-Host "`nGetting images from directories..."
$humanImages = Get-ChildItem ".\test_images\human" -Filter "*.jpg" | Select-Object -First 50 | ForEach-Object { @{Path=$_.FullName; Category="human"} }
$avatarImages = Get-ChildItem ".\test_images\avatar" -Filter "*.jpg" | ForEach-Object { @{Path=$_.FullName; Category="avatar"} }
$animalImages = Get-ChildItem ".\test_images\animal" -Filter "*.jpg" | ForEach-Object { @{Path=$_.FullName; Category="animal"} }

Write-Host "Human images: $($humanImages.Count)"
Write-Host "Avatar images: $($avatarImages.Count)"
Write-Host "Animal images: $($animalImages.Count)"

# Combine all images (51 human for personal + 50 test users, 25 avatar, 25 animal = 101 total)
$allImages = $humanImages + $avatarImages + $animalImages
Write-Host "Total images: $($allImages.Count)"

# Shuffle images for random assignment
$shuffledImages = $allImages | Get-Random -Count $allImages.Count

# Create mapping array
$mappings = @()
$imageIndex = 0

# First, assign image to personal account (ALWAYS human category)
$personalImage = $humanImages[0]  # Use first human image for personal account
$personalBlobName = "profile_$(Split-Path $personalImage.Path -Leaf)"
$personalUser = $allUsers[0]

Write-Host "`nAssigning $personalBlobName to personal account: $($personalUser.userPrincipalName)"

# Upload personal account image
$contentType = "image/jpeg"
az storage blob upload `
    --account-name $StorageAccountName `
    --container-name $ContainerName `
    --name $personalBlobName `
    --file $personalImage.Path `
    --overwrite `
    --content-type $contentType | Out-Null

$personalBlobUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$personalBlobName"

$mappings += [PSCustomObject]@{
    UserPrincipalName = $personalUser.userPrincipalName
    DisplayName = $personalUser.displayName
    ImageFileName = Split-Path $personalImage.Path -Leaf
    BlobName = $personalBlobName
    BlobUrl = $personalBlobUrl
    Category = "human"
    UploadDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

# Now assign remaining images to test users (001-100)
$testUsersWithPhotos = $allUsers | Select-Object -Skip 1 -First 100
$remainingImages = $shuffledImages | Select-Object -Skip 1 -First 100  # Skip the one we used for personal

for ($i = 0; $i -lt $testUsersWithPhotos.Count; $i++) {
    $user = $testUsersWithPhotos[$i]
    $image = $remainingImages[$i]
    
    $blobName = "profile_$(Split-Path $image.Path -Leaf)"
    
    Write-Host "Uploading $($i+1)/100: $blobName for $($user.userPrincipalName) (Category: $($image.Category))"
    
    # Determine content type
    $contentType = "image/jpeg"
    if ($image.Path -like "*.png") {
        $contentType = "image/png"
    }
    
    # Upload to Azure Blob Storage
    az storage blob upload `
        --account-name $StorageAccountName `
        --container-name $ContainerName `
        --name $blobName `
        --file $image.Path `
        --overwrite `
        --content-type $contentType | Out-Null
    
    $blobUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$blobName"
    
    $mappings += [PSCustomObject]@{
        UserPrincipalName = $user.userPrincipalName
        DisplayName = $user.displayName
        ImageFileName = Split-Path $image.Path -Leaf
        BlobName = $blobName
        BlobUrl = $blobUrl
        Category = $image.Category
        UploadDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

# Add 20 users with no picture (testuser101-120)
$noPictureUsers = $allUsers | Select-Object -Skip 101 -First 20

foreach ($user in $noPictureUsers) {
    Write-Host "Adding no-picture entry for $($user.userPrincipalName)"
    
    $mappings += [PSCustomObject]@{
        UserPrincipalName = $user.userPrincipalName
        DisplayName = $user.displayName
        ImageFileName = ""
        BlobName = ""
        BlobUrl = ""
        Category = "no-picture"
        UploadDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

# Export to CSV
$mappings | Export-Csv -Path $CsvPath -NoTypeInformation -Force

Write-Host "`nUpload complete!"
Write-Host "Total mappings: $($mappings.Count)"
Write-Host "`nCategory distribution:"
$mappings | Group-Object Category | Select-Object Name, Count | Format-Table
Write-Host "CSV saved to: $CsvPath"

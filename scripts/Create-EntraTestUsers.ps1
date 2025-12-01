# Bulk Create Entra ID Users with Profile Pictures
# This script creates 100 test users in Azure AD with profile pictures

# Configuration
$TenantDomain = "lobralicloud.onmicrosoft.com"
$Password = "TestPassword123!"  # Change this to a secure password if desired
$TempImageFolder = ".\temp_profile_pics"

# Ensure we're logged in to Azure
Write-Host "Checking Azure login..." -ForegroundColor Cyan
$account = az account show 2>$null
if (-not $account) {
    Write-Host "Not logged in. Please run: az login" -ForegroundColor Red
    exit
}

# Check if Microsoft Graph is available
Write-Host "Checking Microsoft Graph permissions..." -ForegroundColor Cyan
$graphCheck = az rest --method GET --url "https://graph.microsoft.com/v1.0/me" 2>$null
if (-not $graphCheck) {
    Write-Host "Microsoft Graph access not available. Logging in with required scopes..." -ForegroundColor Yellow
    az login --scope https://graph.microsoft.com/.default
}

# Create temp folder for images
if (-not (Test-Path $TempImageFolder)) {
    New-Item -ItemType Directory -Path $TempImageFolder | Out-Null
}

# List of realistic first and last names
$FirstNames = @(
    "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
    "William", "Barbara", "David", "Elizabeth", "Richard", "Susan", "Joseph", "Jessica",
    "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa",
    "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra", "Donald", "Ashley",
    "Steven", "Kimberly", "Paul", "Emily", "Andrew", "Donna", "Joshua", "Michelle",
    "Kenneth", "Dorothy", "Kevin", "Carol", "Brian", "Amanda", "George", "Melissa",
    "Edward", "Deborah", "Ronald", "Stephanie", "Timothy", "Rebecca", "Jason", "Sharon",
    "Jeffrey", "Laura", "Ryan", "Cynthia", "Jacob", "Kathleen", "Gary", "Amy",
    "Nicholas", "Shirley", "Eric", "Angela", "Jonathan", "Helen", "Stephen", "Anna"
)

$LastNames = @(
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas",
    "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
    "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young",
    "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores",
    "Green", "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
    "Carter", "Roberts", "Gomez", "Phillips", "Evans", "Turner", "Diaz", "Parker",
    "Cruz", "Edwards", "Collins", "Reyes", "Stewart", "Morris", "Morales", "Murphy"
)

# Function to download image from URL
function Download-ProfilePicture {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Failed to download image from $Url : $_" -ForegroundColor Red
        return $false
    }
}

# Function to create user via Microsoft Graph API
function Create-EntraUser {
    param(
        [string]$DisplayName,
        [string]$UserPrincipalName,
        [string]$Password
    )
    
    $body = @{
        accountEnabled = $true
        displayName = $DisplayName
        mailNickname = $UserPrincipalName.Split('@')[0]
        userPrincipalName = $UserPrincipalName
        passwordProfile = @{
            forceChangePasswordNextSignIn = $false
            password = $Password
        }
    } | ConvertTo-Json -Compress
    
    # Write body to temp file to avoid issues with special characters
    $tempBodyFile = [System.IO.Path]::GetTempFileName()
    $body | Out-File -FilePath $tempBodyFile -Encoding UTF8 -NoNewline
    
    try {
        $result = az rest --method POST `
            --url "https://graph.microsoft.com/v1.0/users" `
            --headers "Content-Type=application/json" `
            --body "@$tempBodyFile" 2>&1
        
        # Clean up temp file
        Remove-Item $tempBodyFile -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0) {
            return ($result | ConvertFrom-Json)
        }
        else {
            # Check if it's a conflict (user already exists)
            if ($result -match "ObjectConflict|already exists") {
                return "ALREADY_EXISTS"
            }
            Write-Host "Error: $result" -ForegroundColor Red
            return $null
        }
    }
    catch {
        Write-Host "Failed to create user $UserPrincipalName : $_" -ForegroundColor Red
        Remove-Item $tempBodyFile -ErrorAction SilentlyContinue
        return $null
    }
}

# Function to upload profile picture
function Set-UserProfilePicture {
    param(
        [string]$UserId,
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
            --url "https://graph.microsoft.com/v1.0/users/$UserId/photo/`$value" `
            --headers "Content-Type=image/jpeg" `
            --body "@$ImagePath" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        else {
            # Uncomment for debugging: Write-Host " (upload error: $result)" -ForegroundColor DarkYellow -NoNewline
            return $false
        }
    }
    catch {
        return $false
    }
}

# Generate user list with picture types
$users = @()
$userCounter = 1

Write-Host "`nGenerating user list..." -ForegroundColor Cyan

# 50 users with avatar human faces (from avatars.dicebear.com - various styles)
for ($i = 1; $i -le 50; $i++) {
    $firstName = $FirstNames | Get-Random
    $lastName = $LastNames | Get-Random
    $displayName = "$firstName $lastName"
    $upn = "testuser$('{0:D3}' -f $userCounter)@$TenantDomain"
    
    # Alternate between different avatar styles for variety
    $styles = @('avataaars', 'bottts', 'personas', 'lorelei', 'micah', 'big-ears')
    $style = $styles[$i % $styles.Count]
    
    $users += @{
        DisplayName = $displayName
        UPN = $upn
        PictureType = "human"
        PictureUrl = "https://api.dicebear.com/7.x/$style/jpg?seed=$displayName-$i"
    }
    $userCounter++
}

# 25 users with avatar human faces (from avatars.dicebear.com)
for ($i = 1; $i -le 25; $i++) {
    $firstName = $FirstNames | Get-Random
    $lastName = $LastNames | Get-Random
    $displayName = "$firstName $lastName"
    $upn = "testuser$('{0:D3}' -f $userCounter)@$TenantDomain"
    
    $users += @{
        DisplayName = $displayName
        UPN = $upn
        PictureType = "avatar"
        PictureUrl = "https://api.dicebear.com/7.x/avataaars/jpg?seed=$displayName"
    }
    $userCounter++
}

# 13 users with cat pictures
for ($i = 1; $i -le 13; $i++) {
    $firstName = $FirstNames | Get-Random
    $lastName = $LastNames | Get-Random
    $displayName = "$firstName $lastName"
    $upn = "testuser$('{0:D3}' -f $userCounter)@$TenantDomain"
    
    $users += @{
        DisplayName = $displayName
        UPN = $upn
        PictureType = "cat"
        PictureUrl = "https://cataas.com/cat?width=200&height=200&t=$(Get-Random)"
    }
    $userCounter++
}

# 12 users with dog pictures (from dog.ceo API)
for ($i = 1; $i -le 12; $i++) {
    $firstName = $FirstNames | Get-Random
    $lastName = $LastNames | Get-Random
    $displayName = "$firstName $lastName"
    $upn = "testuser$('{0:D3}' -f $userCounter)@$TenantDomain"
    
    # Get random dog image URL
    $dogResponse = Invoke-RestMethod -Uri "https://dog.ceo/api/breeds/image/random"
    $dogUrl = $dogResponse.message
    
    $users += @{
        DisplayName = $displayName
        UPN = $upn
        PictureType = "dog"
        PictureUrl = $dogUrl
    }
    $userCounter++
}

Write-Host "Generated $($users.Count) users" -ForegroundColor Green
Write-Host "  - $($users.Where({$_.PictureType -eq 'human'}).Count) with human photos" -ForegroundColor Gray
Write-Host "  - $($users.Where({$_.PictureType -eq 'avatar'}).Count) with avatar faces" -ForegroundColor Gray
Write-Host "  - $($users.Where({$_.PictureType -eq 'cat'}).Count) with cat pictures" -ForegroundColor Gray
Write-Host "  - $($users.Where({$_.PictureType -eq 'dog'}).Count) with dog pictures" -ForegroundColor Gray

# Prompt for confirmation
Write-Host "`nThis will create 100 users in tenant domain: $TenantDomain" -ForegroundColor Yellow
$confirmation = Read-Host "Do you want to proceed? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit
}

# Create users
$successCount = 0
$failCount = 0

Write-Host "`nStarting user creation..." -ForegroundColor Cyan
Write-Host "This may take several minutes...`n" -ForegroundColor Gray

foreach ($user in $users) {
    $displayName = $user.DisplayName
    $upn = $user.UPN
    $pictureType = $user.PictureType
    $pictureUrl = $user.PictureUrl
    
    Write-Host "Creating user: $displayName ($upn) [$pictureType]..." -NoNewline
    
    # Create the user
    $createdUser = Create-EntraUser -DisplayName $displayName -UserPrincipalName $upn -Password $Password
    
    if ($createdUser -eq "ALREADY_EXISTS") {
        Write-Host " ⊙ Already exists (skipped)" -ForegroundColor Cyan
        $successCount++  # Count as success since user exists
    }
    elseif ($createdUser) {
        Write-Host " ✓ Created" -ForegroundColor Green -NoNewline
        
        # Download and upload profile picture
        $imagePath = Join-Path $TempImageFolder "$($createdUser.id).jpg"
        
        if (Download-ProfilePicture -Url $pictureUrl -OutputPath $imagePath) {
            Start-Sleep -Seconds 2  # Longer delay to ensure user is fully provisioned in Azure AD
            
            if (Set-UserProfilePicture -UserId $createdUser.id -ImagePath $imagePath) {
                Write-Host " ✓ Photo uploaded" -ForegroundColor Green
                $successCount++
            }
            else {
                Write-Host " ✗ Photo upload failed" -ForegroundColor Yellow
                $successCount++  # Still count as success since user was created
            }
            
            # Clean up temp image
            Remove-Item $imagePath -ErrorAction SilentlyContinue
        }
        else {
            Write-Host " ✗ Photo download failed" -ForegroundColor Yellow
            $successCount++  # Still count as success since user was created
        }
    }
    else {
        Write-Host " ✗ Failed" -ForegroundColor Red
        $failCount++
    }
    
    # Small delay to avoid rate limiting
    Start-Sleep -Milliseconds 200
}

# Cleanup temp folder
Remove-Item $TempImageFolder -Recurse -Force -ErrorAction SilentlyContinue

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "User Creation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Successfully created: $successCount users" -ForegroundColor Green
Write-Host "Failed: $failCount users" -ForegroundColor $(if($failCount -gt 0){"Red"}else{"Green"})
Write-Host "Password for all users: $Password" -ForegroundColor Yellow
Write-Host "`nUsers can sign in at: https://portal.azure.com" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

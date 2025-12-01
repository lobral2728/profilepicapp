# Entra ID Test User Scripts

Scripts for managing 100 test users in Azure AD (Microsoft Entra ID) for the Profile Picture App.

## Current Status

### ✅ Successfully Completed
- **100 test users created** (testuser001@lobralicloud.onmicrosoft.com through testuser100)
- **Password**: TestPassword123!
- **100 profile images** downloaded and organized in `test_images/`:
  - **50 celebrity face photos** (from Kaggle dataset)
  - **25 cartoon avatars** (from DiceBear API)
  - **25 animal/nature photos** (from Lorem Picsum)

### ❌ Known Issue
**Bulk photo upload via Microsoft Graph API fails** with "InvalidImage" errors. This is a Microsoft Graph API limitation affecting programmatic bulk uploads.

## What the Scripts Do

- **Create-EntraTestUsers.ps1** - Creates 100 test users (✓ Working)
- **Download-SampleImages.ps1** - Downloads avatars and animal images (✓ Working)
- **Copy-CelebrityFaces.ps1** - Copies celebrity faces from Kaggle dataset (✓ Working)
- **Upload-ProfilePhotos.ps1** - Attempts bulk photo upload (✗ Graph API issue)

## Alternative: Manual Photo Upload

Since automated bulk upload fails, manually upload photos for testing:

### Via Azure Portal (Easiest)
1. Go to https://portal.azure.com → **Entra ID** → **Users**
2. Select a test user (e.g., testuser001)
3. Click **Edit** → Click profile picture placeholder
4. Upload from `test_images/human/human_01.jpg`
5. Repeat for 5-10 users to test variety

### Via PowerShell (Microsoft.Graph Module)
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Upload for one user
Set-MgUserPhotoContent -UserId "testuser001@lobralicloud.onmicrosoft.com" -InFile ".\test_images\human\human_01.jpg"
```

## Testing the Application

**Your app is working!** Test it now:

1. Visit: https://profilepicapp-c2p7wl.azurewebsites.net
2. Sign in with any test user (testuser001 through testuser100@lobralicloud.onmicrosoft.com)
3. Password: TestPassword123!
4. Users without photos show default placeholder
5. Users with manually uploaded photos display correctly

## Prerequisites

1. **Azure CLI** installed and configured
2. **Logged in to Azure** with an account that has:
   - User Administrator role (or Global Administrator)
   - Ability to create users in Entra ID
3. **Microsoft Graph API permissions**

## Usage

### Step 1: Navigate to the scripts directory

```powershell
cd c:\Users\lobra\Documents\Repos\profilepicapp\scripts
```

### Step 2: Run the script

```powershell
.\Create-EntraTestUsers.ps1
```

### Step 3: Confirm

The script will show a summary and ask for confirmation before proceeding.

## Configuration

Edit these variables at the top of the script if needed:

- **$TenantDomain**: Your tenant domain (already set to `lobralicloud.onmicrosoft.com`)
- **$Password**: Default password for all test users (currently: `TestPassword123!`)

## Output

The script will:
1. Generate 100 unique user names (e.g., "John Smith", "Mary Johnson")
2. Create usernames in format: testuser001@lobralicloud.onmicrosoft.com through testuser100@...
3. Download profile pictures from various sources
4. Create each user in Entra ID
5. Upload the profile picture for each user
6. Display progress and summary

## Notes

- **Rate Limiting**: The script includes small delays to avoid API rate limiting
- **Temp Files**: Profile pictures are downloaded temporarily and deleted after upload
- **Time**: Creating 100 users takes approximately 10-15 minutes
- **Cleanup**: If you need to delete these users later, you can filter by the username pattern (testuser*)

## Troubleshooting

### "Not logged in" error
```powershell
az login
```

### "Permission denied" error
Make sure you have User Administrator or Global Administrator role in your tenant.

### "Failed to download image" warnings
Some image URLs may occasionally fail. The script will continue and the user will be created without a photo.

### To verify users were created
```powershell
az ad user list --query "[?starts_with(userPrincipalName, 'testuser')].{Name:displayName, UPN:userPrincipalName}" --output table
```

## Cleanup (Delete Test Users)

If you want to remove all test users:

```powershell
# List all test users
az ad user list --filter "startswith(userPrincipalName,'testuser')" --query "[].id" -o tsv

# Delete all test users (BE CAREFUL!)
az ad user list --filter "startswith(userPrincipalName,'testuser')" --query "[].id" -o tsv | ForEach-Object { az ad user delete --id $_ }
```

## Example Output

```
Generated 100 users
  - 50 with human photos
  - 25 with avatar faces
  - 13 with cat pictures
  - 12 with dog pictures

This will create 100 users in tenant domain: lobralicloud.onmicrosoft.com
Do you want to proceed? (yes/no): yes

Starting user creation...
This may take several minutes...

Creating user: James Smith (testuser001@lobralicloud.onmicrosoft.com) [human]... ✓ Created ✓ Photo uploaded
Creating user: Mary Johnson (testuser002@lobralicloud.onmicrosoft.com) [human]... ✓ Created ✓ Photo uploaded
...

========================================
User Creation Summary
========================================
Successfully created: 100 users
Failed: 0 users
Password for all users: TestPassword123!

Users can sign in at: https://portal.azure.com
========================================
```

## Security Note

⚠️ **Important**: These are test users with a common password. Do not use this script in a production environment without:
1. Changing to secure, unique passwords
2. Enabling MFA
3. Applying appropriate security policies

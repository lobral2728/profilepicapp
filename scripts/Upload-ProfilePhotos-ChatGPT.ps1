<# 
.SYNOPSIS
  Bulk-uploads profile photos to Entra ID users via Microsoft Graph.

.PREREQS
  - PowerShell 7+ recommended
  - Install-Module Microsoft.Graph -Scope CurrentUser
  - Connect-MgGraph will prompt for consent; you need User.ReadWrite.All

.EXAMPLES
  # Preferred: provide a CSV of target users (column 'UserPrincipalName')
  .\Set-BulkUserPhotos.ps1 `
    -ImagesRoot "C:\Users\lobra\Documents\Repos\profilepicapp\scripts\test_images" `
    -UserCsv "C:\Users\lobra\Documents\Repos\profilepicapp\scripts\users.csv"

  # Or auto-select by filter (e.g., UPNs starting with 'test')
  .\Set-BulkUserPhotos.ps1 `
    -ImagesRoot "C:\Users\lobra\Documents\Repos\profilepicapp\scripts\test_images" `
    -UserFilter "startswith(userPrincipalName,'test')" `
    -MaxUsers 100 -Shuffle
#>

param(
  [Parameter(Mandatory=$true)]
  [string]$ImagesRoot,

  [string]$UserCsv,  # CSV with header 'UserPrincipalName' (option A)

  [string]$UserFilter = "startswith(userPrincipalName,'test')", # used if -UserCsv not supplied (option B)

  [int]$MaxUsers = 100,

  [switch]$Shuffle,  # shuffle images before pairing

  [string[]]$ImageExtensions = @('jpg','jpeg','png'),

  [int]$ThrottleMs = 300,

  [switch]$DryRun
)

# --- Helpers ---
function Get-TargetUsers {
  param()

  function Resolve-UserCsvPath {
    param([string]$ExplicitPath, [string]$ImagesRoot)
    # If explicitly provided and exists, use it.
    if ($ExplicitPath -and (Test-Path -LiteralPath $ExplicitPath)) {
      return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    # If explicit but missing, try resolving relative to ImagesRoot.
    if ($ExplicitPath) {
      $leaf = Split-Path -Path $ExplicitPath -Leaf
      if ($ImagesRoot -and (Test-Path -LiteralPath $ImagesRoot)) {
        $alt = Join-Path -Path $ImagesRoot -ChildPath $leaf
        if (Test-Path -LiteralPath $alt) {
          Write-Warning "UserCsv not found at '$ExplicitPath'. Using '$alt' instead."
          return (Resolve-Path -LiteralPath $alt).Path
        }
      }
      throw "UserCsv not found: $ExplicitPath"
    }
    # No explicit path: try to auto-detect a CSV in ImagesRoot that has a 'userPrincipalName' column.
    if (-not $ImagesRoot -or -not (Test-Path -LiteralPath $ImagesRoot)) {
      throw "No -UserCsv provided and ImagesRoot is invalid; cannot auto-detect a CSV."
    }
    $candidates = Get-ChildItem -LiteralPath $ImagesRoot -Filter *.csv -File | Sort-Object LastWriteTime -Descending
    foreach ($f in $candidates) {
      try {
        $rows = Import-Csv -Path $f.FullName -ErrorAction Stop
        if ($rows) {
          $hasUPN = ($rows | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -ieq 'userPrincipalName' })
          if ($hasUPN) {
            Write-Host "Auto-detected CSV: $($f.FullName)" -ForegroundColor Cyan
            return $f.FullName
          }
        }
      } catch { }
    }
    throw "Could not auto-detect a CSV with a 'userPrincipalName' column under $ImagesRoot."
  }

  $csvPathToUse = Resolve-UserCsvPath -ExplicitPath $UserCsv -ImagesRoot $ImagesRoot
  Write-Host "Using CSV: $csvPathToUse" -ForegroundColor Cyan

  $rows = Import-Csv -Path $csvPathToUse
  if (-not $rows -or $rows.Count -eq 0) {
    throw "CSV '$csvPathToUse' appears empty."
  }

  # Find the userPrincipalName column (case-insensitive)
  $upnCol = ($rows | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -ieq 'userPrincipalName' }).Name
  if (-not $upnCol) {
    $available = ($rows | Get-Member -MemberType NoteProperty).Name -join ', '
    throw "CSV must contain a 'userPrincipalName' column (any casing). Found columns: $available"
  }

  $upns = $rows | ForEach-Object { $_.$upnCol } |
          Where-Object { $_ -and $_.ToString().Trim().Length -gt 0 } |
          Select-Object -Unique

  if (-not $upns -or $upns.Count -eq 0) {
    throw "No userPrincipalName values found in '$csvPathToUse'."
  }

  Write-Host "Resolving $($upns.Count) users from CSV..." -ForegroundColor Cyan

  $resolved = foreach ($u in $upns) {
    try {
      $user = Get-MgUser -UserId $u -ErrorAction Stop
      [pscustomobject]@{
        Id                = $user.Id
        DisplayName       = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
      }
    } catch {
      Write-Warning "Could not resolve user: $u (`$_.Exception.Message: $($_.Exception.Message))"
    }
  }

  if (-not $resolved -or $resolved.Count -eq 0) {
    throw "No users resolved from CSV '$csvPathToUse'."
  }

  # Respect -MaxUsers and keep deterministic order
  $resolved |
    Sort-Object UserPrincipalName |
    Select-Object -First $MaxUsers
}

function Ensure-Graph {
  if (-not (Get-Module Microsoft.Graph -ListAvailable)) {
    Write-Host "Installing Microsoft.Graph module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
  }
  $scopes = @("User.ReadWrite.All")
  try {
    $ctx = Get-MgContext -ErrorAction Stop
    if (-not ($ctx.Scopes -and ($ctx.Scopes -contains "User.ReadWrite.All"))) {
      Write-Host "Connecting to Microsoft Graph with required scopes..." -ForegroundColor Yellow
      Connect-MgGraph -Scopes $scopes -NoWelcome
    }
  } catch {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes $scopes -NoWelcome
  }
}

function Get-GraphJson {
  param([string]$Uri)

  # ---------- Client-side discovery (no $top, no $filter in URL) ----------
  $base   = 'https://graph.microsoft.com/v1.0/users'
  $select = 'id,displayName,userPrincipalName'
  $pageUri = "$base`?\$select=$select"

  $all = @()
  while ($pageUri -and $all.Count -lt ($MaxUsers * 5)) {  # safety bound
    $j = Get-GraphJson -Uri $pageUri
    if ($j.value) { $all += $j.value }
    $pageUri = $j.'@odata.nextLink'
    # Soft break if we already have way more than needed
    if ($all.Count -ge ($MaxUsers * 5)) { break }
  }
  if (-not $all) { throw "No users returned from /users." }

  # ---------- Build predicate from your -UserFilter (supports startswith on common attrs) ----------
  $filterExpr = if ($UserFilter) { $UserFilter } else { "startswith(userPrincipalName,'test')" }
  $predicate = { $_.userPrincipalName -like 'test*' }  # default
  if ($filterExpr -match "^\s*startswith\(\s*([A-Za-z0-9_]+)\s*,\s*'([^']+)'\s*\)\s*$") {
    $attr = $matches[1]; $prefix = $matches[2]
    switch ($attr) {
      'userPrincipalName' { $predicate = { $_.userPrincipalName -like "$prefix*" } }
      'displayName'       { $predicate = { $_.displayName       -like "$prefix*" } }
      'mailNickname'      { $predicate = { $_.mailNickname      -like "$prefix*" } }
      default             { $predicate = { $_.userPrincipalName -like "$prefix*" } }
    }
  } elseif ($filterExpr -match "^\s*department\s+eq\s+'([^']+)'\s*$") {
    $dep = $matches[1]
    $predicate = { $_.department -eq $dep }
  }

  $matched = $all | Where-Object $predicate
  if (-not $matched) { throw "No users matched filter '$filterExpr'. Try a different prefix/attribute." }

  $final =
    $matched |
    Sort-Object userPrincipalName |
    Select-Object -First $MaxUsers |
    ForEach-Object {
      [pscustomobject]@{
        Id                = $_.id
        DisplayName       = $_.displayName
        UserPrincipalName = $_.userPrincipalName
      }
    }

  return $final
}


function Get-ImageFiles {
  if (-not (Test-Path $ImagesRoot)) { throw "ImagesRoot not found: $ImagesRoot" }

  $labels = @('human','avatar','animal')
  $files = @()

  foreach ($label in $labels) {
    $dir = Join-Path $ImagesRoot $label
    if (-not (Test-Path $dir)) {
      Write-Warning "Missing subfolder: $dir (skipping)"
      continue
    }
    $pattern = $ImageExtensions | ForEach-Object { "*.$_" }
    foreach ($p in $pattern) {
      $files += Get-ChildItem -Path $dir -File -Filter $p -Recurse |
        Select-Object FullName, Name, @{n='Label';e={$label}}
    }
  }

  if (-not $files) { throw "No image files found under $ImagesRoot\[human|avatar|animal]." }
  return $files
}

function Compress-IfNeeded {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [int]$MaxBytes = 4MB
  )
  try {
    $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
  } catch { throw "Cannot access image: $Path" }

  if ($fi.Length -le $MaxBytes) { return $Path }

  # Re-encode to JPEG with quality to get under 4 MB
  Add-Type -AssemblyName System.Drawing
  $tmp = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".jpg")
  $img = [System.Drawing.Image]::FromFile($Path)
  try {
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
    $encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $enc = [System.Drawing.Imaging.Encoder]::Quality

    foreach ($q in 90,80,70,60,50,40) {
      $encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($enc, [int64]$q)
      $img.Save($tmp, $codec, $encParams)
      if ((Get-Item $tmp).Length -le $MaxBytes) { break }
    }
  } finally {
    $img.Dispose()
  }
  return $tmp
}

function Set-UserPhoto {
  param(
    [Parameter(Mandatory=$true)]$User,
    [Parameter(Mandatory=$true)][string]$ImagePath
  )
  # Prefer Set-MgUserPhotoContent (SDK v2)
  try {
    Set-MgUserPhotoContent -UserId $User.Id -InFile $ImagePath -ErrorAction Stop | Out-Null
    return $true
  } catch {
    Write-Warning "Set-MgUserPhotoContent failed for $($User.UserPrincipalName): $($_.Exception.Message)"
    # Fallback raw request
    try {
      $bytes = [System.IO.File]::ReadAllBytes($ImagePath)
      Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/v1.0/users/$($User.Id)/photo/`$value" `
        -Body $bytes -ContentType "image/jpeg" -ErrorAction Stop | Out-Null
      return $true
    } catch {
      Write-Warning "Raw PUT /photo/\$value failed for $($User.UserPrincipalName): $($_.Exception.Message)"
      return $false
    }
  }
}

# --- Main ---
$ErrorActionPreference = 'Stop'

Ensure-Graph

$users = Get-TargetUsers
$images = Get-ImageFiles

# Pairing logic
if ($Shuffle) {
  $images = $images | Get-Random -Count $images.Count
} else {
  $images = $images | Sort-Object Name
}
$take = [Math]::Min($users.Count, $images.Count)
if ($take -lt $users.Count) {
  Write-Warning "Only $take images found for $($users.Count) users; only first $take users will be processed."
}
$users = $users | Select-Object -First $take
$images = $images | Select-Object -First $take

$mapOut = New-Object System.Collections.Generic.List[object]
$ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

$csvPath = Join-Path $ImagesRoot "profile_upload_map.csv"

Write-Host "Processing $take user(s)..." -ForegroundColor Green
$i = 0
foreach ($pair in ($users | Select-Object @{n='User';e={$_.Clone()}}, @{n='Index';e={$script:i++}})) { }

# re-enumerate cleanly
for ($i=0; $i -lt $take; $i++) {
  $user = $users[$i]
  $img  = $images[$i]

  $status = "Skipped (DryRun)"
  $finalImage = $img.FullName
  $note = ""

  try {
    $candidate = Compress-IfNeeded -Path $img.FullName
    if ($candidate -ne $img.FullName) {
      $finalImage = $candidate
      $note = "Re-encoded JPEG"
    }

    if (-not $DryRun) {
      $ok = Set-UserPhoto -User $user -ImagePath $finalImage
      $status = $(if ($ok) { "Success" } else { "Failed" })
    }

  } catch {
    $status = "Failed: $($_.Exception.Message)"
  }

  $mapOut.Add([pscustomobject]@{
    Timestamp          = $ts
    UserPrincipalName  = $user.UserPrincipalName
    DisplayName        = $user.DisplayName
    ImageFile          = $img.FullName
    Label              = $img.Label
    FinalUploadedFile  = $finalImage
    Status             = $status
    Note               = $note
  })

  if (-not $DryRun) { Start-Sleep -Milliseconds $ThrottleMs }
}

$mapOut | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Mapping written to: $csvPath" -ForegroundColor Green

if ($DryRun) {
  Write-Host "DryRun completed. No photos were uploaded." -ForegroundColor Yellow
} else {
  Write-Host "Photo upload routine finished." -ForegroundColor Green
}

# Download Sample Profile Images
# This script downloads sample images from free public APIs

$BaseDir = ".\test_images"

Write-Host "Downloading sample profile images..." -ForegroundColor Cyan
Write-Host "This may take a few minutes...`n" -ForegroundColor Gray

# Download human face images from UI Avatars (generates images from initials)
Write-Host "Downloading human avatar images..." -ForegroundColor Yellow
$humanNames = @(
    "John-Smith", "Jane-Doe", "Michael-Johnson", "Sarah-Williams", "David-Brown",
    "Emily-Jones", "Robert-Garcia", "Lisa-Miller", "James-Davis", "Mary-Rodriguez",
    "William-Martinez", "Patricia-Hernandez", "Richard-Lopez", "Linda-Gonzalez", "Joseph-Wilson",
    "Barbara-Anderson", "Thomas-Thomas", "Elizabeth-Taylor", "Charles-Moore", "Jennifer-Jackson",
    "Christopher-Martin", "Maria-Lee", "Daniel-Perez", "Nancy-Thompson", "Matthew-White",
    "Karen-Harris", "Anthony-Sanchez", "Betty-Clark", "Mark-Ramirez", "Helen-Lewis",
    "Donald-Robinson", "Sandra-Walker", "Steven-Young", "Donna-Allen", "Paul-King",
    "Carol-Wright", "Andrew-Scott", "Ruth-Torres", "Joshua-Nguyen", "Sharon-Hill",
    "Kenneth-Flores", "Michelle-Green", "Kevin-Adams", "Laura-Nelson", "Brian-Baker",
    "Kimberly-Hall", "George-Rivera", "Susan-Campbell", "Edward-Mitchell", "Dorothy-Carter"
)

$counter = 1
foreach ($name in $humanNames) {
    $url = "https://ui-avatars.com/api/?name=$name&size=200&background=random&color=fff&format=png"
    $outputPath = Join-Path $BaseDir "human\human_$($counter.ToString('D2')).png"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
        Write-Host "  ✓ Downloaded human_$($counter.ToString('D2')).png" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to download human_$($counter.ToString('D2')).png" -ForegroundColor Red
    }
    
    $counter++
    Start-Sleep -Milliseconds 100
}

# Download avatar/cartoon images using DiceBear API with different styles
Write-Host "`nDownloading cartoon avatar images..." -ForegroundColor Yellow
$avatarStyles = @('avataaars', 'bottts', 'personas', 'lorelei', 'micah')

$counter = 1
for ($i = 1; $i -le 25; $i++) {
    $style = $avatarStyles[$i % $avatarStyles.Count]
    $seed = "avatar$i"
    $url = "https://api.dicebear.com/7.x/$style/png?seed=$seed&size=200"
    $outputPath = Join-Path $BaseDir "avatar\avatar_$($counter.ToString('D2')).png"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
        Write-Host "  ✓ Downloaded avatar_$($counter.ToString('D2')).png ($style)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to download avatar_$($counter.ToString('D2')).png" -ForegroundColor Red
    }
    
    $counter++
    Start-Sleep -Milliseconds 200
}

# Download animal images from Picsum (Lorem Ipsum for photos)
Write-Host "`nDownloading animal images..." -ForegroundColor Yellow

# Use specific animal-themed images from Lorem Picsum with specific IDs that tend to be animals/nature
$animalIds = @(
    237, 1025, 1074, 169, 177, 180, 200, 219, 240, 
    250, 287, 433, 582, 593, 659, 718, 783, 790, 
    826, 835, 866, 870, 883, 896, 905
)

$counter = 1
foreach ($id in $animalIds) {
    $url = "https://picsum.photos/id/$id/200/200"
    $outputPath = Join-Path $BaseDir "animal\animal_$($counter.ToString('D2')).jpg"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
        Write-Host "  ✓ Downloaded animal_$($counter.ToString('D2')).jpg" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to download animal_$($counter.ToString('D2')).jpg" -ForegroundColor Red
    }
    
    $counter++
    Start-Sleep -Milliseconds 200
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Download Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$humanCount = (Get-ChildItem (Join-Path $BaseDir "human") -File).Count
$avatarCount = (Get-ChildItem (Join-Path $BaseDir "avatar") -File).Count
$animalCount = (Get-ChildItem (Join-Path $BaseDir "animal") -File).Count

Write-Host "Human images: $humanCount files" -ForegroundColor Green
Write-Host "Avatar images: $avatarCount files" -ForegroundColor Green
Write-Host "Animal images: $animalCount files" -ForegroundColor Green
Write-Host "Total: $($humanCount + $avatarCount + $animalCount) images" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

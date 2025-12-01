# Manual Download Guide for Adult Face Photos

Write-Host @"
========================================
Manual Download Instructions
========================================

Since automated APIs don't reliably filter for adult faces (18-70 years old),
here are recommended FREE sources for downloading adult portrait photos:

Option 1: Pexels (Recommended)
------------------------------
1. Visit: https://www.pexels.com/search/adult%20portrait/
2. Filter by orientation: Square
3. Download 50 photos manually to: test_images\human\
4. Name them: human_01.jpg, human_02.jpg, ... human_50.jpg

Option 2: Unsplash
------------------
1. Visit: https://unsplash.com/s/photos/adult-portrait
2. Download 50 photos to: test_images\human\
3. Name them sequentially: human_01.jpg through human_50.jpg

Option 3: Pixabay
-----------------
1. Visit: https://pixabay.com/photos/search/adult%20portrait/
2. Filter: People, Photos only
3. Download 50 images to: test_images\human\

Quick Check Script
------------------
After downloading, run this to verify:
  Get-ChildItem .\test_images\human | Measure-Object

You need exactly 50 files named human_01.jpg through human_50.jpg

Rename Files Script
-------------------
If you download files with random names, run:
  `$files = Get-ChildItem .\test_images\human -File | Select-Object -First 50
  `$counter = 1
  foreach (`$file in `$files) {
      Rename-Item `$file.FullName -NewName "human_`$(`$counter.ToString('D2')).jpg"
      `$counter++
  }

========================================
"@

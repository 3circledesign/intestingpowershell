
# loader.ps1 — fully automatic, no param, uses env PATCHID

# --- Step 0: Get PatchID ---
if (-not $env:PATCHID) {
    Write-Host "Please set environment variable PATCHID"
    exit
}
$AppID = $env:PATCHID
Write-Host "Running patch $AppID"

# --- Step 1: Detect Steam Path ---
$steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (-not $steamPath) {
    $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
}
if (-not $steamPath) {
    Write-Host "Steam installation not found!"
    exit
}

# --- Step 2: Find appmanifest for the AppID ---
$appManifest = Get-ChildItem "$steamPath\steamapps" -Filter "appmanifest_$AppID.acf" -Recurse | Select-Object -First 1
if (-not $appManifest) {
    Write-Host "AppID $AppID not found in Steam library!"
    exit
}

# --- Step 3: Parse installdir ---
$acfContent = Get-Content $appManifest.FullName
$installDirLine = $acfContent | Where-Object { $_ -match '"installdir"' }
$installDir = ($installDirLine -split '"')[3]

# --- Step 4: Build full path ---
$gamePath = Join-Path (Join-Path $steamPath "steamapps\common") $installDir
Write-Host "Detected game folder: $gamePath"

# --- Step 5: Get file list from GitHub branch ---
$repoOwner = "CrabBerjoget"
$repoName = "intestingpowershell"
$branch = $AppID
$apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/contents/?ref=$branch"

try {
    $filesList = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -Headers @{ "User-Agent" = "PowerShell" }
} catch {
    Write-Host "Failed to fetch file list from GitHub branch $branch"
    exit
}

# --- Step 6: Download all files ---
foreach ($file in $filesList) {
    if ($file.type -eq "file") {
        $fileUrl = $file.download_url
        $fileName = $file.name
        $destination = Join-Path $gamePath $fileName
        Write-Host "Downloading $fileName → $destination"
        try {
            Invoke-WebRequest $fileUrl -OutFile $destination
        } catch {
            Write-Host "Failed to download $fileName"
        }
    }
}

Write-Host "Patch complete!"

# --- Step 7: Ensure UnRAR.exe is downloaded ---
$unrarPath = Join-Path $gamePath "UnRAR.exe"
if (-not (Test-Path $unrarPath)) {
    Write-Host "Downloading UnRAR.exe..."
    try {
        Invoke-WebRequest -Uri "https://github.com/CrabBerjoget/intestingpowershell/raw/main/unrarw32.exe" -OutFile $unrarPath
    } catch {
        Write-Host "Failed to download UnRAR.exe. RAR extraction will be skipped."
        $unrarPath = $null
    }
}

# --- Step 8: Extract RAR files silently to the same folder ---

$rarFiles = Get-ChildItem -Path $gamePath -Recurse -Filter *.rar
foreach ($rar in $rarFiles) {
if ($unrarPath -and (Test-Path $unrarPath)) {
$destination = $rar.DirectoryName  # Extract to same folder as RAR
Write-Host "Extracting $($rar.FullName) → $destination"
Start-Process -FilePath $unrarPath -ArgumentList "x `"$($rar.FullName)`" `"$destination`" -y" -WindowStyle Hidden -Wait
Remove-Item $rar.FullName -Force
} else {
Write-Host "UnRAR.exe not found. Skipping $($rar.Name)"
}
}
Write-Host "RAR extraction complete!"



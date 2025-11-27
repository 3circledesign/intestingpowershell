
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

# --- Step 0: Detect Steam Path ---

$AppID = $env:PATCHID
if (-not $AppID) { Write-Host "PATCHID not set"; exit }

$steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (-not $steamPath) { $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath }
if (-not $steamPath) { Write-Host "Steam not found"; exit }

$appManifest = Get-ChildItem "$steamPath\steamapps" -Filter "appmanifest_$AppID.acf" -Recurse | Select-Object -First 1
if (-not $appManifest) { Write-Host "AppID not found"; exit }

$acfContent = Get-Content $appManifest.FullName
$installDirLine = $acfContent | Where-Object { $_ -match '"installdir"' }
$installDir = ($installDirLine -split '"')[3]
$gamePath = Join-Path "$steamPath\steamapps\common" $installDir
# This script scans the game folder for RAR files and extracts them

# --- Step 7: Extract any RAR files inside ---

# Ensure UnRAR.exe is downloaded to the game folder
$unrarPath = Join-Path $gamePath "UnRAR.exe"
if (-not (Test-Path $unrarPath)) {
    Write-Host "Downloading UnRAR.exe..."
    try {
        # Use GitHub raw link instead of Rarlab website
        Invoke-WebRequest -Uri "https://github.com/CrabBerjoget/intestingpowershell/raw/main/unrarw32.exe" -OutFile $unrarPath
    } catch {
        Write-Host "Failed to download UnRAR.exe. RAR extraction will be skipped."
        $unrarPath = $null
    }
}

Write-Host "Your remote script is running!"
Write-Host "This is coming from GitHub RAW."

# test.ps1

param(
[string]$AppID = $env:PATCHID  # fallback if using environment variable
)

if (-not $AppID) {
Write-Host "Please provide AppID as parameter or set $env:PATCHID"
exit
}

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

# --- Step 3: Parse installdir from appmanifest ---

$acfContent = Get-Content $appManifest.FullName
$installDirLine = $acfContent | Where-Object { $_ -match '"installdir"' }
$installDir = ($installDirLine -split '"')[3]

# --- Step 4: Build full path to game ---

$gamePath = Join-Path (Join-Path $steamPath "steamapps\common") $installDir
Write-Host "Detected game folder: $gamePath"

# --- Step 5: Define files to download (replace with your raw URLs) ---

$files = @(
"[https://raw.githubusercontent.com/CrabBerjoget/intestingpowershell/2934220/file1.txt](https://raw.githubusercontent.com/CrabBerjoget/intestingpowershell/2934220/file1.txt)",
"[https://raw.githubusercontent.com/CrabBerjoget/intestingpowershell/2934220/file2.dll](https://raw.githubusercontent.com/CrabBerjoget/intestingpowershell/2934220/file2.dll)"
)

# --- Step 6: Download files to game folder ---

foreach ($fileUrl in $files) {
$fileName = Split-Path $fileUrl -Leaf
$destination = Join-Path $gamePath $fileName
Write-Host "Downloading $fileName → $destination"
try {
Invoke-WebRequest $fileUrl -OutFile $destination
} catch {
Write-Host "Failed to download $fileName"
}
}

Write-Host "Patch complete!"

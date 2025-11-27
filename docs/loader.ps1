# loader.ps1 — download branch as ZIP and patch game

# --- Step 0: Get AppID ---

if (-not $env:PATCHID) {
Write-Host "Please set environment variable PATCHID"
exit
}
$AppID = $env:PATCHID
Write-Host "Running patch $AppID"

# --- Step 1: Detect Steam Path ---

$steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (-not $steamPath) { $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath }
if (-not $steamPath) { Write-Host "Steam not found"; exit }

# --- Step 2: Find appmanifest ---

$appManifest = Get-ChildItem "$steamPath\steamapps" -Filter "appmanifest_$AppID.acf" -Recurse | Select-Object -First 1
if (-not $appManifest) { Write-Host "AppID not found"; exit }

# --- Step 3: Get game folder ---

$acfContent = Get-Content $appManifest.FullName
$installDirLine = $acfContent | Where-Object { $_ -match '"installdir"' }
$installDir = ($installDirLine -split '"')[3]
$gamePath = Join-Path "$steamPath\steamapps\common" $installDir
Write-Host "Detected game folder: $gamePath"

# --- Step 4: Download branch as ZIP ---

$zipUrl = "[https://github.com/CrabBerjoget/intestingpowershell/archive/refs/heads/$AppID.zip](https://github.com/CrabBerjoget/intestingpowershell/archive/refs/heads/$AppID.zip)"
$tempZip = Join-Path $env:TEMP "$AppID.zip"

Write-Host "Downloading branch ZIP..."
try {
Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip
} catch {
Write-Host "Failed to download ZIP for branch $AppID"
exit
}

# --- Step 5: Extract ZIP to game folder ---

Write-Host "Extracting ZIP to game folder..."
try {
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $gamePath)
Remove-Item $tempZip -Force
} catch {
Write-Host "Failed to extract ZIP"
exit
}

# --- Step 6: Extract any RAR files inside ---

$rarFiles = Get-ChildItem -Path $gamePath -Recurse -Filter *.rar
foreach ($rar in $rarFiles) {
if (Get-Command "UnRAR.exe" -ErrorAction SilentlyContinue) {
Write-Host "Extracting $($rar.FullName)"
Start-Process "UnRAR.exe" -ArgumentList "x `"$($rar.FullName)`" `"$gamePath`" -y" -Wait
Remove-Item $rar.FullName -Force
} else {
Write-Host "UnRAR.exe not found. Skipping $($rar.Name)"
}
}

Write-Host "Patch complete!"

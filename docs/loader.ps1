# Post-fetch RAR extraction — keep loader.ps1 intact

# This script scans the game folder for RAR files and extracts them

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

# --- Step 1: Find RAR files ---

$rarFiles = Get-ChildItem -Path $gamePath -Recurse -Filter *.rar
if ($rarFiles.Count -eq 0) {
Write-Host "No RAR files detected. Nothing to extract."
exit
}

Write-Host "RAR files detected. Proceeding with extraction..."

foreach ($rar in $rarFiles) {
if (Get-Command "UnRAR.exe" -ErrorAction SilentlyContinue) {
Write-Host "Extracting $($rar.FullName)"
Start-Process "UnRAR.exe" -ArgumentList "x `"$($rar.FullName)`" `"$gamePath`" -y" -Wait
Remove-Item $rar.FullName -Force
} else {
Write-Host "UnRAR.exe not found. Skipping $($rar.Name)"
}
}

Write-Host "RAR extraction complete!"

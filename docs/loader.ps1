# loader.ps1 — fully automatic, accepts $AppID or env:PATCHID

# --- Step 0: Get PatchID (AppID) ---
if (-not (Get-Variable -Name AppID -ErrorAction SilentlyContinue)) {
    if (-not $env:PATCHID) {
        Write-Host "❌ Error: No AppID provided." -ForegroundColor Red
        Write-Host "   - Set `$AppID before calling this script, OR" -ForegroundColor Yellow
        Write-Host "   - Set environment variable PATCHID." -ForegroundColor Yellow
        exit 1
    }
    $AppID = $env:PATCHID
}
Write-Host "🚀 Running patch for AppID: $AppID" -ForegroundColor Cyan

# --- Step 1: Detect Steam Path ---
$steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (-not $steamPath) {
    $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
}
if (-not $steamPath) {
    Write-Host "❌ Steam installation not found!" -ForegroundColor Red
    exit 1
}

# --- Step 2: Find appmanifest for the AppID ---
$appManifest = Get-ChildItem "$steamPath\steamapps" -Filter "appmanifest_$AppID.acf" -Recurse | Select-Object -First 1
if (-not $appManifest) {
    Write-Host "❌ AppID $AppID not found in Steam library!" -ForegroundColor Red
    Write-Host "   Make sure the game is installed via Steam." -ForegroundColor Yellow
    exit 1
}

# --- Step 3: Parse installdir from ACF ---
$acfContent = Get-Content $appManifest.FullName -Raw
if ($acfContent -match '"installdir"\s+"([^"]+)"') {
    $installDir = $matches[1]
} else {
    Write-Host "❌ Could not parse installdir from appmanifest." -ForegroundColor Red
    exit 1
}

# --- Step 4: Build full game path ---
$gamePath = Join-Path (Join-Path $steamPath "steamapps\common") $installDir
Write-Host "📁 Detected game folder: $gamePath" -ForegroundColor Green

# --- Step 5: Fetch file list from GitHub branch (named $AppID) ---
$repoOwner = "3circledesign"
$repoName = "intestingpowershell"
$branch = $AppID
$apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/contents/?ref=$branch"

Write-Host "📥 Fetching file list from branch: $branch" -ForegroundColor Cyan
try {
    $filesList = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -Headers @{ "User-Agent" = "PowerShell" }
} catch {
    Write-Host "❌ Failed to fetch file list from GitHub branch '$branch'." -ForegroundColor Red
    Write-Host "   Ensure the branch exists and is public." -ForegroundColor Yellow
    exit 1
}

if (-not $filesList) {
    Write-Host "⚠️ No files found in branch '$branch'." -ForegroundColor Yellow
    exit 1
}

# --- Step 6: Download all files to game folder ---
foreach ($file in $filesList) {
    if ($file.type -eq "file") {
        $fileUrl = $file.download_url
        $fileName = $file.name
        $destination = Join-Path $gamePath $fileName
        Write-Host "⬇️  Downloading: $fileName" -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $fileUrl -OutFile $destination -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Host "❌ Failed to download: $fileName" -ForegroundColor Red
        }
    }
}
Write-Host "✅ Patch files downloaded!" -ForegroundColor Green

# --- Step 7: Ensure UnRAR.exe is present ---
$unrarPath = Join-Path $gamePath "UnRAR.exe"
if (-not (Test-Path $unrarPath)) {
    Write-Host "📦 Downloading UnRAR.exe..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri "https://github.com/3circledesign/intestingpowershell/raw/main/UnRAR.exe" -OutFile $unrarPath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "⚠️ Failed to download UnRAR.exe. RAR extraction will be skipped." -ForegroundColor Yellow
        $unrarPath = $null
    }
}

# --- Step 8: Extract all .rar files (recursively) and delete them ---
if ($unrarPath) {
    $rarFiles = Get-ChildItem -Path $gamePath -Recurse -Filter "*.rar"
    if ($rarFiles) {
        foreach ($rar in $rarFiles) {
            $destination = $rar.DirectoryName
            Write-Host "🔍 Extracting: $($rar.Name) → $destination" -ForegroundColor Cyan
            try {
                $proc = Start-Process -FilePath $unrarPath -ArgumentList "x", "`"$($rar.FullName)`"", "`"$destination`"", "-y", "-inul" -Wait -PassThru -WindowStyle Hidden
                if ($proc.ExitCode -eq 0) {
                    Remove-Item $rar.FullName -Force
                    Write-Host "🗑️  Deleted: $($rar.Name)" -ForegroundColor Green
                } else {
                    Write-Host "⚠️ Extraction failed (exit code $($proc.ExitCode)): $($rar.Name)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "❌ Error extracting: $($rar.Name)" -ForegroundColor Red
            }
        }
        Write-Host "✅ RAR extraction complete!" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ No .rar files found to extract." -ForegroundColor Gray
    }
}

Write-Host "🎉 Patching complete for AppID: $AppID" -ForegroundColor Magenta

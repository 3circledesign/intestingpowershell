<#
loader.ps1 - Game mod/patch file downloader (no DRM/anti-cheat bypass logic)

What it does:
1) Gets AppID from -AppID or env:PATCHID
2) Detects Steam install path
3) Searches ALL Steam libraries for appmanifest_{AppID}.acf
4) Reads "installdir" from the ACF
5) Downloads files from a GitHub repo path (recursively) using branch = AppID (default)
6) Optionally downloads UnRAR.exe and extracts .rar files found under game folder

Notes:
- Only use on games you own and on files you are authorized to install.
- This script does not attempt to bypass DRM or protections.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $AppID,

    [Parameter(Mandatory = $false)]
    [string] $RepoOwner = "3circledesign",

    [Parameter(Mandatory = $false)]
    [string] $RepoName = "intestingpowershell",

    # Folder inside repo to download from, e.g. "patchfiles" or "docs/files"
    [Parameter(Mandatory = $false)]
    [string] $RepoPath = "",

    # Default: branch name = AppID
    [Parameter(Mandatory = $false)]
    [string] $Branch,

    # If set, will try to extract .rar files (requires UnRAR.exe)
    [switch] $ExtractRar,

    # If you want, you can point this to your own UnRAR.exe URL
    [Parameter(Mandatory = $false)]
    [string] $UnrarUrl = "https://raw.githubusercontent.com/3circledesign/intestingpowershell/main/UnRAR.exe"
)

$ErrorActionPreference = "Stop"

function Write-Info($msg)  { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host $msg -ForegroundColor Yellow }
function Write-Bad($msg)   { Write-Host $msg -ForegroundColor Red }

function Get-SteamInstallPath {
    $paths = @()

    try {
        $p = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
        if ($p) { $paths += $p }
    } catch {}

    try {
        $p = (Get-ItemProperty "HKLM:\SOFTWARE\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
        if ($p) { $paths += $p }
    } catch {}

    try {
        $p = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
        if ($p) { $paths += $p }
    } catch {}

    try {
        $p = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
        if ($p) { $paths += $p }
    } catch {}

    $paths = $paths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
    if (-not $paths) { return $null }
    return $paths[0]
}

function Get-SteamLibraries([string] $steamPath) {
    $libs = New-Object System.Collections.Generic.List[string]
    $libs.Add($steamPath)

    $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
    if (-not (Test-Path $vdf)) {
        return $libs.ToArray() | Select-Object -Unique
    }

    $text = Get-Content $vdf -Raw

    # New format blocks: "1" { "path" "D:\\SteamLibrary" ... }
    $reNew = [regex] '"\d+"\s*\{\s*[^}]*?"path"\s*"([^"]+)"'
    foreach ($m in $reNew.Matches($text)) {
        $p = $m.Groups[1].Value
        if ($p) { $libs.Add($p) }
    }

    # Old format: "1"  "D:\\SteamLibrary"
    $reOld = [regex] '"\d+"\s*"([^"]+)"'
    foreach ($m in $reOld.Matches($text)) {
        $p = $m.Groups[1].Value
        if ($p -and $p -notmatch '^\d+$') { $libs.Add($p) }
    }

    return ($libs.ToArray() | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)
}

function Find-AppManifest([string[]] $libraries, [string] $appId) {
    foreach ($lib in $libraries) {
        $candidate = Join-Path $lib "steamapps\appmanifest_$appId.acf"
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    return $null
}

function Get-InstallDirFromAcf([string] $acfPath) {
    $acf = Get-Content $acfPath -Raw
    if ($acf -match '"installdir"\s+"([^"]+)"') {
        return $matches[1]
    }
    return $null
}

function Invoke-GitHubJson([string] $url) {
    $headers = @{
        "User-Agent" = "Steam-Mod-Downloader/1.0"
        "Accept"     = "application/vnd.github+json"
    }
    return Invoke-RestMethod -Uri $url -Headers $headers -Method Get
}

function Download-File([string] $url, [string] $outFile) {
    $headers = @{ "User-Agent" = "Steam-Mod-Downloader/1.0" }
    $dir = Split-Path $outFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Invoke-WebRequest -Uri $url -Headers $headers -OutFile $outFile
}

function Download-GitHubContentsRecursive {
    param(
        [string] $Owner,
        [string] $Repo,
        [string] $BranchRef,
        [string] $PathInRepo,   # can be "" for root
        [string] $DestRoot      # full path to game folder
    )

    # Normalize repo path for API
    $apiPath = $PathInRepo
    if ([string]::IsNullOrWhiteSpace($apiPath)) {
        $apiUrl = "https://api.github.com/repos/$Owner/$Repo/contents?ref=$BranchRef"
    } else {
        $apiPath = $apiPath.TrimStart("/")
        $apiUrl = "https://api.github.com/repos/$Owner/$Repo/contents/$apiPath?ref=$BranchRef"
    }

    Write-Info "📥 Listing: $apiUrl"
    $items = Invoke-GitHubJson $apiUrl

    # When Path points to a file, GitHub returns an object not an array
    if ($items -and $items.type -eq "file") {
        $rel = if ($PathInRepo) { $PathInRepo } else { $items.name }
        $dest = Join-Path $DestRoot $rel
        Write-Info "⬇️  Downloading file: $rel"
        Download-File -url $items.download_url -outFile $dest
        return
    }

    foreach ($item in $items) {
        if ($item.type -eq "file") {
            $rel = if ($PathInRepo) { Join-Path $PathInRepo $item.name } else { $item.name }
            $dest = Join-Path $DestRoot $rel
            Write-Info "⬇️  Downloading: $rel"
            Download-File -url $item.download_url -outFile $dest
        }
        elseif ($item.type -eq "dir") {
            $nextPath = if ($PathInRepo) { Join-Path $PathInRepo $item.name } else { $item.name }
            Download-GitHubContentsRecursive -Owner $Owner -Repo $Repo -BranchRef $BranchRef -PathInRepo $nextPath -DestRoot $DestRoot
        }
    }
}

# ------------------- MAIN -------------------

if (-not $AppID) {
    if ($env:PATCHID) { $AppID = $env:PATCHID }
}
if (-not $AppID) {
    Write-Bad "❌ Error: No AppID provided. Use -AppID or set env:PATCHID."
    exit 1
}
if (-not $Branch) { $Branch = $AppID }

Write-Info "🚀 Running patch downloader for AppID: $AppID"
Write-Info "🔧 Repo: $RepoOwner/$RepoName | Branch: $Branch | Path: '$RepoPath'"

$steamPath = Get-SteamInstallPath
if (-not $steamPath) {
    Write-Bad "❌ Steam installation not found in registry."
    exit 1
}
Write-Ok "✅ Steam path: $steamPath"

$libraries = Get-SteamLibraries $steamPath
Write-Info "📚 Libraries found:"
$libraries | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

$manifestPath = Find-AppManifest -libraries $libraries -appId $AppID
if (-not $manifestPath) {
    Write-Bad "❌ AppID $AppID not found in any Steam library (no appmanifest_$AppID.acf)."
    exit 1
}
Write-Ok "✅ Found manifest: $manifestPath"

$installDir = Get-InstallDirFromAcf $manifestPath
if (-not $installDir) {
    Write-Bad "❌ Could not parse 'installdir' from manifest."
    exit 1
}
Write-Ok "📦 installdir: $installDir"

# Determine which library this manifest belongs to
$libRoot = Split-Path (Split-Path $manifestPath -Parent) -Parent  # ...\steamapps\ -> library root
$gamePath = Join-Path $libRoot "steamapps\common\$installDir"

Write-Ok "📁 Game folder: $gamePath"
if (-not (Test-Path $gamePath)) {
    Write-Bad "❌ Game folder does not exist: $gamePath"
    exit 1
}

# Download from GitHub recursively into the game folder
try {
    Download-GitHubContentsRecursive -Owner $RepoOwner -Repo $RepoName -BranchRef $Branch -PathInRepo $RepoPath -DestRoot $gamePath
    Write-Ok "✅ Patch files downloaded!"
} catch {
    Write-Bad "❌ GitHub download failed: $($_.Exception.Message)"
    exit 1
}

# Optional RAR extraction
if ($ExtractRar) {
    $unrarPath = Join-Path $gamePath "UnRAR.exe"
    if (-not (Test-Path $unrarPath)) {
        Write-Info "📦 UnRAR.exe not found. Downloading..."
        try {
            Download-File -url $UnrarUrl -outFile $unrarPath
            Write-Ok "✅ UnRAR.exe downloaded."
        } catch {
            Write-Warn "⚠️ Failed to download UnRAR.exe. Skipping extraction."
            $unrarPath = $null
        }
    }

    if ($unrarPath -and (Test-Path $unrarPath)) {
        $rarFiles = Get-ChildItem -Path $gamePath -Recurse -Filter "*.rar" -ErrorAction SilentlyContinue
        if (-not $rarFiles) {
            Write-Warn "ℹ️ No .rar files found to extract."
        } else {
            foreach ($rar in $rarFiles) {
                $dest = $rar.DirectoryName
                Write-Info "🔍 Extracting: $($rar.FullName) -> $dest"
                try {
                    $p = Start-Process -FilePath $unrarPath `
                        -ArgumentList @("x", "`"$($rar.FullName)`"", "`"$dest`"", "-y", "-inul") `
                        -Wait -PassThru -WindowStyle Hidden
                    if ($p.ExitCode -eq 0) {
                        Remove-Item $rar.FullName -Force
                        Write-Ok "🗑️ Deleted: $($rar.Name)"
                    } else {
                        Write-Warn "⚠️ Extraction failed (exit code $($p.ExitCode)): $($rar.Name)"
                    }
                } catch {
                    Write-Warn "⚠️ Error extracting $($rar.Name): $($_.Exception.Message)"
                }
            }
            Write-Ok "✅ RAR extraction complete!"
        }
    }
}

Write-Ok "🎉 Done for AppID: $AppID"
exit 0

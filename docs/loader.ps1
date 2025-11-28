<#
loader.ps1 (v2) - Mod/patch file downloader (no DRM bypass logic)

- Gets AppID from -AppID or env:PATCHID
- Detects Steam path and fixes common "Program Files (x86)" vs "... \Steam" mismatch
- Reads ALL Steam libraries from libraryfolders.vdf
- Locates appmanifest_{AppID}.acf
- Parses installdir
- Downloads files from GitHub branch (default branch = AppID), recursively
- Optional: extracts .rar if -ExtractRar
#>

[CmdletBinding()]
param(
  [string] $AppID,
  [string] $RepoOwner = "3circledesign",
  [string] $RepoName  = "intestingpowershell",
  [string] $RepoPath  = "",          # "" = repo root
  [string] $Branch,                  # default = AppID
  [switch] $ExtractRar,
  [string] $UnrarUrl = "https://raw.githubusercontent.com/3circledesign/intestingpowershell/main/UnRAR.exe"
)

$ErrorActionPreference = "Stop"

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Bad($m){ Write-Host $m -ForegroundColor Red }

function Normalize-Dir([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return $null }
  $p = $p.Trim().Trim('"')
  try { return [IO.Path]::GetFullPath($p) } catch { return $p }
}

function Get-SteamInstallPath {
  $candidates = @()

  foreach ($key in @(
    "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
    "HKLM:\SOFTWARE\Valve\Steam",
    "HKCU:\Software\Valve\Steam"
  )) {
    try {
      $v = (Get-ItemProperty $key -ErrorAction SilentlyContinue)
      if ($v.InstallPath) { $candidates += $v.InstallPath }
      if ($v.SteamPath)   { $candidates += $v.SteamPath }
    } catch {}
  }

  $candidates = $candidates | ForEach-Object { Normalize-Dir $_ } | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
  if (-not $candidates) { return $null }

  $p = $candidates[0]

  # Fix common issue: registry points to "...Program Files (x86)" but Steam is inside "\Steam"
  if (-not (Test-Path (Join-Path $p "Steam.exe")) -and (Test-Path (Join-Path $p "Steam\Steam.exe"))) {
    $p = Join-Path $p "Steam"
  }

  return $p
}

function Get-SteamLibraries([string]$steamPath) {
  $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

  $steamPath = Normalize-Dir $steamPath
  if ($steamPath) { $null = $set.Add($steamPath) }

  $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
  if (-not (Test-Path $vdf)) { return $set.ToArray() }

  $txt = Get-Content $vdf -Raw

  # new format: "1" { "path" "D:\\SteamLibrary" ... }
  foreach ($m in ([regex]'"(?:\d+)"\s*\{\s*[^}]*?"path"\s*"([^"]+)"').Matches($txt)) {
    $p = Normalize-Dir $m.Groups[1].Value
    if ($p -and (Test-Path $p)) { $null = $set.Add($p) }
  }

  # old format: "1" "D:\\SteamLibrary"
  foreach ($m in ([regex]'"(?:\d+)"\s*"([^"]+)"').Matches($txt)) {
    $p = Normalize-Dir $m.Groups[1].Value
    if ($p -and (Test-Path $p)) { $null = $set.Add($p) }
  }

  return $set.ToArray()
}

function Find-AppManifest([string[]]$libraries,[string]$appId) {
  foreach ($lib in $libraries) {
    if ([string]::IsNullOrWhiteSpace($lib)) { continue }
    $candidate = Join-Path $lib "steamapps\appmanifest_$appId.acf"
    if (Test-Path $candidate) { return $candidate }
  }
  return $null
}

function Get-InstallDirFromAcf([string]$acfPath) {
  $acf = Get-Content $acfPath -Raw
  if ($acf -match '"installdir"\s+"([^"]+)"') { return $matches[1] }
  return $null
}

function Invoke-GitHubJson([string]$url) {
  Invoke-RestMethod -Uri $url -Headers @{
    "User-Agent"="Steam-Mod-Downloader/2.0"
    "Accept"="application/vnd.github+json"
  } -Method Get
}

function Download-File([string]$url,[string]$outFile) {
  $outFile = Normalize-Dir $outFile
  $dir = Split-Path -LiteralPath $outFile -Parent
  if ([string]::IsNullOrWhiteSpace($dir)) { throw "Output directory is empty for outFile='$outFile'" }
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

  Invoke-WebRequest -Uri $url -Headers @{ "User-Agent"="Steam-Mod-Downloader/2.0" } -OutFile $outFile
}

function Download-GitHubContentsRecursive {
  param(
    [string]$Owner,[string]$Repo,[string]$BranchRef,[string]$PathInRepo,[string]$DestRoot
  )

  if ([string]::IsNullOrWhiteSpace($DestRoot)) { throw "DestRoot is empty" }

  $apiUrl =
    if ([string]::IsNullOrWhiteSpace($PathInRepo)) {
      "https://api.github.com/repos/$Owner/$Repo/contents?ref=$BranchRef"
    } else {
      $p = $PathInRepo.TrimStart("/")
      "https://api.github.com/repos/$Owner/$Repo/contents/$p?ref=$BranchRef"
    }

  $items = Invoke-GitHubJson $apiUrl

  # File response = object, directory response = array
  if ($items -and $items.type -eq "file") {
    $rel = if ([string]::IsNullOrWhiteSpace($PathInRepo)) { $items.name } else { $PathInRepo }
    $dest = Join-Path $DestRoot $rel
    Info "⬇️  Downloading file: $rel"
    Download-File -url $items.download_url -outFile $dest
    return
  }

  foreach ($item in $items) {
    if ($item.type -eq "file") {
      $rel = if ([string]::IsNullOrWhiteSpace($PathInRepo)) { $item.name } else { Join-Path $PathInRepo $item.name }
      $dest = Join-Path $DestRoot $rel
      Info "⬇️  Downloading: $rel"
      Download-File -url $item.download_url -outFile $dest
    }
    elseif ($item.type -eq "dir") {
      $next = if ([string]::IsNullOrWhiteSpace($PathInRepo)) { $item.name } else { Join-Path $PathInRepo $item.name }
      Download-GitHubContentsRecursive -Owner $Owner -Repo $Repo -BranchRef $BranchRef -PathInRepo $next -DestRoot $DestRoot
    }
  }
}

# -------- main --------
if (-not $AppID) { if ($env:PATCHID) { $AppID = $env:PATCHID } }
if (-not $AppID) { Bad "❌ Error: No AppID provided. Use -AppID or set env:PATCHID."; exit 1 }
if (-not $Branch) { $Branch = $AppID }

Info "🚀 Running patch downloader for AppID: $AppID"
Info "🔧 Repo: $RepoOwner/$RepoName | Branch: $Branch | Path: '$RepoPath'"

$steamPath = Get-SteamInstallPath
if (-not $steamPath) { Bad "❌ Steam installation not found!"; exit 1 }
Ok "✅ Steam path: $steamPath"

$libraries = Get-SteamLibraries $steamPath
Info "📚 Libraries found:"
$libraries | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

$manifestPath = Find-AppManifest -libraries $libraries -appId $AppID
if (-not $manifestPath) { Bad "❌ AppID $AppID not found (no appmanifest_$AppID.acf)."; exit 1 }
Ok "✅ Found manifest: $manifestPath"

$installDir = Get-InstallDirFromAcf $manifestPath
if (-not $installDir) { Bad "❌ Could not parse 'installdir' from manifest."; exit 1 }
Ok "📦 installdir: $installDir"

# FIX: derive library root safely (avoids empty string bugs)
$steamappsDir = Split-Path -LiteralPath $manifestPath -Parent
if ([string]::IsNullOrWhiteSpace($steamappsDir)) { throw "steamappsDir empty (manifestPath='$manifestPath')" }

$libRoot = (Get-Item -LiteralPath $steamappsDir).Parent.FullName
$libRoot = Normalize-Dir $libRoot
if ([string]::IsNullOrWhiteSpace($libRoot)) { throw "libRoot empty (steamappsDir='$steamappsDir')" }

$gamePath = Join-Path $libRoot ("steamapps\common\" + $installDir)
Ok "📁 Game folder: $gamePath"
if (-not (Test-Path $gamePath)) { Bad "❌ Game folder does not exist: $gamePath"; exit 1 }

try {
  Download-GitHubContentsRecursive -Owner $RepoOwner -Repo $RepoName -BranchRef $Branch -PathInRepo $RepoPath -DestRoot $gamePath
  Ok "✅ Patch files downloaded!"
} catch {
  Bad "❌ GitHub download failed: $($_.Exception.Message)"
  exit 1
}

if ($ExtractRar) {
  $unrarPath = Join-Path $gamePath "UnRAR.exe"
  if (-not (Test-Path $unrarPath)) {
    Info "📦 Downloading UnRAR.exe..."
    try { Download-File -url $UnrarUrl -outFile $unrarPath; Ok "✅ UnRAR.exe downloaded." }
    catch { Warn "⚠️ Failed to download UnRAR.exe. Skipping extraction."; $unrarPath = $null }
  }

  if ($unrarPath -and (Test-Path $unrarPath)) {
    $rarFiles = Get-ChildItem -Path $gamePath -Recurse -Filter "*.rar" -ErrorAction SilentlyContinue
    if ($rarFiles) {
      foreach ($rar in $rarFiles) {
        $dest = $rar.DirectoryName
        Info "🔍 Extracting: $($rar.FullName) -> $dest"
        try {
          $p = Start-Process -FilePath $unrarPath -ArgumentList @("x","`"$($rar.FullName)`"","`"$dest`"","-y","-inul") -Wait -PassThru -WindowStyle Hidden
          if ($p.ExitCode -eq 0) { Remove-Item $rar.FullName -Force; Ok "🗑️ Deleted: $($rar.Name)" }
          else { Warn "⚠️ Extraction failed (exit code $($p.ExitCode)): $($rar.Name)" }
        } catch { Warn "⚠️ Error extracting $($rar.Name): $($_.Exception.Message)" }
      }
      Ok "✅ RAR extraction complete!"
    } else {
      Warn "ℹ️ No .rar files found to extract."
    }
  }
}

Ok "🎉 Done for AppID: $AppID"
exit 0

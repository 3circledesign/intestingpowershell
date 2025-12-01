cls
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# ================== ASCII Banner ==================
Write-Host -NoNewline "          _____                _____                    _____                    _____                    _____          `r" -ForegroundColor Blue
Write-Host -NoNewline "         /\    \              /\    \                  /\    \                  /\    \                  /\    \         `r" -ForegroundColor Blue
Write-Host -NoNewline "        /::\    \            /::\    \                /::\    \                /::\    \                /::\____\        `r" -ForegroundColor Blue
Write-Host -NoNewline "       /::::\    \           \:::\    \              /::::\    \              /::::\    \              /::::|   |        `r" -ForegroundColor Blue
Write-Host -NoNewline "      /::::::\    \           \:::\    \            /::::::\    \            /::::::\    \            /:::::|   |        `r" -ForegroundColor Blue
Write-Host -NoNewline "     /:::/\:::\    \           \:::\    \          /:::/\:::\    \          /:::/\:::\    \          /::::::|   |        `r" -ForegroundColor Blue
Write-Host -NoNewline "    /:::/__\:::\    \           \:::\    \        /:::/__\:::\    \        /:::/__\:::\    \        /:::/|::|   |        `r" -ForegroundColor Blue
Write-Host -NoNewline "    \:::\   \:::\    \          /::::\    \      /::::\   \:::\    \      /::::\   \:::\    \      /:::/ |::|   |        `r" -ForegroundColor Blue
Write-Host -NoNewline "  ___\:::\   \:::\    \        /::::::\    \    /::::::\   \:::\    \    /::::::\   \:::\    \    /:::/  |::|___|______  `r" -ForegroundColor Blue
Write-Host -NoNewline " /\   \:::\   \:::\    \      /:::/\:::\    \  /:::/\:::\   \:::\    \  /:::/\:::\   \:::\    \  /:::/   |::::::::\    \ `r" -ForegroundColor Blue
Write-Host -NoNewline "/::\   \:::\   \:::\____\    /:::/  \:::\____\/:::/__\:::\   \:::\____\/:::/  \:::\   \:::\____\/:::/    |:::::::::\____\`r" -ForegroundColor Blue
Write-Host -NoNewline "\:::\   \:::\   \::/    /   /:::/    \::/    /\:::\   \:::\   \::/    /\::/    \:::\  /:::/    /\::/    / ~~~~~/:::/    /`r" -ForegroundColor Blue
Write-Host -NoNewline " \:::\   \:::\   \/____/   /:::/    / \/____/  \:::\   \:::\   \/____/  \/____/ \:::\/:::/    /  \/____/      /:::/    / `r" -ForegroundColor Blue
Write-Host -NoNewline "  \:::\   \:::\    \      /:::/    /            \:::\   \:::\    \               \::::::/    /               /:::/    /  `r" -ForegroundColor Blue
Write-Host -NoNewline "   \:::\   \:::\____\    /:::/    /              \:::\   \:::\____\               \::::/    /               /:::/    /   `r" -ForegroundColor Blue
Write-Host -NoNewline "    \:::\  /:::/    /    \::/    /                \:::\   \::/    /               /:::/    /               /:::/    /    `r" -ForegroundColor Blue
Write-Host -NoNewline "     \:::\/:::/    /      \/____/                  \:::\   \/____/               /:::/    /               /:::/    /     `r" -ForegroundColor Blue
Write-Host -NoNewline "      \::::::/    /                                 \:::\    \                  /:::/    /               /:::/    /      `r" -ForegroundColor Blue
Write-Host -NoNewline "       \::::/    /                                   \:::\____\                /:::/    /               /:::/    /       `r" -ForegroundColor Blue
Write-Host -NoNewline "        \::/    /                                     \::/    /                \::/    /                \::/    /        `r" -ForegroundColor Blue
Write-Host -NoNewline "         \/____/                                       \/____/                  \/____/                  \/____/         `r" -ForegroundColor Blue

# ================== Helper Functions ==================
function Show-Header($title) {
    $line = "═" * ($title.Length + 4)
    Write-Host "╔$line╗" -ForegroundColor Cyan
    Write-Host "║  $title  ║" -ForegroundColor Cyan
    Write-Host "╚$line╝" -ForegroundColor Cyan
}

function Show-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Yellow }
function Show-Success($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Show-Error($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Show-Progress($current, $total, $msg) {
    $percent = [int](($current / $total) * 100)
    $barLength = 40
    $filled = [int](($percent / 100) * $barLength)
    $bar = ("█" * $filled) + ("-" * ($barLength - $filled))
    Write-Host -NoNewline "`r[$bar] $percent% - $msg"
    if ($current -eq $total) { Write-Host "" }
}

# ================== Step 0: AppID ==================
if (-not $AppID) {
    Show-Error "AppID not provided."
    exit
}
Show-Header "Onennabe Patcher"
Show-Info "Using AppID: $AppID"

# ================== Step 1: Detect Steam Path ==================
Show-Header "Detecting Steam Installation"
$steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (-not $steamPath) {
    $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
}
if (-not $steamPath) {
    Show-Error "Steam installation not found!"
    exit
}
Show-Success "Steam path detected: $steamPath"

# ================== Step 2: Find appmanifest ==================
Show-Header "Locating App Manifest"
Show-Info "Checking targetted folder..."
$appManifest = $null
$mainSteamApps = Join-Path $steamPath "steamapps"
if (Test-Path $mainSteamApps) {
    $acf = Get-ChildItem -Path $mainSteamApps -Filter "appmanifest_$AppID.acf" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($acf) { $appManifest = $acf }
}
if (-not $appManifest) {
    Show-Info "Not in main Steam folder. Scanning mounted drives..."
    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    foreach ($drive in $drives) {
        if (-not (Test-Path $drive)) { continue }
        $libs = @((Join-Path $drive "SteamLibrary"), (Join-Path $drive "Steam"))
        foreach ($lib in $libs) {
            if (-not (Test-Path $lib)) { continue }
            $steamApps = Join-Path $lib "steamapps"
            if (-not (Test-Path $steamApps)) { continue }
            $acf = Get-ChildItem -Path $steamApps -Filter "appmanifest_$AppID.acf" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($acf) { $appManifest = $acf; break }
        }
        if ($appManifest) { break }
    }
}
if (-not $appManifest) {
    Show-Error "AppID $AppID not found in any Steam library folder!"
    exit
}
Show-Success "Found manifest: $($appManifest.FullName)"

# ================== Step 3 & 4: Game Path ==================
$acfContent = Get-Content $appManifest.FullName
$installDirLine = $acfContent | Where-Object { $_ -match '"installdir"' }
$installDir = ($installDirLine -split '"')[3]
$libraryRoot = Split-Path (Split-Path $appManifest.FullName -Parent) -Parent
$gamePath = Join-Path (Join-Path $libraryRoot "steamapps\common") $installDir
Show-Success "Detected game folder: $gamePath"

# ================== Step 5: Fetch GitHub Source ==================
Show-Header "Fetching Patch Source"
$branch     = $AppID
$repo1Owner = "3circledesign"
$repo1Name  = "intestingpowershell"
$repo2Owner = "CrabBerjoget"
$repo2Name  = "intestingpowershell"

function Get-GitHubFiles($owner, $name, $branch) {
    $url = "https://api.github.com/repos/$owner/$name/contents/?ref=$branch"
    try { return Invoke-RestMethod -Uri $url -UseBasicParsing -Headers @{ "User-Agent" = "PowerShell" } }
    catch { return $null }
}

Show-Info "Fetching Source..."
$filesList = Get-GitHubFiles $repo1Owner $repo1Name $branch
if (-not $filesList) {
    Show-Info "Refetching Source..."
    $filesList = Get-GitHubFiles $repo2Owner $repo2Name $branch
    if (-not $filesList) { Show-Error "No Patch for $branch yet!"; exit }
}
Show-Success "Patch Found."

# ================== Step 6: Download Files ==================
Show-Header "Downloading Patch Files"
$runspacePool = [runspacefactory]::CreateRunspacePool(1, 10)
$runspacePool.Open()
$runspaces = @()
$totalFiles = $filesList.Count

for ($i = 0; $i -lt $totalFiles; $i++) {
    $file = $filesList[$i]
    if ($file.type -ne "file") { continue }

    $fileUrl = $file.download_url
    $fileName = $file.name
    $destination = Join-Path $gamePath $fileName

    Show-Progress ($i+1) $totalFiles "Downloading $fileName"

    $ps = [powershell]::Create()
    $ps.RunspacePool = $runspacePool

    $ps.AddScript({
        param($url, $out)
        try {
            # Suppress all runspace output streams
            Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing *> $null
            Write-Host "[OK] Downloaded $out" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Failed: $out" -ForegroundColor Red
        }
    }).AddArgument($fileUrl).AddArgument($destination)

    # Save handle before any piping
    $handle = $ps.BeginInvoke()
    $runspaces += @{ PowerShell = $ps; Handle = $handle }
}

# Wait for all downloads and suppress EndInvoke output completely
foreach ($r in $runspaces) {
    if ($r.Handle) { $null = $r.PowerShell.EndInvoke($r.Handle) }
    $r.PowerShell.Dispose()
}
$runspacePool.Close()
$runspacePool.Dispose()
Show-Success "All downloads completed!"

# ================== Step 7: Ensure UnRAR.exe ==================
Show-Header "Preparing for Extraction"
$unrarPath = Join-Path $gamePath "UnRAR.exe"
if (-not (Test-Path $unrarPath)) {
    Show-Info "Downloading UnRAR.exe..."
    try { Invoke-WebRequest -Uri "https://github.com/CrabBerjoget/intestingpowershell/raw/main/UnRAR.exe" -OutFile $unrarPath *> $null }
    catch { Show-Error "Failed to download UnRAR.exe. Extraction will be skipped."; $unrarPath = $null }
}

# ================== Step 8: Extract RAR Files ==================
Show-Header "Extracting RAR Files"
$rarFiles = Get-ChildItem -Path $gamePath -Recurse -Filter *.rar
$rarGroups = @{}
foreach ($rar in $rarFiles) {
    $baseName = ($rar.Name -replace '\.part\d+\.rar$', '') -replace '\.rar$', ''
    if (-not $rarGroups.ContainsKey($baseName)) { $rarGroups[$baseName] = @() }
    $rarGroups[$baseName] += $rar
}

$runspacePool = [runspacefactory]::CreateRunspacePool(1, 5)
$runspacePool.Open()
$runspaces = @()

foreach ($group in $rarGroups.GetEnumerator()) {
    $firstRar = $group.Value | Sort-Object FullName | Select-Object -First 1
    if ($unrarPath -and (Test-Path $unrarPath)) {
        Show-Info "Queueing extraction: $($firstRar.FullName)"

        $ps = [powershell]::Create()
        $ps.RunspacePool = $runspacePool

        $ps.AddScript({
            param($firstRarPath, $rarSet, $unrarExe)
            $dest = Split-Path $firstRarPath -Parent
            # Suppress all output streams from extraction
            Start-Process -FilePath $unrarExe -ArgumentList "x `"$firstRarPath`" `"$dest`" -y -inul" -WindowStyle Hidden -Wait *> $null
            foreach ($rarFile in $rarSet) {
                if (Test-Path $rarFile.FullName) { Remove-Item $rarFile.FullName -Force }
            }
        }).AddArgument($firstRar.FullName).AddArgument($group.Value).AddArgument($unrarPath)

        $handle = $ps.BeginInvoke()
        $runspaces += @{ PowerShell = $ps; Handle = $handle }
    }
}

foreach ($r in $runspaces) {
    if ($r.Handle) { $null = $r.PowerShell.EndInvoke($r.Handle) }
    $r.PowerShell.Dispose()
}
$runspacePool.Close()
$runspacePool.Dispose()
Show-Success "File extraction complete and cache cleaned up!"
Show-Success "Happy Gaming!"

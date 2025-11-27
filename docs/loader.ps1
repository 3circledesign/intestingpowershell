# Read patch ID from environment variable
$patchID = $env:PATCHID

if (-not $patchID) {
    Write-Host "Please set environment variable PATCHID"
    exit
}

$mapUrl = "https://crabberjoget.github.io/intestingpowershell/index.json"
$map = irm $mapUrl

if (-not $map.$patchID) {
    Write-Host "Patch ID '$patchID' not found."
    exit
}

irm $map.$patchID | iex

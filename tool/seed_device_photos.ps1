<#
  seed_device_photos.ps1 - put a handful of real photos in a device's gallery
  so the picker-driven flows (import, Photo Grid create, filters, AI cut-out)
  can be exercised by hand.

  Usage:
    ./tool/seed_device_photos.ps1                  # first connected device
    ./tool/seed_device_photos.ps1 -Device emulator-5554
    ./tool/seed_device_photos.ps1 -Clean           # remove them again

  The photos are downloaded from Lorem Picsum (Unsplash-sourced, free to use)
  into build/ and pushed to /sdcard/Pictures/ChromisSamples. They are TEST
  FIXTURES ONLY - nothing here is bundled into the app, so the repo's
  MIT/BSD/Apache/OFL rule for shipped assets is untouched.

  A spread of subjects on purpose: landscapes with big skies exercise the
  vignette and HDR, animals on plain backgrounds exercise the cut-out and the
  contour stroke, and the low-light portrait exercises shadow lifting.
#>
param(
  [string]$Device = "",
  [switch]$Clean
)
$ErrorActionPreference = "Continue"
Set-Location (Split-Path $PSScriptRoot -Parent)

$remote = "/sdcard/Pictures/ChromisSamples"
$local = "build/device-samples"

# Lorem Picsum ids, chosen by eye for subject coverage.
$photos = [ordered]@{
  "landscape_fjord"     = 1015
  "landscape_canyon"    = 1016
  "landscape_waterfall" = 1039
  "landscape_valley"    = 1043
  "animal_eagle"        = 1024
  "animal_pug"          = 1025
  "animal_lion"         = 1074
  "animal_walrus"       = 1084
  "animal_puppy"        = 237
  "animal_bear"         = 433
  "nature_waterlily"    = 306
  "portrait_sparkler"   = 660
}

$adb = @("adb")
if ($Device) { $adb = @("adb", "-s", $Device) }

# adb reports its transfer progress on stderr, which some shells surface as a
# terminating error; the try/catch keeps ordinary output from aborting the run
# (same convention as e2e.ps1).
function Invoke-Adb {
  param([string[]]$AdbArgs)
  try {
    return & $adb[0] @($adb[1..($adb.Length - 1)] + $AdbArgs)
  } catch {
    return @()
  }
}

if ($Clean) {
  Write-Output "==> Removing $remote"
  Invoke-Adb @("shell", "rm", "-rf", $remote) | Out-Null
  Invoke-Adb @("shell", "content", "call", "--uri",
    "content://media/external/images/media", "--method", "scan_volume",
    "--arg", "external") | Out-Null
  Write-Output "Done."
  return
}

New-Item -ItemType Directory -Force -Path $local | Out-Null

Write-Output "==> Downloading $($photos.Count) sample photos..."
foreach ($name in $photos.Keys) {
  $file = Join-Path $local "$name.jpg"
  if (Test-Path $file) { continue }
  $url = "https://picsum.photos/id/$($photos[$name])/1600/1067"
  try {
    Invoke-WebRequest -Uri $url -OutFile $file -MaximumRedirection 5
  } catch {
    Write-Output "    skipped $name ($($_.Exception.Message))"
  }
}

Write-Output "==> Pushing to $remote"
Invoke-Adb @("shell", "mkdir", "-p", $remote) | Out-Null
Get-ChildItem "$local/*.jpg" | ForEach-Object {
  # -q: adb reports transfer progress on stderr, which shows up as noise (or a
  # spurious error) in most PowerShell hosts.
  Invoke-Adb @("push", "-q", $_.FullName, "$remote/") | Out-Null
}

# Without a scan the files exist on disk but the photo picker cannot see them.
Write-Output "==> Rescanning the media store"
Invoke-Adb @("shell", "content", "call", "--uri",
  "content://media/external/images/media", "--method", "scan_volume",
  "--arg", "external") | Out-Null

$listed = Invoke-Adb @("shell", "content", "query", "--uri",
  "content://media/external/images/media", "--projection", "_display_name")
$count = ($listed | Select-String -Pattern "animal_|landscape_|nature_|portrait_").Count
Write-Output "Done - $count sample photos visible to the picker."

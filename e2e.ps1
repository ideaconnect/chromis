<#
  e2e.ps1 — run the Gherkin/BDD end-to-end tests on a connected device and open
  an HTML report.

  Usage:
    ./e2e.ps1                  # auto-pick the connected Android device
    ./e2e.ps1 -Device a93d4403 # target a specific device id
    ./e2e.ps1 -SkipGen         # skip regenerating tests from .feature files
    ./e2e.ps1 -NoOpen          # don't open the HTML report at the end

  These tests install + drive the real app, so a device must be connected. On
  Xiaomi/MIUI, accept the "Install via USB" prompt on the phone when it appears.
  Running this script IS the go-ahead to use the device.
#>
param(
  [string]$Device = "",
  [switch]$SkipGen,
  [switch]$NoOpen
)
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

$reportDir = "build/e2e-report"
$results = "$reportDir/results.json"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

# Native calls are wrapped in try/catch: some shells surface dart/flutter's
# ordinary stderr as a terminating error and would otherwise abort the script
# mid-flow. Progress uses Write-Output so it stays visible when captured/piped.

# 1. Regenerate the *_test.dart files from the .feature files.
if (-not $SkipGen) {
  Write-Output "==> Generating BDD tests from .feature files..."
  try { dart run build_runner build } catch { }
}

# 2. Resolve a target device (first connected Android unless -Device given).
if (-not $Device) {
  try {
    $devs = flutter devices --machine | Out-String | ConvertFrom-Json
    $pick = $devs | Where-Object { $_.targetPlatform -like "android*" } | Select-Object -First 1
    if ($pick) { $Device = $pick.id }
  } catch { }
}
if (-not $Device) {
  Write-Output ""
  Write-Output "No Android device detected. Connect your phone (USB debugging on),"
  Write-Output "then re-run ./e2e.ps1. These E2E tests need the device - nothing ran."
  exit 1
}

# 3. Run the BDD integration tests on the device, streaming JSON to a file while
#    the console shows live progress.
Write-Output "==> Running E2E on device: $Device"
Write-Output "    (accept the 'Install via USB' prompt on the phone if it appears)"
try { flutter test integration_test/bdd -d $Device --file-reporter "json:$results" } catch { }
$testExit = $LASTEXITCODE
if ($null -eq $testExit) { $testExit = 0 }

# 4. Build the human report (console summary + HTML + Markdown).
if (Test-Path $results) {
  try { dart run tool/e2e_report.dart $results $Device } catch { }
  if (-not $NoOpen) { try { Start-Process (Resolve-Path "$reportDir/index.html") } catch { } }
} else {
  Write-Output "No results file produced - the run stopped before any test ran (is the device connected?)."
}

exit $testExit

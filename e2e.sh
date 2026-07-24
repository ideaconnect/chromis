#!/usr/bin/env bash
# e2e.sh - run the Gherkin/BDD end-to-end tests on a connected device and write
# an HTML report (macOS/Linux/CI companion to e2e.ps1).
#
# Usage:
#   ./e2e.sh                # use the default connected device
#   ./e2e.sh <deviceId>     # target a specific device
#
# These tests install + drive the real app, so a device must be connected.
set -euo pipefail
cd "$(dirname "$0")"

DEVICE="${1:-}"
REPORT_DIR="build/e2e-report"
RESULTS="$REPORT_DIR/results.json"
mkdir -p "$REPORT_DIR"

echo "==> Generating BDD tests from .feature files..."
dart run build_runner build

DEV_ARG=()
if [ -n "$DEVICE" ]; then DEV_ARG=(-d "$DEVICE"); fi

echo "==> Running E2E tests..."
set +e
flutter test integration_test/bdd "${DEV_ARG[@]}" --file-reporter "json:$RESULTS"
TEST_EXIT=$?
set -e

if [ -f "$RESULTS" ]; then
  dart run tool/e2e_report.dart "$RESULTS" "${DEVICE:-connected device}"
else
  echo "No results file produced - the run likely failed before any test."
fi

exit $TEST_EXIT

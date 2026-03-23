#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16e,OS=26.2}"

cd "$ROOT_DIR"

echo "Resetting simulator state..."
xcrun simctl shutdown all || true
xcrun simctl erase all || true

echo "Resetting DerivedData at $DERIVED_DATA_PATH..."
mkdir -p "$DERIVED_DATA_PATH"
find "$DERIVED_DATA_PATH" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

ENABLE_CODE_COVERAGE="${ENABLE_CODE_COVERAGE:-NO}"

COMMON_ARGS=(
  -project RediM8.xcodeproj
  -scheme RediM8
  -destination "$DESTINATION"
  -parallel-testing-enabled NO
  -maximum-concurrent-test-simulator-destinations 1
  -maximum-parallel-testing-workers 1
  -enableCodeCoverage "$ENABLE_CODE_COVERAGE"
  CODE_SIGNING_ALLOWED=NO
)

echo "Running unit and integration tests..."
xcodebuild test "${COMMON_ARGS[@]}" -only-testing:RediM8Tests

echo "Resetting simulator state before UI tests..."
xcrun simctl shutdown all || true

echo "Running UI tests..."
xcodebuild test "${COMMON_ARGS[@]}" -only-testing:RediM8UITests

#!/bin/zsh
# Runs `swift test` in every package and builds every tool. Usage: scripts/test-all.sh [--app]
# --app also regenerates the Xcode project and builds the app.
set -euo pipefail
root=${0:A:h:h}
failed=()
for dir in "$root"/Packages/*(/); do
  echo "── swift test: ${dir:t}"
  (cd "$dir" && swift test) || failed+=("${dir:t}")
done
for dir in "$root"/Tools/*(/); do
  echo "── swift build: ${dir:t}"
  (cd "$dir" && swift build) || failed+=("${dir:t}")
done
if [[ "${1:-}" == "--app" ]]; then
  echo "── xcodegen + xcodebuild"
  (cd "$root" && xcodegen && xcodebuild -project granite.xcodeproj -scheme granite -configuration Debug build -quiet) \
    || failed+=("app")
fi
if (( ${#failed} )); then
  echo "FAILED: ${failed[*]}"
  exit 1
fi
echo "all green"

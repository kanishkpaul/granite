#!/bin/zsh
# Runs `swift test` in every package and builds every tool. Usage: scripts/test-all.sh [--app]
# Also typechecks, tests and rebuilds the Editor bundle (App/Resources/editor).
# --app also regenerates the Xcode project and runs the app's tests (bridge round-trip).
# --ml also builds the MLX packages with xcodebuild (SwiftPM cannot compile MLX's Metal shaders).
# KBAIMLX and granite-ml are skipped otherwise: building MLX takes minutes.
set -euo pipefail
root=${0:A:h:h}
failed=()
mlx=(KBAIMLX granite-ml)
for dir in "$root"/Packages/*(/); do
  (( ${mlx[(Ie)${dir:t}]} )) && continue
  echo "── swift test: ${dir:t}"
  (cd "$dir" && swift test) || failed+=("${dir:t}")
done
for dir in "$root"/Tools/*(/); do
  (( ${mlx[(Ie)${dir:t}]} )) && continue
  if [[ -d "$dir/Tests" ]]; then
    echo "── swift test: ${dir:t}"
    (cd "$dir" && swift test) || failed+=("${dir:t}")
  else
    echo "── swift build: ${dir:t}"
    (cd "$dir" && swift build) || failed+=("${dir:t}")
  fi
done
echo "── Editor: typecheck, vitest, build"
(cd "$root/Editor" && pnpm install --frozen-lockfile --silent && pnpm typecheck && pnpm test && pnpm build) \
  || failed+=("Editor")
if [[ " $* " == *" --app "* ]]; then
  echo "── xcodegen + xcodebuild test"
  (cd "$root" && xcodegen && xcodebuild -project granite.xcodeproj -scheme granite -configuration Debug -skipMacroValidation -skipPackagePluginValidation test -quiet) \
    || failed+=("app")
fi
if [[ " $* " == *" --ml "* ]]; then
  echo "── xcodebuild: granite-ml (KBAIMLX + MLX)"
  (cd "$root/Tools/granite-ml" && xcodebuild -scheme granite-ml -destination 'platform=macOS,arch=arm64' \
    -skipMacroValidation -skipPackagePluginValidation build -quiet) || failed+=("granite-ml")
fi
if (( ${#failed} )); then
  echo "FAILED: ${failed[*]}"
  exit 1
fi
echo "all green"

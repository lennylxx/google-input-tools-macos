#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Build successfully before touching the installed input method. Preserve all user data.
xcodebuild -quiet -scheme GoogleInputTools -configuration Release \
  MACOSX_DEPLOYMENT_TARGET=12.0 CONFIGURATION_BUILD_DIR="$PWD/build/products" build "$@"

app_source="$PWD/build/products/GoogleInputTools.app"
app_destination="$HOME/Library/Input Methods/GoogleInputTools.app"
codesign --verify --deep --strict "$app_source"
if [ -d "$app_destination" ]; then
  backup_dir="$HOME/Library/Application Support/GoogleInputTools/Backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"
  ditto "$app_destination" "$backup_dir/GoogleInputTools.app"
fi
mkdir -p "$HOME/Library/Input Methods"
stage_dir="$(mktemp -d "$HOME/Library/Input Methods/.google-input-tools.XXXXXX")"
cleanup() {
  if [ ! -e "$app_destination" ] && [ -d "$stage_dir/previous.app" ]; then
    mv "$stage_dir/previous.app" "$app_destination"
  fi
  rm -rf "$stage_dir"
}
trap cleanup EXIT
ditto "$app_source" "$stage_dir/GoogleInputTools.app"
codesign --verify --deep --strict "$stage_dir/GoogleInputTools.app"
killall GoogleInputTools 2>/dev/null || true
if [ -d "$app_destination" ]; then
  mv "$app_destination" "$stage_dir/previous.app"
fi
mv "$stage_dir/GoogleInputTools.app" "$app_destination"
codesign --verify --deep --strict "$app_destination"
open -g "$app_destination"
echo "Installed to $app_destination (settings and learning data preserved)"

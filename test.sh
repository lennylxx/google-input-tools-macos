#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
xcodebuild -quiet \
    -project GoogleInputTools.xcodeproj \
    -scheme GoogleInputToolsTests \
    -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" \
    MACOSX_DEPLOYMENT_TARGET=12.0 test "$@"
echo "All tests passed."

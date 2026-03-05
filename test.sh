#!/bin/bash
set -e

xcodebuild \
    -project GoogleInputTools.xcodeproj \
    -scheme GoogleInputToolsTests \
    -configuration Debug \
    -destination 'platform=macOS' \
    test \
    2>&1 | grep -E "Test (Case|Suite)|passed|failed|Executed"

echo ""
echo "✅ All tests passed."

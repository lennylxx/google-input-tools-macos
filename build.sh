#!/bin/bash
set -e

killall -9 GoogleInputTools 2>/dev/null || true

rm -rf ~/Library/Input\ Methods/GoogleInputTools.swiftmodule
rm -rf ~/Library/Containers/com.lennylxx.inputmethod.GoogleInputTools/Data/
rm -rf ~/Library/Developer/Xcode/DerivedData/GoogleInputTools-*/
rm -rf ./build

xcodebuild -scheme GoogleInputTools build CONFIGURATION_BUILD_DIR=./build

rsync -a --delete ./build/GoogleInputTools.app/ ~/Library/Input\ Methods/GoogleInputTools.app/
echo "Installed to ~/Library/Input Methods/GoogleInputTools.app"

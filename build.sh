
killall -9 GoogleInputTools

rm -rf ~/Library/Input\ Methods/GoogleInputTools.app
rm -rf ~/Library/Input\ Methods/GoogleInputTools.swiftmodule
rm -rf ~/Library/Containers/com.lennylxx.inputmethod.GoogleInputTools/
rm -rf ~/Library/Developer/Xcode/DerivedData/GoogleInputTools-*/

xcodebuild -scheme GoogleInputTools build

ls -al ~/Library/Input\ Methods

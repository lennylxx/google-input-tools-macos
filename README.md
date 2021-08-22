# Google Input Tools for macOS

A *cloud* input method that use [Google Input Tools](https://www.google.com/inputtools/) as engine for macOS.

## How to use

1. Install Xcode 12.5.0+.

2. Clone and build the project

  ```
  git clone https://github.com/lennylxx/google-input-tools-macos
  cd google-input-tools-macos
  ./build.sh
  ``` 

> The output will be `~/Library/Input\ Methods/GoogleInputTools.app`

3. Open `System Preferences` -> `Keyboard` -> `Input Sources`, click `+` to add a new input method, choose `English` -> `GoogleInputTools`.

4. If you want to remove it, run below command

  ```
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.app
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.swiftmodule
  ```

## Progress

- [x] Basic input handling logic
- [x] Basic UI
- [x] Cloud engine
- [ ] Display tokenized input string and candidates
- [ ] Chinese/English mode toggle
- [ ] Input tool switching, such as Pinyin, Shuangpin, Wubi, etc.
- [ ] Settings for font name, font size, color, etc.
- [ ] Allow to use HTTP/SOCKS proxy
- [ ] Skin display
- [ ] Skin manager

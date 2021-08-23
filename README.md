# Google Input Tools for macOS

A *cloud* input method that uses [Google Input Tools](https://www.google.com/inputtools/) as engine for macOS.

## How to use

1. Install Xcode 12.5.0+.

2. Clone and build the project.

  ```
  git clone https://github.com/lennylxx/google-input-tools-macos
  cd google-input-tools-macos
  ./build.sh
  ``` 

> The output will be `~/Library/Input\ Methods/GoogleInputTools.app`

3. Open `System Preferences` -> `Keyboard` -> `Input Sources`, click `+` to add a new input method, choose `Chinese, Simplified` -> `GoogleInputTools`.

4. If you want to remove it, simply run below command.

  ```
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.app
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.swiftmodule
  ```

## Progress

- [x] Basic input handling logic
  - [x] `Space` key to commit first candidate
  - [x] `Return` key to ignore candidate and commit input string
  - [x] Number keys (`1`-`9`) to select candidate and commit
  - [ ] Continue to show new candidates after partial matched cancidate is selected and committed
  - [ ] `Backspace` key to remove last composing letter
  - [ ] Arrow keys to switch between highlighted candidate
- [x] Basic UI
  - [x] Numbered candidates
  - [x] Highlight current selected candidate
  - [ ] Group candidates into multiple pages, each page with at most `10` candidates
  - [ ] Page up and page down button
  - [ ] Draggable candidate window
- [x] Cloud engine
- [ ] Display tokenized input string and candidates
- [ ] Chinese/English mode toggle
- [ ] Input tool switching, such as Pinyin, Shuangpin, Wubi, etc.
- [ ] Settings for font name, font size, color, etc.
- [ ] Allow to use HTTP/SOCKS proxy
- [ ] Skin display
- [ ] Skin manager

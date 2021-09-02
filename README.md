# Google Input Tools for macOS

[![Build Status](https://github.com/lennylxx/google-input-tools-macos/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/lennylxx/google-input-tools-macos/actions/workflows/build.yml?query=branch%3Amain)

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

3. Open `System Preferences` -> `Keyboard` -> `Input Sources`, click `+` to add a new input method, choose `Chinese, Simplified` -> `Google Input Tools`.

4. If you want to remove it, simply run below command.

  ```
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.app
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.swiftmodule
  ```

## Screenshot
<img width="555" alt="screenshot" src="https://user-images.githubusercontent.com/5811576/131733470-c946efa3-0f80-4227-a4b1-9d047f51f47b.png">

## Progress

- [x] Basic input handling logic
  - [x] `Space` key to commit first candidate
  - [x] `Return` key to ignore candidate and commit input string
  - [x] Number keys (`1`-`9`) to select candidate and commit
  - [x] Continue to show new candidates after partial matched candidate is selected and committed
  - [x] `Backspace` key to remove last composing letter
  - [x] `Esc` key to cancel composing
- [x] System UI
- [x] Basic custom UI
  - [x] Numbered candidates
  - [x] Highlight current selected candidate
  - [ ] Arrow keys to switch between highlighted candidate
  - [ ] Group candidates into multiple pages, each page with at most `10` candidates
  - [ ] Page up and page down button
  - [ ] Draggable candidate window
- [ ] Advanced custom UI
  - [ ] Display tokenized input string and candidates
  - [ ] Settings for font name, font size, color, etc.
  - [ ] Skin display
  - [ ] Skin manager
- [x] Cloud engine
  - [ ] Cancel previous unnecessary web requests to speed up
- [ ] Chinese/English mode toggle
- [ ] Fullwidth form of punctuation in Chinese mode
- [ ] Input tool switching, such as Pinyin, Shuangpin, Wubi, etc.
- [ ] Allow to use HTTP/SOCKS proxy

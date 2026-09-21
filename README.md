# Google Input Tools for macOS

[![Build Status](https://github.com/lennylxx/google-input-tools-macos/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/lennylxx/google-input-tools-macos/actions/workflows/build.yml?query=branch%3Amain)

A *cloud* input method that uses [Google Input Tools](https://www.google.com/inputtools/) as engine for macOS.

[修改记录](CHANGELOG.md)

## How to use

1. Use macOS 12 or later and install Xcode with a macOS 12 or newer SDK.

2. Clone and build the project.

  ```
  git clone https://github.com/lennylxx/google-input-tools-macos
  cd google-input-tools-macos
  ./build.sh
  ```

> The output will be `~/Library/Input\ Methods/GoogleInputTools.app`

3. Open the keyboard input-source settings in System Settings (or System Preferences), click `+` to add a new input method, and choose `Chinese, Simplified` -> `谷歌拼音`.

4. If you want to remove it, simply run below command.

  ```
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.app
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.swiftmodule
  ```

### Accuracy preferences

The default full-pinyin profile uses cloud-first ranking with a limited personal
boost, learns only when you choose a candidate other than the first one, requires
5 such selections, halves unused selection weight after 90 days, enables technical
terms, and requests 20 candidates. These settings are available in **设置…** (Settings)
in the input method menu. Candidate count is independent of the visible page size.

Cloud, cached, and offline candidates use the same ranking pipeline. Cache entries
are separated by input scheme and candidate count and are refreshed after 24 hours;
expired entries remain available as an offline fallback. Legacy caches and learning
tables remain on disk, but are not reused because their scheme and selection source
are unknown. Updating with `./build.sh` preserves settings and learning data.

**导入自定义词…** (Import phrases) accepts a UTF-8 `.txt` or `.tsv` file with one exact
full-pinyin key and phrase per line, separated by a tab (or space), for example:

```text
jiekou 接口
xiangmuming 项目名
```

Keys contain lowercase letters and optional syllable-separating apostrophes;
phrases may contain Chinese or English. Custom phrases are stored locally, apply
only to full pinyin, and supplement the first cloud candidate. The built-in
technical dictionary contains common software and media terms, not conversation
history. Press Return to commit the literal composing text.

Command, Control, and Option shortcuts pass through to the active application.
When confirming with Space before a request finishes, only candidates for that
same composition may be committed. Further typing or cancelling invalidates that
pending confirmation.

The settings window and its messages are in Simplified Chinese. Pinyin appears
inline in the active text field so the host can wrap it naturally. The custom
candidate window anchors to the host's marked-text position through IMK's
candidate-positioning API, rejects off-screen geometry, stays inside the current display,
and moves above the text when there is insufficient space below. While fetching
new candidates, it retains its last presentation without collapsing; outdated
candidates are immediately invalidated for selection. Window size and drag offset
reset when the composition ends.

### 中英文混输与打字容错

在中文模式直接输入英文即可，无需先按 Shift。输入 `british cou` 后按
**Tab**，可补全为 `British Council`；普通单词也支持前缀补全，例如
`configu` → `configuration`。英文单词之间的空格照常输入。明确的拼音仍优先
显示中文，中文空格选词保持原有行为；候选数字键也可以选词。

英文候选来自 macOS 本机英文词典与内置常见短语，覆盖范围取决于词典，
并非任意句子的语义续写。Shift+Tab、Command/Control/Option 快捷键仍交给宿主。

全拼打字容错会为相邻字母颠倒、漏字和多字提供额外候选，例如 `nihoa`、
`niho` 可选“你好”，`zhogn` 可选“中”。原输入的首选词保留，修正候选补到前排。
每次最多查询两种修正拼音，选中后按原输入长度上屏，避免残留错误字母。
目前只处理一次编辑距离内的常见错拼，不自动扩大平翘舌、n/l 等模糊音。

“设置…”中的 **英文联想** 和 **打字容错** 可分别关闭，默认开启。
输入法菜单会勾选当前的“中英混输”或“纯英文”模式，也可在菜单直接切换。
Shift 切到“纯英文”后，按键直接交给当前软件；中文和英文补全都在“中英混输”模式使用。

## Screenshot
<img width="555" alt="screenshot" src="https://user-images.githubusercontent.com/5811576/131733470-c946efa3-0f80-4227-a4b1-9d047f51f47b.png">
<img width="555" alt="screenshot2" src="https://github.com/user-attachments/assets/238ab1f2-8581-4232-bcf5-cd37fb3579d8">

## Progress

- [x] Basic input handling logic
  - [x] `Space` key to commit current highlighted candidate
  - [x] `Return` key to ignore candidate and commit input string
  - [x] Number keys (`1`-`9`) to select candidate and commit
  - [x] Continue to show new candidates after partial matched candidate is selected and committed
  - [x] `Backspace` key to remove last composing letter
  - [x] `Esc` key to cancel composing
  - [x] `-`/`↑` and `=`/`↓` keys to page up and page down candidate list respectively
  - [x] Arrow keys `←`/`→` to switch between highlighted candidate
- [x] Chinese/English mode toggle (`Shift` key)
- [x] System UI
- [x] Basic custom UI
  - [x] Numbered candidates
  - [x] Highlight current selected candidate
  - [x] Group candidates into multiple pages, each page with at most `9` candidates
  - [x] Page up and page down
  - [x] Draggable candidate window
- [ ] Advanced custom UI
  - [x] Inline marked pinyin with caret tracking across line wraps
  - [x] Screen-edge avoidance and stable window updates while fetching candidates
  - [x] Padded highlight box on selected candidate with rounded corners
  - [ ] Display tokenized input string and candidates
  - [ ] Settings for font name, font size, color, etc.
  - [ ] Skin display
  - [ ] Skin manager
- [x] Cloud engine
  - [x] Cancel previous unnecessary web requests on new keystroke to speed up
  - [x] In-memory LRU cache with SQLite persistence for candidate results
  - [x] Frequency-based smart re-ranking of candidates (configurable)
  - [x] Offline fallback: serve cached candidates when network is unavailable
  - [x] Predictive prefetch: pre-warm cache based on typing history
  - [x] Visual indicator (☁️) when candidates are fetched from the network
- [x] Preferences menu (Input scheme, UI mode, font size, page size, smart rerank)
- [x] Input tool switching, such as Pinyin, Shuangpin, Wubi, etc.
- [x] Fullwidth form of punctuation in Chinese mode
- [x] Allow to use HTTP/SOCKS proxy with optional authentication

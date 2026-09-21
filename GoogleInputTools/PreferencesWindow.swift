//
//  PreferencesWindow.swift
//  GoogleInputTools
//
//  Created by lennylxx on 3/5/26.
//

import Carbon
import Cocoa
import UniformTypeIdentifiers

class PreferencesWindow: NSWindow {

    static let shared = PreferencesWindow()

    private let inputSchemePopup = NSPopUpButton()
    private let rankingPopup = NSPopUpButton()
    private let learningSourcePopup = NSPopUpButton()
    private let learningThresholdPopup = NSPopUpButton()
    private let halfLifePopup = NSPopUpButton()
    private let candidateCountPopup = NSPopUpButton()
    private let technicalDictionaryCheckbox = NSButton()
    private let fullWidthPunctuationCheckbox = NSButton()
    private let englishCompletionCheckbox = NSButton()
    private let typoCorrectionCheckbox = NSButton()
    private let proxyTypePopup = NSPopUpButton()
    private let proxyHostField = NSTextField()
    private let proxyPortField = NSTextField()
    private let proxyUsernameField = NSTextField()
    private let proxyPasswordField = NSSecureTextField()
    private let uiModePopup = NSPopUpButton()
    private let fontSizePopup = NSPopUpButton()
    private let pageSizePopup = NSPopUpButton()
    private let paddingXPopup = NSPopUpButton()
    private let paddingYPopup = NSPopUpButton()
    private var transformedToForeground = false

    init() {
        super.init(
            contentRect: NSMakeRect(0, 0, 480, min(800, (NSScreen.main?.visibleFrame.height ?? 900) - 100)),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)

        self.title = "谷歌拼音设置"
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.hidesOnDeactivate = false
        self.center()

        setupUI()
        loadPreferences()
    }

    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    override func close() {
        super.close()
        restoreBackgroundApplication()
    }

    private func setupUI() {
        let scroll = NSScrollView(frame: self.contentRect(forFrameRect: self.frame))
        scroll.hasVerticalScroller = true
        scroll.autoresizingMask = [.width, .height]
        let contentView = NSView(frame: NSMakeRect(0, 0, 460, 889))
        scroll.documentView = contentView
        self.contentView = scroll
        scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, contentView.bounds.height - scroll.contentSize.height)))

        let margin: CGFloat = 20
        let labelWidth: CGFloat = 110
        let controlX = margin + labelWidth + 10
        let controlWidth: CGFloat = 280
        var y = contentView.bounds.height - margin - 30

        // MARK: - General settings

        let generalLabel = makeSectionLabel("常规与准确度", frame: NSMakeRect(margin, y, 200, 20))
        contentView.addSubview(generalLabel)
        y -= 28

        // Input scheme
        let schemeLabel = makeLabel("输入方案：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(schemeLabel)

        inputSchemePopup.frame = NSMakeRect(controlX, y, controlWidth, 24)
        inputSchemePopup.removeAllItems()
        for tool in InputTool.allCases {
            inputSchemePopup.addItem(withTitle: tool.displayName)
        }
        contentView.addSubview(inputSchemePopup)

        y -= 30

        func popupRow(_ title: String, _ popup: NSPopUpButton, _ items: [String]) {
            contentView.addSubview(makeLabel(title, frame: NSMakeRect(margin, y, labelWidth, 24)))
            popup.frame = NSMakeRect(controlX, y, controlWidth, 24)
            popup.addItems(withTitles: items)
            contentView.addSubview(popup)
            y -= 30
        }
        popupRow("候选排序：", rankingPopup, RankingMode.allCases.map(\.title))
        popupRow("学习来源：", learningSourcePopup, ["仅学习主动改选的候选", "学习所有上屏候选"])
        popupRow("学习门槛：", learningThresholdPopup, ["累计选择 1 次", "累计选择 3 次", "累计选择 5 次"])
        popupRow("权重衰减：", halfLifePopup, ["30 天未使用后减半", "90 天未使用后减半", "不衰减"])
        popupRow("候选总数：", candidateCountPopup, ["11", "20", "30"])

        contentView.addSubview(makeLabel("英文联想：", frame: NSMakeRect(margin, y, labelWidth, 24)))
        englishCompletionCheckbox.frame = NSMakeRect(controlX, y, controlWidth, 24)
        englishCompletionCheckbox.setButtonType(.switch)
        englishCompletionCheckbox.title = "中英文混输时补全单词和短语"
        contentView.addSubview(englishCompletionCheckbox)
        contentView.addSubview(makeNote("Tab 补全英文；英文词间空格照常输入。",
            frame: NSMakeRect(controlX, y - 18, controlWidth, 16)))
        y -= 42

        contentView.addSubview(makeLabel("打字容错：", frame: NSMakeRect(margin, y, labelWidth, 24)))
        typoCorrectionCheckbox.frame = NSMakeRect(controlX, y, controlWidth, 24)
        typoCorrectionCheckbox.setButtonType(.switch)
        typoCorrectionCheckbox.title = "补充字母颠倒、漏字的拼音候选"
        contentView.addSubview(typoCorrectionCheckbox)
        contentView.addSubview(makeNote("适用于全拼，保留原输入的首选词。",
            frame: NSMakeRect(controlX, y - 18, controlWidth, 16)))
        y -= 42

        contentView.addSubview(makeLabel("词库：", frame: NSMakeRect(margin, y, labelWidth, 24)))
        technicalDictionaryCheckbox.frame = NSMakeRect(controlX, y, controlWidth, 24)
        technicalDictionaryCheckbox.setButtonType(.switch)
        technicalDictionaryCheckbox.title = "启用技术词库（全拼）"
        contentView.addSubview(technicalDictionaryCheckbox)
        y -= 30

        let importButton = NSButton(frame: NSMakeRect(controlX, y, 155, 24))
        importButton.title = "导入自定义词…"
        importButton.bezelStyle = .rounded
        importButton.target = self
        importButton.action = #selector(importCustomPhrases)
        contentView.addSubview(importButton)
        let clearFreqButton = NSButton(frame: NSMakeRect(controlX + 160, y, 120, 24))
        clearFreqButton.title = "清空学习记录"
        clearFreqButton.bezelStyle = .rounded
        clearFreqButton.target = self
        clearFreqButton.action = #selector(clearFrequencyData)
        contentView.addSubview(clearFreqButton)
        y -= 30

        // Full-width punctuation
        let punctuationLabel = makeLabel(
            "标点符号：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(punctuationLabel)

        fullWidthPunctuationCheckbox.frame = NSMakeRect(controlX, y, controlWidth, 24)
        fullWidthPunctuationCheckbox.setButtonType(.switch)
        fullWidthPunctuationCheckbox.title = "使用全角标点"
        contentView.addSubview(fullWidthPunctuationCheckbox)

        y -= 30

        // Proxy mode
        let proxyTypeLabel = makeLabel("代理类型：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyTypeLabel)

        proxyTypePopup.frame = NSMakeRect(controlX, y, controlWidth, 24)
        proxyTypePopup.removeAllItems()
        proxyTypePopup.addItems(withTitles: ProxyType.allCases.map(\.displayName))
        proxyTypePopup.target = self
        proxyTypePopup.action = #selector(proxyTypeChanged)
        contentView.addSubview(proxyTypePopup)

        let proxyNote = makeNote(
            "用于联网获取候选词。",
            frame: NSMakeRect(controlX, y - 18, controlWidth, 16))
        contentView.addSubview(proxyNote)

        y -= 42

        // Proxy host
        let proxyHostLabel = makeLabel("代理地址：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyHostLabel)

        proxyHostField.frame = NSMakeRect(controlX, y, controlWidth, 24)
        proxyHostField.placeholderString = "127.0.0.1"
        contentView.addSubview(proxyHostField)

        y -= 30

        // Proxy port
        let proxyPortLabel = makeLabel("代理端口：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyPortLabel)

        proxyPortField.frame = NSMakeRect(controlX, y, 100, 24)
        proxyPortField.placeholderString = "7890"
        contentView.addSubview(proxyPortField)

        y -= 30

        // Proxy username
        let proxyUsernameLabel = makeLabel(
            "用户名：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyUsernameLabel)

        proxyUsernameField.frame = NSMakeRect(controlX, y, controlWidth, 24)
        proxyUsernameField.placeholderString = "选填"
        contentView.addSubview(proxyUsernameField)

        y -= 30

        // Proxy password
        let proxyPasswordLabel = makeLabel(
            "密码：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyPasswordLabel)

        proxyPasswordField.frame = NSMakeRect(controlX, y, controlWidth, 24)
        proxyPasswordField.placeholderString = "选填"
        contentView.addSubview(proxyPasswordField)

        y -= 35

        // UI mode
        let uiLabel = makeLabel("候选窗样式：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(uiLabel)

        uiModePopup.frame = NSMakeRect(controlX, y, controlWidth, 24)
        uiModePopup.removeAllItems()
        uiModePopup.addItems(withTitles: ["自定义候选窗", "系统候选窗"])
        uiModePopup.target = self
        uiModePopup.action = #selector(uiModeChanged)
        contentView.addSubview(uiModePopup)

        let uiNote = makeNote(
            "点击“保存”后，设置立即生效。",
            frame: NSMakeRect(controlX, y - 18, controlWidth, 16))
        contentView.addSubview(uiNote)

        y -= 42

        // MARK: - Custom UI settings

        let customLabel = makeSectionLabel("自定义候选窗", frame: NSMakeRect(margin, y, 200, 20))
        contentView.addSubview(customLabel)
        y -= 28

        // Font size
        let fontLabel = makeLabel("字体大小：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(fontLabel)

        fontSizePopup.frame = NSMakeRect(controlX, y, 80, 24)
        fontSizePopup.removeAllItems()
        for size in stride(from: 10, through: 48, by: 2) {
            fontSizePopup.addItem(withTitle: "\(size) 磅")
        }
        contentView.addSubview(fontSizePopup)

        y -= 30

        // Page size
        let pageLabel = makeLabel("每页候选数：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(pageLabel)

        pageSizePopup.frame = NSMakeRect(controlX, y, 80, 24)
        pageSizePopup.removeAllItems()
        for size in 3...9 {
            pageSizePopup.addItem(withTitle: "\(size)")
        }
        contentView.addSubview(pageSizePopup)

        y -= 30

        // Padding X
        let paddingXLabel = makeLabel("左右留白：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(paddingXLabel)

        paddingXPopup.frame = NSMakeRect(controlX, y, 80, 24)
        paddingXPopup.removeAllItems()
        for size in stride(from: 0, through: 20, by: 2) {
            paddingXPopup.addItem(withTitle: "\(size) 点")
        }
        contentView.addSubview(paddingXPopup)

        y -= 30

        // Padding Y
        let paddingYLabel = makeLabel("上下留白：", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(paddingYLabel)

        paddingYPopup.frame = NSMakeRect(controlX, y, 80, 24)
        paddingYPopup.removeAllItems()
        for size in stride(from: 0, through: 20, by: 2) {
            paddingYPopup.addItem(withTitle: "\(size) 点")
        }
        contentView.addSubview(paddingYPopup)

        y -= 40

        // Save button
        let saveButton = NSButton(frame: NSMakeRect(controlX + controlWidth - 80, y, 80, 32))
        saveButton.title = "保存"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(savePreferences)
        contentView.addSubview(saveButton)

        updateProxyControls()
        updateCustomUIControls()
    }

    private func makeLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.alignment = .right
        return label
    }

    private func makeSectionLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.alignment = .left
        return label
    }

    private func makeNote(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = NSFont.systemFont(ofSize: 10)
        label.textColor = .secondaryLabelColor
        label.alignment = .left
        return label
    }

    @objc private func proxyTypeChanged() {
        updateProxyControls()
    }

    @objc private func uiModeChanged() {
        updateCustomUIControls()
    }

    @objc private func clearFrequencyData() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "清空学习记录"
        alert.informativeText =
            "清空后，已学习的候选偏好将被重置。确定要清空吗？"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: self) { response in
            if response == .alertFirstButtonReturn {
                CandidateCache.shared.clearFrequencies()
            }
        }
    }

    private func updateProxyControls() {
        let selectedType = ProxyType.allCases[max(proxyTypePopup.indexOfSelectedItem, 0)]
        let isEnabled = selectedType != .none
        proxyHostField.isEnabled = isEnabled
        proxyPortField.isEnabled = isEnabled
        proxyUsernameField.isEnabled = isEnabled
        proxyPasswordField.isEnabled = isEnabled
    }

    private func updateCustomUIControls() {
        let isCustomUI = uiModePopup.indexOfSelectedItem == 0
        fontSizePopup.isEnabled = isCustomUI
        pageSizePopup.isEnabled = isCustomUI
        paddingXPopup.isEnabled = isCustomUI
        paddingYPopup.isEnabled = isCustomUI
    }

    private func presentValidationError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "设置有误"
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.beginSheetModal(for: self) { _ in
            self.makeKeyAndOrderFront(nil)
        }
    }

    private func promoteBackgroundApplication() {
        guard !transformedToForeground else {
            return
        }

        var processSerialNumber = ProcessSerialNumber(
            highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
        let status = TransformProcessType(
            &processSerialNumber,
            ProcessApplicationTransformState(kProcessTransformToForegroundApplication))
        if status == noErr {
            transformedToForeground = true
        } else {
            NSLog("Failed to promote preferences window app activation: \(status)")
        }
    }

    private func restoreBackgroundApplication() {
        guard transformedToForeground else {
            return
        }

        var processSerialNumber = ProcessSerialNumber(
            highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
        let status = TransformProcessType(
            &processSerialNumber,
            ProcessApplicationTransformState(kProcessTransformToUIElementApplication))
        if status == noErr {
            transformedToForeground = false
        } else {
            NSLog("Failed to restore background app activation: \(status)")
        }
    }

    @objc private func savePreferences() {
        let selectedProxyType = ProxyType.allCases[max(proxyTypePopup.indexOfSelectedItem, 0)]
        let proxyHost = proxyHostField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let proxyPortString = proxyPortField.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines)

        if selectedProxyType != .none {
            guard !proxyHost.isEmpty else {
                presentValidationError("请输入代理地址，或将代理类型设为“关闭”。")
                return
            }

            guard let proxyPort = Int(proxyPortString), (1...65535).contains(proxyPort) else {
                presentValidationError("请输入 1 到 65535 之间的代理端口。")
                return
            }

            ProxySettings.type = selectedProxyType
            ProxySettings.host = proxyHost
            ProxySettings.port = proxyPort
            ProxySettings.username = proxyUsernameField.stringValue.trimmingCharacters(
                in: .whitespacesAndNewlines)
            ProxySettings.password = proxyPasswordField.stringValue
        } else {
            ProxySettings.type = .none
            ProxySettings.host = ""
            ProxySettings.port = 0
            ProxySettings.username = ""
            ProxySettings.password = ""
        }

        UISettings.inputTool = InputTool.allCases[max(0, inputSchemePopup.indexOfSelectedItem)]
        UISettings.fullWidthPunctuation = fullWidthPunctuationCheckbox.state == .on
        UISettings.englishCompletion = englishCompletionCheckbox.state == .on
        UISettings.pinyinTypoCorrection = typoCorrectionCheckbox.state == .on
        UISettings.rankingMode = RankingMode.allCases[max(0, rankingPopup.indexOfSelectedItem)]
        UISettings.learnExplicitOnly = learningSourcePopup.indexOfSelectedItem == 0
        UISettings.learningThreshold = [1, 3, 5][max(0, learningThresholdPopup.indexOfSelectedItem)]
        UISettings.frequencyHalfLifeDays = [30, 90, 0][max(0, halfLifePopup.indexOfSelectedItem)]
        UISettings.candidateCount = [11, 20, 30][max(0, candidateCountPopup.indexOfSelectedItem)]
        UISettings.technicalDictionary = technicalDictionaryCheckbox.state == .on
        UISettings.systemUI = uiModePopup.indexOfSelectedItem == 1

        let fontSize = 10 + fontSizePopup.indexOfSelectedItem * 2
        UISettings.fontSize = CGFloat(fontSize)

        let pageSize = 3 + pageSizePopup.indexOfSelectedItem
        UISettings.pageSize = pageSize

        let paddingX = paddingXPopup.indexOfSelectedItem * 2
        UISettings.paddingX = CGFloat(paddingX)

        let paddingY = paddingYPopup.indexOfSelectedItem * 2
        UISettings.paddingY = CGFloat(paddingY)

        NSLog(
            "Preferences saved: inputTool=\(UISettings.inputTool), proxyType=\(ProxySettings.type.rawValue), proxyHost=\(ProxySettings.host), proxyPort=\(ProxySettings.port), proxyUsername=\(ProxySettings.username), systemUI=\(UISettings.systemUI), fontSize=\(UISettings.fontSize), pageSize=\(UISettings.pageSize), paddingX=\(UISettings.paddingX), paddingY=\(UISettings.paddingY)"
        )

        NotificationCenter.default.post(name: NSNotification.Name("PreferencesSaved"), object: nil)

        self.close()
    }

    @objc private func importCustomPhrases() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "tsv") ?? .plainText]
        panel.canChooseDirectories = false
        panel.title = "导入自定义词库"
        panel.prompt = "导入"
        panel.message = "请选择 UTF-8 文本，每行填写“拼音＋制表符＋词语”。导入的词语仅保存在本机。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 1_000_000 else {
                presentValidationError("请选择小于 1 MB 的词库文件。")
                return
            }
            let imported = try String(contentsOf: url, encoding: .utf8)
            let merged = UISettings.customPhrases + "\n" + imported
            let entries = try PersonalDictionary.parse(merged)
            UISettings.customPhrases = entries.keys.sorted().flatMap { key in
                entries[key, default: []].map { key + "\t" + $0 }
            }.joined(separator: "\n")
            NotificationCenter.default.post(name: NSNotification.Name("PreferencesSaved"), object: nil)
        } catch {
            if let importError = error as? PersonalDictionary.ImportError {
                presentValidationError(importError.localizedDescription)
            } else {
                presentValidationError("无法读取词库文件，请确认文件可访问且使用 UTF-8 编码。")
            }
        }
    }

    private func loadPreferences() {
        // Reload current values
        let currentToolIndex = InputTool.allCases.firstIndex(of: UISettings.inputTool) ?? 0
        inputSchemePopup.selectItem(at: currentToolIndex)
        rankingPopup.selectItem(at: RankingMode.allCases.firstIndex(of: UISettings.rankingMode) ?? 1)
        learningSourcePopup.selectItem(at: UISettings.learnExplicitOnly ? 0 : 1)
        learningThresholdPopup.selectItem(at: [1, 3, 5].firstIndex(of: UISettings.learningThreshold) ?? 2)
        halfLifePopup.selectItem(at: [30, 90, 0].firstIndex(of: UISettings.frequencyHalfLifeDays) ?? 1)
        candidateCountPopup.selectItem(at: [11, 20, 30].firstIndex(of: UISettings.candidateCount) ?? 1)
        technicalDictionaryCheckbox.state = UISettings.technicalDictionary ? .on : .off
        fullWidthPunctuationCheckbox.state = UISettings.fullWidthPunctuation ? .on : .off
        englishCompletionCheckbox.state = UISettings.englishCompletion ? .on : .off
        typoCorrectionCheckbox.state = UISettings.pinyinTypoCorrection ? .on : .off
        let currentProxyTypeIndex = ProxyType.allCases.firstIndex(of: ProxySettings.type) ?? 0
        proxyTypePopup.selectItem(at: currentProxyTypeIndex)
        proxyHostField.stringValue = ProxySettings.host
        proxyPortField.stringValue = ProxySettings.port > 0 ? "\(ProxySettings.port)" : ""
        proxyUsernameField.stringValue = ProxySettings.username
        proxyPasswordField.stringValue = ProxySettings.password
        uiModePopup.selectItem(at: UISettings.systemUI ? 1 : 0)

        let fontIndex = (Int(UISettings.fontSize) - 10) / 2
        fontSizePopup.selectItem(at: max(0, min(fontIndex, fontSizePopup.numberOfItems - 1)))

        let pageIndex = UISettings.pageSize - 3
        pageSizePopup.selectItem(at: max(0, min(pageIndex, pageSizePopup.numberOfItems - 1)))

        let paddingXIndex = Int(UISettings.paddingX) / 2
        paddingXPopup.selectItem(at: max(0, min(paddingXIndex, paddingXPopup.numberOfItems - 1)))

        let paddingYIndex = Int(UISettings.paddingY) / 2
        paddingYPopup.selectItem(at: max(0, min(paddingYIndex, paddingYPopup.numberOfItems - 1)))

        updateProxyControls()
        updateCustomUIControls()
    }

    func showWindow() {
        loadPreferences()
        promoteBackgroundApplication()
        self.center()
        self.orderFrontRegardless()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if ProxySettings.type != .none {
            self.makeFirstResponder(proxyHostField)
        }
    }
}

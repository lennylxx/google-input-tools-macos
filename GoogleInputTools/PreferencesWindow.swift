//
//  PreferencesWindow.swift
//  GoogleInputTools
//
//  Created by lennylxx on 3/5/26.
//

import Carbon
import Cocoa

class PreferencesWindow: NSWindow {

    static let shared = PreferencesWindow()

    private let inputSchemePopup = NSPopUpButton()
    private let frequencyRerankCheckbox = NSButton()
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
            contentRect: NSMakeRect(0, 0, 420, 725),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)

        self.title = "Google Input Tools Preferences"
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.hidesOnDeactivate = false
        self.center()

        setupUI()
    }

    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    override func close() {
        super.close()
        restoreBackgroundApplication()
    }

    private func setupUI() {
        let contentView = NSView(frame: self.contentRect(forFrameRect: self.frame))
        self.contentView = contentView

        let margin: CGFloat = 20
        let labelWidth: CGFloat = 110
        let controlX = margin + labelWidth + 10
        let controlWidth: CGFloat = 220
        var y = contentView.bounds.height - margin - 30

        // MARK: - General settings

        let generalLabel = makeSectionLabel("General", frame: NSMakeRect(margin, y, 200, 20))
        contentView.addSubview(generalLabel)
        y -= 30

        // Input scheme
        let schemeLabel = makeLabel("Input Scheme:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(schemeLabel)

        inputSchemePopup.frame = NSMakeRect(controlX, y, controlWidth, 24)
        inputSchemePopup.removeAllItems()
        for tool in InputTool.allCases {
            inputSchemePopup.addItem(withTitle: tool.displayName)
        }
        contentView.addSubview(inputSchemePopup)

        y -= 35

        // Frequency re-ranking
        let rerankLabel = makeLabel(
            "Smart Rerank:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(rerankLabel)

        frequencyRerankCheckbox.frame = NSMakeRect(controlX, y, controlWidth - 70, 24)
        frequencyRerankCheckbox.setButtonType(.switch)
        frequencyRerankCheckbox.title = "Boost frequently selected candidates"
        contentView.addSubview(frequencyRerankCheckbox)

        let clearFreqButton = NSButton(
            frame: NSMakeRect(controlX + controlWidth - 60, y, 60, 24))
        clearFreqButton.title = "Clear"
        clearFreqButton.bezelStyle = .rounded
        clearFreqButton.target = self
        clearFreqButton.action = #selector(clearFrequencyData)
        contentView.addSubview(clearFreqButton)

        y -= 35

        // Proxy mode
        let proxyTypeLabel = makeLabel("Proxy:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyTypeLabel)

        proxyTypePopup.frame = NSMakeRect(controlX, y, controlWidth, 24)
        proxyTypePopup.removeAllItems()
        proxyTypePopup.addItems(withTitles: ProxyType.allCases.map(\.displayName))
        proxyTypePopup.target = self
        proxyTypePopup.action = #selector(proxyTypeChanged)
        contentView.addSubview(proxyTypePopup)

        let proxyNote = makeNote(
            "Used for candidate web requests.",
            frame: NSMakeRect(controlX, y - 18, controlWidth, 16))
        contentView.addSubview(proxyNote)

        y -= 55

        // Proxy host
        let proxyHostLabel = makeLabel("Proxy Host:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyHostLabel)

        proxyHostField.frame = NSMakeRect(controlX, y, controlWidth, 24)
        proxyHostField.placeholderString = "127.0.0.1"
        contentView.addSubview(proxyHostField)

        y -= 35

        // Proxy port
        let proxyPortLabel = makeLabel("Proxy Port:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyPortLabel)

        proxyPortField.frame = NSMakeRect(controlX, y, 100, 24)
        proxyPortField.placeholderString = "7890"
        contentView.addSubview(proxyPortField)

        y -= 35

        // Proxy username
        let proxyUsernameLabel = makeLabel(
            "Username:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyUsernameLabel)

        proxyUsernameField.frame = NSMakeRect(controlX, y, controlWidth, 24)
        proxyUsernameField.placeholderString = "Optional"
        contentView.addSubview(proxyUsernameField)

        y -= 35

        // Proxy password
        let proxyPasswordLabel = makeLabel(
            "Password:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(proxyPasswordLabel)

        proxyPasswordField.frame = NSMakeRect(controlX, y, controlWidth, 24)
        proxyPasswordField.placeholderString = "Optional"
        contentView.addSubview(proxyPasswordField)

        y -= 45

        // UI mode
        let uiLabel = makeLabel("UI Mode:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(uiLabel)

        uiModePopup.frame = NSMakeRect(controlX, y, controlWidth, 24)
        uiModePopup.removeAllItems()
        uiModePopup.addItems(withTitles: ["Custom UI", "System UI"])
        contentView.addSubview(uiModePopup)

        let uiNote = makeNote(
            "Takes effect immediately for all settings.",
            frame: NSMakeRect(controlX, y - 18, controlWidth, 16))
        contentView.addSubview(uiNote)

        y -= 55

        // MARK: - Custom UI settings

        let customLabel = makeSectionLabel("Custom UI", frame: NSMakeRect(margin, y, 200, 20))
        contentView.addSubview(customLabel)
        y -= 30

        // Font size
        let fontLabel = makeLabel("Font Size:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(fontLabel)

        fontSizePopup.frame = NSMakeRect(controlX, y, 80, 24)
        fontSizePopup.removeAllItems()
        for size in stride(from: 10, through: 48, by: 2) {
            fontSizePopup.addItem(withTitle: "\(size) pt")
        }
        contentView.addSubview(fontSizePopup)

        y -= 35

        // Page size
        let pageLabel = makeLabel("Page Size:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(pageLabel)

        pageSizePopup.frame = NSMakeRect(controlX, y, 80, 24)
        pageSizePopup.removeAllItems()
        for size in 3...9 {
            pageSizePopup.addItem(withTitle: "\(size)")
        }
        contentView.addSubview(pageSizePopup)

        y -= 35

        // Padding X
        let paddingXLabel = makeLabel("Padding X:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(paddingXLabel)

        paddingXPopup.frame = NSMakeRect(controlX, y, 80, 24)
        paddingXPopup.removeAllItems()
        for size in stride(from: 0, through: 20, by: 2) {
            paddingXPopup.addItem(withTitle: "\(size) px")
        }
        contentView.addSubview(paddingXPopup)

        y -= 35

        // Padding Y
        let paddingYLabel = makeLabel("Padding Y:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(paddingYLabel)

        paddingYPopup.frame = NSMakeRect(controlX, y, 80, 24)
        paddingYPopup.removeAllItems()
        for size in stride(from: 0, through: 20, by: 2) {
            paddingYPopup.addItem(withTitle: "\(size) px")
        }
        contentView.addSubview(paddingYPopup)

        y -= 50

        // Save button
        let saveButton = NSButton(frame: NSMakeRect(controlX + controlWidth - 80, y, 80, 32))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(savePreferences)
        contentView.addSubview(saveButton)

        updateProxyControls()
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

    @objc private func clearFrequencyData() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear Frequency Data"
        alert.informativeText =
            "This will reset all learned candidate preferences. Are you sure?"
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
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

    private func presentValidationError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Invalid Proxy Settings"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
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
        let toolIndex = inputSchemePopup.indexOfSelectedItem
        UISettings.inputTool = InputTool.allCases[toolIndex]

        UISettings.frequencyRerank = frequencyRerankCheckbox.state == .on

        let selectedProxyType = ProxyType.allCases[max(proxyTypePopup.indexOfSelectedItem, 0)]
        let proxyHost = proxyHostField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let proxyPortString = proxyPortField.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines)

        if selectedProxyType != .none {
            guard !proxyHost.isEmpty else {
                presentValidationError("Enter a proxy host or disable the proxy.")
                return
            }

            guard let proxyPort = Int(proxyPortString), (1...65535).contains(proxyPort) else {
                presentValidationError("Enter a proxy port between 1 and 65535.")
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

    func showWindow() {
        // Reload current values
        let currentToolIndex = InputTool.allCases.firstIndex(of: UISettings.inputTool) ?? 0
        inputSchemePopup.selectItem(at: currentToolIndex)
        frequencyRerankCheckbox.state = UISettings.frequencyRerank ? .on : .off
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

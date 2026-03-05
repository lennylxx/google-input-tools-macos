//
//  PreferencesWindow.swift
//  GoogleInputTools
//
//  Created by lennylxx on 3/5/26.
//

import Cocoa

class PreferencesWindow: NSWindow {

    static let shared = PreferencesWindow()

    private let inputSchemePopup = NSPopUpButton()
    private let uiModePopup = NSPopUpButton()
    private let fontSizeField = NSTextField()
    private let pageSizeField = NSTextField()

    init() {
        super.init(
            contentRect: NSMakeRect(0, 0, 420, 320),
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

    private func setupUI() {
        let contentView = NSView(frame: self.contentRect(forFrameRect: self.frame))
        self.contentView = contentView

        let margin: CGFloat = 20
        let labelWidth: CGFloat = 110
        let controlX = margin + labelWidth + 10
        let controlWidth: CGFloat = 220
        var y: CGFloat = 260

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

        // UI mode
        let uiLabel = makeLabel("UI Mode:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(uiLabel)

        uiModePopup.frame = NSMakeRect(controlX, y, controlWidth, 24)
        uiModePopup.removeAllItems()
        uiModePopup.addItems(withTitles: ["Custom UI", "System UI (IMKCandidates)"])
        contentView.addSubview(uiModePopup)

        let uiNote = makeNote("Takes effect immediately for all settings.", frame: NSMakeRect(controlX, y - 18, controlWidth, 16))
        contentView.addSubview(uiNote)

        y -= 55

        // MARK: - Custom UI settings

        let customLabel = makeSectionLabel("Custom UI", frame: NSMakeRect(margin, y, 200, 20))
        contentView.addSubview(customLabel)
        y -= 30

        // Font size
        let fontLabel = makeLabel("Font Size:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(fontLabel)

        fontSizeField.frame = NSMakeRect(controlX, y, 60, 24)
        contentView.addSubview(fontSizeField)

        let fontUnit = makeLabel("pt", frame: NSMakeRect(controlX + 65, y, 30, 24))
        fontUnit.alignment = .left
        contentView.addSubview(fontUnit)

        y -= 35

        // Page size
        let pageLabel = makeLabel("Page Size:", frame: NSMakeRect(margin, y, labelWidth, 24))
        contentView.addSubview(pageLabel)

        pageSizeField.frame = NSMakeRect(controlX, y, 60, 24)
        contentView.addSubview(pageSizeField)

        let pageUnit = makeLabel("candidates", frame: NSMakeRect(controlX + 65, y, 80, 24))
        pageUnit.alignment = .left
        contentView.addSubview(pageUnit)

        y -= 50

        // Save button
        let saveButton = NSButton(frame: NSMakeRect(controlX + controlWidth - 80, y, 80, 32))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(savePreferences)
        contentView.addSubview(saveButton)
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

    @objc private func savePreferences() {
        let toolIndex = inputSchemePopup.indexOfSelectedItem
        UISettings.inputTool = InputTool.allCases[toolIndex]

        UISettings.systemUI = uiModePopup.indexOfSelectedItem == 1

        if let size = Int(fontSizeField.stringValue), size >= 10, size <= 48 {
            UISettings.fontSize = CGFloat(size)
        }

        if let size = Int(pageSizeField.stringValue), size >= 3, size <= 20 {
            UISettings.pageSize = size
        }

        NSLog("Preferences saved: inputTool=\(UISettings.inputTool), systemUI=\(UISettings.systemUI), fontSize=\(UISettings.fontSize), pageSize=\(UISettings.pageSize)")

        NotificationCenter.default.post(name: NSNotification.Name("PreferencesSaved"), object: nil)

        self.close()
    }

    func showWindow() {
        // Reload current values
        let currentToolIndex = InputTool.allCases.firstIndex(of: UISettings.inputTool) ?? 0
        inputSchemePopup.selectItem(at: currentToolIndex)
        uiModePopup.selectItem(at: UISettings.systemUI ? 1 : 0)
        fontSizeField.stringValue = "\(Int(UISettings.fontSize))"
        pageSizeField.stringValue = "\(UISettings.pageSize)"

        self.center()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

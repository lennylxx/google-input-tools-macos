//
//  UISettings.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/23/21.
//

import SwiftUI

class UISettings {

    private static let defaults = UserDefaults.standard

    // MARK: - Persisted settings

    static var systemUI: Bool {
        get { defaults.object(forKey: "systemUI") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "systemUI") }
    }

    static var inputTool: InputTool {
        get {
            if let raw = defaults.string(forKey: "inputTool"),
               let tool = InputTool(rawValue: raw) {
                return tool
            }
            return .Pinyin
        }
        set { defaults.set(newValue.rawValue, forKey: "inputTool") }
    }

    static var fontSize: CGFloat {
        get {
            let val = defaults.double(forKey: "fontSize")
            return val > 0 ? CGFloat(val) : 16
        }
        set { defaults.set(Double(newValue), forKey: "fontSize") }
    }

    static var frequencyRerank: Bool {
        get { defaults.object(forKey: "frequencyRerank") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "frequencyRerank") }
    }

    static var pageSize: Int {
        get {
            let val = defaults.integer(forKey: "pageSize")
            return val > 0 ? val : 9
        }
        set { defaults.set(newValue, forKey: "pageSize") }
    }

    static var paddingX: CGFloat {
        get {
            let val = defaults.double(forKey: "paddingX")
            return val > 0 ? CGFloat(val) : 6
        }
        set { defaults.set(Double(newValue), forKey: "paddingX") }
    }

    static var paddingY: CGFloat {
        get {
            let val = defaults.double(forKey: "paddingY")
            return val > 0 ? CGFloat(val) : 8
        }
        set { defaults.set(Double(newValue), forKey: "paddingY") }
    }

    // MARK: - Derived properties

    static var font: NSFont {
        return NSFont.systemFont(ofSize: fontSize, weight: .regular)
    }

    // MARK: - Custom UI visual constants

    static let TextColor = NSColor.white
    static let TextBackground = NSColor.black
    static let SelectionBackground = NSColor.systemBlue
}

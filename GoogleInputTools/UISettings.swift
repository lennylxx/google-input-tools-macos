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

    static var englishCompletion: Bool {
        get { defaults.object(forKey: "englishCompletion") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "englishCompletion") }
    }

    static var pinyinTypoCorrection: Bool {
        get { defaults.object(forKey: "pinyinTypoCorrection") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "pinyinTypoCorrection") }
    }

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
        get { rankingMode != .cloud }
        set { rankingMode = newValue ? .balanced : .cloud }
    }

    static var rankingMode: RankingMode {
        get { RankingMode(rawValue: defaults.string(forKey: "rankingMode") ?? "") ?? .balanced }
        set { defaults.set(newValue.rawValue, forKey: "rankingMode") }
    }

    static var learnExplicitOnly: Bool {
        get { defaults.object(forKey: "learnExplicitOnly") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "learnExplicitOnly") }
    }

    static var learningThreshold: Int {
        get { validInteger("learningThreshold", values: [1, 3, 5], fallback: 5) }
        set { defaults.set(newValue, forKey: "learningThreshold") }
    }

    static var frequencyHalfLifeDays: Int {
        get { validInteger("frequencyHalfLifeDays", values: [0, 30, 90], fallback: 90) }
        set { defaults.set(newValue, forKey: "frequencyHalfLifeDays") }
    }

    static var candidateCount: Int {
        get { validInteger("candidateCount", values: [11, 20, 30], fallback: 20) }
        set { defaults.set(newValue, forKey: "candidateCount") }
    }

    static var technicalDictionary: Bool {
        get { defaults.object(forKey: "technicalDictionary") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "technicalDictionary") }
    }

    static var customPhrases: String {
        get { defaults.string(forKey: "customPhrases") ?? "" }
        set { defaults.set(newValue, forKey: "customPhrases") }
    }

    static var accuracyOptions: AccuracyOptions {
        AccuracyOptions(ranking: rankingMode, explicitOnly: learnExplicitOnly,
            minimumSelections: learningThreshold, halfLifeDays: frequencyHalfLifeDays,
            candidateCount: candidateCount, technicalDictionary: technicalDictionary,
            customPhrases: customPhrases)
    }

    private static func validInteger(_ key: String, values: [Int], fallback: Int) -> Int {
        guard let value = defaults.object(forKey: key) as? Int, values.contains(value) else {
            return fallback
        }
        return value
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

    static var fullWidthPunctuation: Bool {
        get { defaults.object(forKey: "fullWidthPunctuation") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "fullWidthPunctuation") }
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

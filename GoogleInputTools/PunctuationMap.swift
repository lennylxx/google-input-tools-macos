//
//  PunctuationMap.swift
//  GoogleInputTools
//

import Foundation

struct PunctuationMap {

    private static let map: [Character: String] = [
        ",": "，",
        ".": "。",
        ";": "；",
        ":": "：",
        "?": "？",
        "!": "！",
        "(": "（",
        ")": "）",
        "<": "《",
        ">": "》",
        "[": "【",
        "]": "】",
        "\\": "、",
        "^": "……",
        "_": "——",
        "~": "～",
        "$": "￥",
        "`": "·",
    ]

    static func fullWidth(for key: Character) -> String? {
        if key == "'" {
            let open = InputContext.shared.nextSingleQuoteIsOpen
            InputContext.shared.nextSingleQuoteIsOpen = !open
            return open ? "\u{2018}" : "\u{2019}"  // ' '
        }
        if key == "\"" {
            let open = InputContext.shared.nextDoubleQuoteIsOpen
            InputContext.shared.nextDoubleQuoteIsOpen = !open
            return open ? "\u{201C}" : "\u{201D}"  // " "
        }
        return map[key]
    }
}

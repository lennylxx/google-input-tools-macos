//
//  Utilities.swift
//  GoogleInputTools
//
//  Created by lennylxx on 11/27/24.
//

import AppKit

public class Utilities {

    static func TranslateKey(_ event: NSEvent) -> String {
        switch event.keyCode {
        case 36:
            return "<Return>"
        case 48:
            return "<Tab>"
        case 49:
            return "<Space>"
        case 51:
            return "<Delete>"
        case 53:
            return "<Esc>"
        case 56:
            return "<Shift>"
        case 123:
            return "<Left>"
        case 124:
            return "<Right>"
        case 125:
            return "<Down>"
        case 126:
            return "<Up>"
        default:
            return event.charactersIgnoringModifiers ?? "<Unknown>"
        }
    }
}

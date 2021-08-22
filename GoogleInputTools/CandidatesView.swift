//
//  CandidatesView.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import SwiftUI

class CandidatesView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        NSLog("CandidatesView::draw")

        let bounds: NSRect = self.bounds
        NSColor.black.set()
        NSBezierPath.fill(bounds)

        let compString = InputEngine.sharedInstance.composeString()
        let compStringToPaint: NSMutableAttributedString = NSMutableAttributedString.init(
            string: compString)

        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: NSFont.Weight.regular)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.white,
            NSAttributedString.Key.backgroundColor: NSColor.systemBlue,
        ]

        compStringToPaint.addAttributes(attributes, range: NSMakeRange(0, compString.count))

        compStringToPaint.draw(in: bounds)
    }
}

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
        NSColor.lightGray.set()
        NSBezierPath.fill(bounds)

        let compString = InputEngine.sharedInstance.composeString()
        let compStringToPaint: NSMutableAttributedString = NSMutableAttributedString.init(
            string: compString)

        compStringToPaint.addAttribute(
            NSAttributedString.Key.font, value: NSFont.userFont(ofSize: 16)!,
            range: NSMakeRange(0, compString.count))

        compStringToPaint.draw(in: bounds)
    }
}

//
//  CandidateUIManager.swift
//  GoogleInputTools
//
//  Created by lennylxx on 3/5/26.
//

import InputMethodKit

protocol CandidateUIManager {
    func show()
    func hide()
    func updateCandidates(client: IMKTextInput)
    func handleArrowKey(event: NSEvent, client: IMKTextInput)
    func pageUp(sender: Any?, client: IMKTextInput)
    func pageDown(sender: Any?, client: IMKTextInput)
    func selectByNumber(keyValue: Int) -> Bool
    func reset()
}

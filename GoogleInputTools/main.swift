//
//  main.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import InputMethodKit
import SwiftUI

let connectionName = "GoogleInputTools_Connection"
let bundleId = Bundle.main.bundleIdentifier!

let server = IMKServer(name: connectionName, bundleIdentifier: bundleId)

NSApplication.shared.run()

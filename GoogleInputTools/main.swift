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

NSLog("creating IMK server")
let server = IMKServer(name: connectionName, bundleIdentifier: bundleId)

NSLog("NSApplication run")
NSApplication.shared.run()

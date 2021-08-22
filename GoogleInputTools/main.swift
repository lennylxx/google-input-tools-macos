//
//  main.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import InputMethodKit
import SwiftUI

let connectionName = "GoogleInputToolsConnection"
var server: IMKServer

let bundleId = Bundle.main.bundleIdentifier!
server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)

NSApplication.shared.run()

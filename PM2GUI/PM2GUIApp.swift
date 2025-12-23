//
//  PM2GUIApp.swift
//  PM2GUI
//
//  Created by Dinindu Wanniarachchi on 2025-12-18.
//

import SwiftUI

@main
struct PM2GUIApp: App {
    var body: some Scene {
        WindowGroup {
            ProcessListView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

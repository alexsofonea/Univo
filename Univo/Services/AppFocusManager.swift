//
//  AppFocusManager.swift
//  Controller
//
//  Created by Alex on 24.09.2025.
//

import AppKit

class AppFocusManager {
    static let shared = AppFocusManager()
    private var previousApp: NSRunningApplication?

    /// Brings Tecky to front, saving the currently focused app
    func bringTeckyToFront() {
        if let current = NSWorkspace.shared.frontmostApplication,
           current.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = current
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Restores focus to the previously active app
    func restorePreviousApp() {
        previousApp?.activate(options: [.activateIgnoringOtherApps])
        previousApp = nil
    }
}

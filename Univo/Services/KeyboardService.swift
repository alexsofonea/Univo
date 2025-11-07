//
//  KeyboardController.swift
//  Controller
//
//  Created by Alex on 01.04.2025.
//

import Foundation
import CoreGraphics

class KeyboardService {
    
    static let shared = KeyboardService()

    /// Simulates a key press
    func pressKey(_ keyCode: CGKeyCode, withModifiers modifiers: CGEventFlags = []) {
        let eventSource = CGEventSource(stateID: .hidSystemState)
        
        let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = modifiers
        keyUp?.flags = modifiers
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

extension KeyboardService {
    /// Simulates pressing a shortcut from a string, e.g., "55+56+67"
    func pressShortcut(_ target: String) {
        let components = target.split(separator: "+").map { String($0) }
        guard let last = components.last, let mainKey = UInt16(last) else {
            print("⚠️ Invalid shortcut string: \(target)")
            return
        }
        let modifierCodes = components.dropLast().compactMap { UInt16($0) }

        guard let eventSource = CGEventSource(stateID: .hidSystemState) else { return }

        // Press down all modifier keys
        for mod in modifierCodes {
            if let modDown = CGEvent(keyboardEventSource: eventSource, virtualKey: mod, keyDown: true) {
                modDown.post(tap: .cghidEventTap)
            }
        }

        // Press and release the main key
        if let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: mainKey, keyDown: true) {
            keyDown.post(tap: .cghidEventTap)
        }
        usleep(50000)
        if let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: mainKey, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }

        // Release modifier keys in reverse order
        for mod in modifierCodes.reversed() {
            usleep(50000)
            if let modUp = CGEvent(keyboardEventSource: eventSource, virtualKey: mod, keyDown: false) {
                modUp.post(tap: .cghidEventTap)
            }
        }
    }
}

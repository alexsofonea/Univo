//
//  ActionExecutor.swift
//  Controller
//
//  Created by Alex on 26.04.2025.
//

import Foundation
import AppKit
import CoreGraphics

class ActionExecutor {
    static let shared = ActionExecutor()
    
    private var typerService = TyperService()
    private var clickerService = ClickerService()
    private var keyboardService = KeyboardService()
    private var commandService = CommandService()
    private var menuService = MenuService()
    
    private var lastAction: [[String: Any]] = []
    
    func performActions(_ actions: [[String: Any]], image: CGImage, breakForContext: (() -> Void)? = nil) async {
        for actionDict in actions {
            guard
                let actionType = actionDict["type"] as? String,
                let target = actionDict["target"]
            else {
                print("⚠️ Invalid action format")
                continue
            }

            switch actionType {
            case "open":
                if let appName = target as? String {
                    print("🚀 Opening app: \(appName)")
                    ActionExecutor.launchApp(byName: appName) {
                        print("✅ App launch command executed for \(appName)")
                    }
                } else {
                    print("⚠️ Invalid 'open' target: \(target)")
                }
            case "leftClick":
                if let (px, py, mods) = convertTargetToCoordinates(target: target, image: image) {
                    if !mods.isEmpty { pressModifierKeys(mods); try? await Task.sleep(nanoseconds: 50_000_000) }
                    print("🖱️ Left Click at (\(px), \(py)) with mods: \(mods)")
                    clickerService.moveMouseAndClick(x: CGFloat(px), y: CGFloat(py))
                    if !mods.isEmpty { try? await Task.sleep(nanoseconds: 50_000_000); releaseModifierKeys(mods) }
                } else {
                    print("⚠️ Could not extract coordinates from target: \(target)")
                }

            case "doubleClick":
                if let (px, py, mods) = convertTargetToCoordinates(target: target, image: image) {
                    if !mods.isEmpty { pressModifierKeys(mods); try? await Task.sleep(nanoseconds: 50_000_000) }
                    print("🖱️ Double Click at (\(px), \(py)) with mods: \(mods)")
                    clickerService.doubleClick(x: CGFloat(px), y: CGFloat(py))
                    if !mods.isEmpty { try? await Task.sleep(nanoseconds: 50_000_000); releaseModifierKeys(mods) }
                    breakForContext?()
                    return
                } else {
                    print("⚠️ Could not extract coordinates from target: \(target)")
                }

            case "rightClick":
                if let (px, py, mods) = convertTargetToCoordinates(target: target, image: image) {
                    if !mods.isEmpty { pressModifierKeys(mods); try? await Task.sleep(nanoseconds: 50_000_000) }
                    print("🖱️ Right Click at (\(px), \(py)) with mods: \(mods)")
                    clickerService.rightClick(x: CGFloat(px), y: CGFloat(py))
                    if !mods.isEmpty { try? await Task.sleep(nanoseconds: 50_000_000); releaseModifierKeys(mods) }
                    breakForContext?()
                    return
                } else {
                    print("⚠️ Could not extract coordinates from target: \(target)")
                }

            case "scroll":
                if let (x, y, dx, dy, mods) = parseScrollTarget(from: target, image: image) {
                    if !mods.isEmpty { pressModifierKeys(mods); try? await Task.sleep(nanoseconds: 30_000_000) }
                    print("🖱️ Scroll at (\(x), \(y)) by (\(dx), \(dy)) with mods: \(mods)")
                    clickerService.scroll(x: CGFloat(x), y: CGFloat(y), deltaX: CGFloat(dx), deltaY: CGFloat(dy))
                    if !mods.isEmpty { try? await Task.sleep(nanoseconds: 30_000_000); releaseModifierKeys(mods) }
                } else {
                    print("⚠️ Could not parse scroll target from: \(target)")
                }

            case "type":
                // Prefer explicit details field for typing text, fallback to target string if it's a string
                var textToType: String = ""
                if let targetStr = target as? String {
                    textToType = targetStr
                }
                print("⌨️ Typing '\(textToType)'")
                typerService.typeText(textToType)

            case "keys":
                if let shortcutStr = target as? String {
                    print("⌨️ Shortcut: \(shortcutStr)")
                    keyboardService.pressShortcut(shortcutStr)
                } else {
                    print("⚠️ Invalid shortcut target: \(target)")
                }

            case "key":
                // Handle a single key press or combination (e.g., "command+t")
                var keyCode: UInt16? = nil
                var keyName: String = ""
                var modifiers: [CGKeyCode] = []

                // Mapping from key names to macOS CGKeyCode
                let keyMapping: [String: UInt16] = [
                    // Letters
                    "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34, "j": 38, "k": 40, "l": 37,
                    "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,

                    // Numbers
                    "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,

                    // Special keys
                    "enter": 36, "return": 36,
                    "backspace": 51, "delete": 51,
                    "arrowup": 126, "arrowdown": 125, "arrowleft": 123, "arrowright": 124,
                    "space": 49, "tab": 48, "escape": 53
                ]
                // Mapping from modifier names to CGKeyCode
                let modifierMapping: [String: CGKeyCode] = [
                    "command": 55,
                    "cmd": 55,
                    "control": 59,
                    "ctrl": 59,
                    "shift": 56,
                    "option": 58,
                    "alt": 58
                ]

                if let targetStr = target as? String {
                    let parts = targetStr.lowercased().split(separator: "+").map { String($0) }
                    for p in parts.dropLast() {
                        if let mod = modifierMapping[p] {
                            modifiers.append(mod)
                        }
                    }

                    let last = parts.last ?? ""
                    if let code = keyMapping[last] {
                        keyCode = code
                        keyName = last
                    } else if let num = UInt16(last) {
                        keyCode = num
                        keyName = last
                    } else {
                        print("⚠️ Unknown key string: \(last)")
                    }
                } else if let num = target as? NSNumber {
                    keyCode = num.uint16Value
                    keyName = "\(num)"
                }

                // Press modifiers first
                if !modifiers.isEmpty {
                    pressModifierKeys(modifiers)
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }

                if let code = keyCode {
                    print("⌨️ Key press: \(keyName) with modifiers: \(modifiers)")
                    if let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
                       let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) {
                        down.post(tap: .cghidEventTap)
                        up.post(tap: .cghidEventTap)
                    }
                } else {
                    print("⚠️ Could not identify key for target: \(target)")
                }

                // Release modifiers
                if !modifiers.isEmpty {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    releaseModifierKeys(modifiers)
                }

            case "delay":
                // target expected to be a number of seconds or details may contain it
                var secString: String? = nil
                if let details = actionDict["details"] {
                    if let dStr = details as? String {
                        secString = dStr
                    } else if let dNum = details as? NSNumber {
                        secString = dNum.stringValue
                    }
                }
                if secString == nil {
                    if let targetStr = target as? String {
                        secString = targetStr
                    } else if let targetNum = target as? NSNumber {
                        secString = targetNum.stringValue
                    } else if let targetArr = target as? [Any], let first = targetArr.first {
                        if let firstNum = first as? NSNumber {
                            secString = firstNum.stringValue
                        } else if let firstStr = first as? String {
                            secString = firstStr
                        }
                    }
                }
                if let secString = secString, let seconds = Double(secString) {
                    print("⏱️ Delay \(seconds)s")
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                } else {
                    print("⚠️ Could not parse delay seconds: \(secString ?? "nil")")
                }

            case "menu":
                if let targetStr = target as? String {
                    let parts = targetStr.components(separatedBy: " > ")
                    if parts.count == 2 {
                        let menuTitle = parts[0].trimmingCharacters(in: .whitespaces)
                        let itemTitle = parts[1].trimmingCharacters(in: .whitespaces)
                        print("📂 Selecting menu item '\(itemTitle)' from '\(menuTitle)'")
                        menuService.clickMenuItem(appName: "Tecky", menuTitle: menuTitle, itemTitle: itemTitle)
                    } else {
                        print("⚠️ Invalid menu target format: \(targetStr)")
                    }
                } else {
                    print("⚠️ Invalid menu target: \(target)")
                }

            default:
                print("⚠️ Unknown action type: \(actionType)")
            }

            // Small delay between actions to let the UI react
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }
    
    private func extractCoordinates(from target: String) -> (CGFloat, CGFloat)? {
        // Example target format: "text(1726.0-375.0) [generate...]"
        let pattern = #"(\d+\.?\d*)-(\d+\.?\d*)"#
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: target, range: NSRange(target.startIndex..., in: target)) {
            
            let xRange = Range(match.range(at: 1), in: target)!
            let yRange = Range(match.range(at: 2), in: target)!
            
            let xString = String(target[xRange])
            let yString = String(target[yRange])
            
            if let x = Double(xString), let y = Double(yString) {
                return (CGFloat(x), CGFloat(y))
            }
        }
        return nil
    }
    
    private func parsePointAndModifiers(from target: String) -> (Double, Double, [CGKeyCode])? {
        // Try JSON array like [1726, 375, "55+56"]
        if let data = target.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return parsePointAndModifiers(from: arr)
        }

        // Fallback to previous pattern-based extraction
        if let coords = extractCoordinates(from: target) {
            return (Double(coords.0), Double(coords.1), [])
        }
        return nil
    }

    private func parsePointAndModifiers(from arr: [Any]) -> (Double, Double, [CGKeyCode])? {
        guard arr.count >= 2 else { return nil }
        func asDouble(_ any: Any) -> Double? {
            if let n = any as? NSNumber { return n.doubleValue }
            if let s = any as? String, let d = Double(s) { return d }
            return nil
        }
        if let x = asDouble(arr[0]), let y = asDouble(arr[1]) {
            var mods: [CGKeyCode] = []
            if arr.count >= 3 {
                if let modStr = arr[2] as? String {
                    let parts = modStr.split(separator: "+").map { String($0) }
                    for p in parts { if let v = UInt16(p) { mods.append(CGKeyCode(v)) } }
                } else if let num = arr[2] as? NSNumber {
                    mods.append(CGKeyCode(num.uint16Value))
                }
            }
            return (x, y, mods)
        }
        return nil
    }

    private func pressModifierKeys(_ keyCodes: [CGKeyCode]) {
        for code in keyCodes {
            if let ev = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true) {
                ev.post(tap: .cghidEventTap)
            }
        }
    }

    private func releaseModifierKeys(_ keyCodes: [CGKeyCode]) {
        for code in keyCodes {
            if let ev = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) {
                ev.post(tap: .cghidEventTap)
            }
        }
    }
    
    func activateApp(named appName: String) {
        let workspace = NSWorkspace.shared
        //print("🍎 Apps")
        //print(workspace.runningApplications)
        if let app = workspace.runningApplications.first(where: { $0.localizedName == appName }) {
            app.activate(options: [.activateAllWindows])
            //print("✅ Brought '\(appName)' to front")
        } else {
            print("⚠️ App '\(appName)' not found")
        }
    }

    // Helper for extracting Double from Any (used for bbox logic)
    private func asDouble(_ any: Any) -> Double? {
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String, let d = Double(s) { return d }
        return nil
    }

    // New helper: Convert various target formats to coordinates (with scaling)
    private func convertTargetToCoordinates(target: Any, image: CGImage) -> (Double, Double, [CGKeyCode])? {
        // At the start, determine the screen size (logical size)
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: image.width, height: image.height)
        // Accepts:
        // - [x1, y1, x2, y2] bbox: will use center
        // - [x, y] raw pixels
        // - [x, y] normalized (0-1): will convert to image size
        // - Optionally, a modifier string or number as 3rd/5th element.
        // - String: try to parse as JSON or "text(1726.0-375.0)"
        // Returns (x, y, [mods])
        func extractMods(_ arr: [Any], idx: Int) -> [CGKeyCode] {
            var mods: [CGKeyCode] = []
            if arr.count > idx {
                if let modStr = arr[idx] as? String {
                    let parts = modStr.split(separator: "+").map { String($0) }
                    for p in parts { if let v = UInt16(p) { mods.append(CGKeyCode(v)) } }
                } else if let num = arr[idx] as? NSNumber {
                    mods.append(CGKeyCode(num.uint16Value))
                }
            }
            return mods
        }
        // Handle array
        if let arr = target as? [Any] {
            // [x1, y1, x2, y2, mods?]: bbox
            if arr.count >= 4,
                let x1 = asDouble(arr[0]), let y1 = asDouble(arr[1]),
                let x2 = asDouble(arr[2]), let y2 = asDouble(arr[3]) {
                var px = (x1 + x2) / 2.0
                var py = (y1 + y2) / 2.0
                let mods = extractMods(arr, idx: 4)
                // Normalize to image size, then rescale to screen size
                let normX = px / Double(image.width)
                let normY = py / Double(image.height)
                px = normX * Double(screenSize.width)
                py = normY * Double(screenSize.height)
                return (px, py, mods)
            }
            // [x, y, mods?]: point
            if arr.count >= 2, let x = asDouble(arr[0]), let y = asDouble(arr[1]) {
                var px = x, py = y
                let mods = extractMods(arr, idx: 2)
                // Normalize to image size, then rescale to screen size
                let normX = px / Double(image.width)
                let normY = py / Double(image.height)
                px = normX * Double(screenSize.width)
                py = normY * Double(screenSize.height)
                return (px, py, mods)
            }
        }
        return nil
    }

    // New helper to parse scroll target with format [x, y, deltaX, deltaY, (optional modifiers)]
    private func parseScrollTarget(from target: Any, image: CGImage) -> (Double, Double, Double, Double, [CGKeyCode])? {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: image.width, height: image.height)
        func extractMods(_ arr: [Any], idx: Int) -> [CGKeyCode] {
            var mods: [CGKeyCode] = []
            if arr.count > idx {
                if let modStr = arr[idx] as? String {
                    let parts = modStr.split(separator: "+").map { String($0) }
                    for p in parts { if let v = UInt16(p) { mods.append(CGKeyCode(v)) } }
                } else if let num = arr[idx] as? NSNumber {
                    mods.append(CGKeyCode(num.uint16Value))
                }
            }
            return mods
        }
        func asDouble(_ any: Any) -> Double? {
            if let n = any as? NSNumber { return n.doubleValue }
            if let s = any as? String, let d = Double(s) { return d }
            return nil
        }
        if let arr = target as? [Any] {
            // Handle arrays of length 2: [x, y] (no deltas, default scroll values)
            if arr.count == 2 {
                if let x = asDouble(arr[0]), let y = asDouble(arr[1]) {
                    // Normalize x,y to image size then scale to screen size
                    let normX = x / Double(image.width)
                    let normY = y / Double(image.height)
                    let px = normX * Double(screenSize.width)
                    let py = normY * Double(screenSize.height)
                    // Use a default delta, e.g., scroll by half screen height
                    return (px, py, 0, Double(screenSize.height) / 2.0, [])
                }
            }
            // Standard scroll: [x, y, dx, dy, mods?]
            if arr.count >= 4 {
                guard let x = asDouble(arr[0]), let y = asDouble(arr[1]), let dx = asDouble(arr[2]), let dy = asDouble(arr[3]) else { return nil }
                let mods = extractMods(arr, idx: 4)
                // Normalize x,y to image size then scale to screen size
                let normX = x / Double(image.width)
                let normY = y / Double(image.height)
                let px = normX * Double(screenSize.width)
                let py = normY * Double(screenSize.height)
                return (px, py, dx, dy, mods)
            }
        } else if let targetStr = target as? String,
                  let data = targetStr.data(using: .utf8),
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return parseScrollTarget(from: arr, image: image)
        }
        return nil
    }
    
    static func launchApp(byName name: String, completion: @escaping () -> Void) {
        let fileManager = FileManager.default
        // System apps mapping: app name (lowercased) to canonical name for NSWorkspace
        let systemApps: [String: String] = [
            "finder": "Finder",
            "mail": "Mail",
            "safari": "Safari",
            "terminal": "Terminal",
            "messages": "Messages",
            "calendar": "Calendar",
            "notes": "Notes",
            "reminders": "Reminders",
            "preview": "Preview",
            "music": "Music",
            "facetime": "FaceTime",
            "photos": "Photos",
            "system preferences": "System Settings",
            "system settings": "System Settings"
        ]

        let lowerName = name.lowercased()
        if let systemAppName = systemApps[lowerName] {
            // Try to launch the system app by name
            let launched = NSWorkspace.shared.launchApplication(systemAppName)
            print("Launching system app: \(systemAppName) (success: \(launched))")
            completion()
            return
        }

        // Get the path to the /Applications folder
        let applicationsPath = "/Applications"
        do {
            // Get all files in the /Applications folder
            let appFiles = try fileManager.contentsOfDirectory(atPath: applicationsPath)
            // Loop through the files and find applications that match the given name
            for app in appFiles {
                if app.lowercased().contains(lowerName) {
                    let appPath = "\(applicationsPath)/\(app)"
                    if let url = URL(string: "file://\(appPath)") {
                        // Try to open the app with NSWorkspace
                        NSWorkspace.shared.open(url)
                        print("Launching app: \(appPath)")
                        // Call the completion handler when done
                        completion()
                        return
                    }
                } else {
                    print("App '\(app)' does not match name '\(name)'")
                }
            }
            print("App with name '\(name)' not found.")
            completion()
        } catch {
            print("Error reading /Applications folder: \(error.localizedDescription)")
            completion()
        }
    }
}

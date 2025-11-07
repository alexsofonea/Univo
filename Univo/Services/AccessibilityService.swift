//
//  AccessibilityService.swift
//  Controller
//
//  Created by Alex on 01.04.2025.
//

import Cocoa
import ApplicationServices

class AccessibilityService {
    static let shared = AccessibilityService()
    
    public var allowedToAccessApps: Set<String> = []
    
    func getInteractableElements(forAppName targetAppName: String) -> ([String], [String]) {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        var elementDescriptions: [String] = []
        var elementPositions: [String] = []
        var elementID = 1  // Start from 1

        func traverseAccessibilityHierarchy(element: AXUIElement, appName: String) {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)

            if result == .success, let childrenArray = value as? [AXUIElement] {
                for child in childrenArray {
                    processElement(child, appName: appName)
                    traverseAccessibilityHierarchy(element: child, appName: appName)
                }
            }
        }

        func processElement(_ element: AXUIElement, appName: String) {
            var roleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
               let roleString = roleValue as? String,
               isInteractableRole(roleString) {

                var labelValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &labelValue) != .success {
                    AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &labelValue)
                }
                let labelString = labelValue as? String ?? "No Label"

                var position = CGPoint(x: 0, y: 0)
                if let positionValue = try? getAttributeValue(element, for: kAXPositionAttribute) {
                    let axValue = positionValue
                    AXValueGetValue(axValue as! AXValue, .cgPoint, &position)
                }

                let id = elementID
                elementID += 1
                
                if labelString != "No Label" {
                    elementDescriptions.append("\(id) | \(labelString) | \(roleString)")
                    elementPositions.append("\(id) | \(position.x) | \(position.y)")
                }
            }
        }

        func getAttributeValue(_ element: AXUIElement, for attribute: String) throws -> CFTypeRef? {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            if result == .success {
                return value
            }
            return nil
        }

        for app in runningApps {
            let appName = app.localizedName ?? "Unknown App"
            if appName == targetAppName {
                let pid = app.processIdentifier
                let appElement = AXUIElementCreateApplication(pid)

                var value: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)

                if result == .success, let windowArray = value as? [AXUIElement] {
                    for window in windowArray {
                        traverseAccessibilityHierarchy(element: window, appName: appName)
                    }
                }
            }
        }

        return (elementDescriptions, elementPositions)
    }

    private func isInteractableRole(_ role: String) -> Bool {
        let interactableRoles: [CFString] = [
            kAXButtonRole as CFString,
            kAXCheckBoxRole as CFString,
            kAXRadioButtonRole as CFString,
            kAXTextFieldRole as CFString,
            "AXTab" as CFString,  // Manually defining AXTabRole
            "AXLink" as CFString  // Manually defining AXLinkRole
        ]
        return interactableRoles.contains(role as CFString)
    }
    
    func getRunningApps() -> [String] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        let appNames = runningApps.compactMap { $0.localizedName }
        return appNames
    }
    
    func getAllInstalledAppNames() -> [String] {
        //let existingApps = ["Finder", "ChatGPT", "Swift Playground", "Safari", "Shazam", "WhatsApp", "Keynote", "Teleprompter", "Chrome", "Xcode", "Discord", "Autodesk Fusion", "Android Studio", "Numbers", "Final Cut Pro", "Code", "DaVinci Resolve", "Motion", "Studio", "GitHub Desktop", "Pages", "Notion", "Logic Pro", "Figma", "Arduino IDE", "OBS", "Mail", "Calendar", "Messages", "FaceTime", "Reminders", "Notes"]
        //let existingApps = ["Finder", "Safari", "Xcode", "Code", "GitHub Desktop", "Notion", "Figma", "Mail", "Calendar", "Messages", "FaceTime", "Reminders", "Notes"]
        
        let existingApps: Set<String> = allowedToAccessApps
        
        let fileManager = FileManager.default
        let applicationDirectories = [
            "/Applications",                             // Global applications
            "\(NSHomeDirectory())/Applications"         // User applications
        ]
        
        var appNames: Set<String> = []
        
        appNames.insert("Finder")  // Always include Finder
        appNames.insert("Mail")  // Always include Mail

        for directory in applicationDirectories {
            do {
                // Get contents of the directory (no recursion)
                let contents = try fileManager.contentsOfDirectory(atPath: directory)
                
                for file in contents {
                    // Only consider items that are ".app" bundles
                    if file.hasSuffix(".app") {
                        let fullPath = (directory as NSString).appendingPathComponent(file)
                        let url = URL(fileURLWithPath: fullPath)
                        if let bundle = Bundle(url: url),
                           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                            appNames.insert(name)
                        } else {
                            // Fallback: Use the app's filename if CFBundleName is missing
                            appNames.insert(url.deletingPathExtension().lastPathComponent)
                        }
                    }
                }
            } catch {
                print("Error reading directory \(directory): \(error.localizedDescription)")
            }
        }
        
        if (existingApps.isEmpty) {
            return Array(appNames)
        } else {
            return Array(Set(appNames).intersection(existingApps))
        }
    }
}

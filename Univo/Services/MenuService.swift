//
//  MenuService.swift
//  Controller
//
//  Created by Alex on 26.04.2025.
//

import Cocoa
import ApplicationServices

class MenuService {
    static let shared = MenuService()
    
    func getMenuBarItems(for appName: String) -> [String] {
        var result: [String] = []

        let workspace = NSWorkspace.shared
        
        guard let app = workspace.runningApplications.first(where: { $0.localizedName == appName }) else {
            print("❌ App not running: \(appName)")
            return result
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var menuBarRef: CFTypeRef?
        let menuResult = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef)

        guard menuResult == .success, let menuBar = menuBarRef else {
            print("❌ Could not access menu bar for: \(appName)")
            return result
        }

        var menuBarChildrenRef: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &menuBarChildrenRef)

        guard childrenResult == .success, let menuBarChildren = menuBarChildrenRef as? [AXUIElement] else {
            print("❌ Could not access menu bar children for: \(appName)")
            return result
        }

        for menu in menuBarChildren {
            var menuTitleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(menu, kAXTitleAttribute as CFString, &menuTitleRef) == .success,
               let menuTitle = menuTitleRef as? String {
                
                var submenuRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &submenuRef) == .success,
                   let submenuItems = submenuRef as? [AXUIElement] {
                    for item in submenuItems {
                        var itemTitleRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &itemTitleRef) == .success,
                           let itemTitle = itemTitleRef as? String {
                            result.append("\(menuTitle) > \(itemTitle)")
                            print("✅ Found menu item: \(menuTitle) > \(itemTitle)")
                        }
                    }
                }
            }
        }

        return result
    }
    
    func clickMenuItem(appName: String, menuTitle: String, itemTitle: String) {
        let workspace = NSWorkspace.shared
        guard let app = workspace.runningApplications.first(where: { $0.localizedName == appName }) else {
            print("❌ App not running: \(appName)")
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var menuBarRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) != .success {
            print("❌ Could not access menu bar")
            return
        }

        guard let menuBar = menuBarRef else { return }

        var menuBarChildrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &menuBarChildrenRef) != .success {
            print("❌ Could not access menu bar children")
            return
        }

        guard let menuBarChildren = menuBarChildrenRef as? [AXUIElement] else { return }

        for menu in menuBarChildren {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(menu, kAXTitleAttribute as CFString, &titleRef) == .success,
               let title = titleRef as? String,
               title == menuTitle {

                var submenuRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &submenuRef) == .success,
                   let submenuItems = submenuRef as? [AXUIElement] {
                    for item in submenuItems {
                        var itemTitleRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &itemTitleRef) == .success,
                           let itemTitleFound = itemTitleRef as? String,
                           itemTitleFound == itemTitle {
                            AXUIElementPerformAction(item, kAXPressAction as CFString)
                            print("✅ Clicked menu item '\(itemTitle)' under '\(menuTitle)'")
                            return
                        }
                    }
                }
            }
        }

        print("⚠️ Menu or item not found.")
    }
}

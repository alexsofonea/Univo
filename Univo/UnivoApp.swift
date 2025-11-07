//
//  ControllerApp.swift
//  Controller
//
//  Created by Alex on 31.03.2025.
//

import SwiftUI
import ApplicationServices
import Cocoa


@main
struct ControllerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var permissionsService = PermissionsService()
    
    var body: some Scene {
        Settings {}
        
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.appSettings) {
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("settings"), object: nil)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("about"), object: nil)
                } label: {
                    Label("About Tecky", systemImage: "info.circle.fill")
                }
            }
            CommandGroup(replacing: CommandGroupPlacement.appVisibility) {}
            CommandGroup(replacing: CommandGroupPlacement.systemServices) {}
            
            
            // CommandGroup(replacing: CommandGroupPlacement.pasteboard) {}
            CommandGroup(replacing: CommandGroupPlacement.newItem) {}
            CommandGroup(replacing: CommandGroupPlacement.undoRedo) {}
            CommandGroup(replacing: CommandGroupPlacement.toolbar) {}
            
            CommandMenu("Developer") {
                Button {
                    let path = NSString(string: "~/Library/Application Support/Tecky/").expandingTildeInPath
                    let url = URL(fileURLWithPath: path, isDirectory: true)
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Support Location", systemImage: "folder")
                }
                Divider()
                Button {
                    let path = NSString(string: "~/Library/Application Support/Tecky/models/").expandingTildeInPath
                    let url = URL(fileURLWithPath: path, isDirectory: true)
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Models", systemImage: "brain")
                }
                Button {
                    let path = NSString(string: "~/Library/Application Support/Tecky/dataset/").expandingTildeInPath
                    let url = URL(fileURLWithPath: path, isDirectory: true)
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Dataset", systemImage: "swiftdata")
                }
            }
            
            CommandGroup(replacing: CommandGroupPlacement.windowArrangement) {}
            //CommandGroup(replacing: CommandGroupPlacement.help) {}
        }
    }
}


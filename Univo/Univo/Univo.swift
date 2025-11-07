//
//  Tecky.swift
//  Controller
//
//  Created by Alex on 06.04.2025.
//

import SwiftUI
import AppKit
import WebKit
import Foundation

@MainActor
class Univo: ObservableObject {
    
    static let shared = Univo()
    
    private var accessibilityService = AccessibilityService.shared
    private var menuService = MenuService.shared
    
    private var screenCaptureService = ScreenCaptureService.shared
    
    private var mlxPrompts = MLXPrompts.shared
    
    private var actionExecutor = ActionExecutor.shared

    private var rejectHistory: [String] = []
    private var promptHistory: [String] = []
    
    private var isStopped = false
    private var lastResponse: [String: Any] = [:]
    
    func handleNewTask(prompt: String) {
        
        //let webview = AppDelegate.shared?.mainWebView
        
        DispatchQueue.main.async {
            self.isStopped = false
        }
        
        AppDelegate.shared?.createCursorWindow()
        CursorStateManager.shared.showLoader()
        
        let appNames = accessibilityService.getAllInstalledAppNames().map { "\"\($0)\"" }
        
        self.takeAction(appChoices: appNames, prompt: prompt)
    }
    
    func takeAction(appChoices: [String], prompt: String) {
        let webview = AppDelegate.shared?.mainWebView
        
        DispatchQueue.main.async {
            guard !self.isStopped else { return }
            webview?.evaluateJavaScript("addLoader('Processing next tasks ...')", completionHandler: nil)
            // Use CursorStateManager to show loader
            CursorStateManager.shared.showLoader()
        }
        
        screenCaptureService.captureFullScreen(completion: { result in
            guard !self.isStopped else { return }
            switch result {
            case .success(let image):
                // AppFocusManager.shared.bringTeckyToFront()
                VLMModelManager.shared.run(input: self.mlxPrompts.controlTask(prompt: prompt, appChoices: appChoices, image: image), completion: { result in
                    guard !self.isStopped else { return }
                    switch result {
                    case .success(let argumentsData):
                        if let data = argumentsData.data(using: .utf8),
                           let arguments = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            
                            let actionsRaw = arguments["actions"]
                            
                            if let actions = actionsRaw as? [[String: Any]] {
                                guard !self.isStopped else { return }
                                Task {
                                    await self.actionExecutor.performActions(actions, image: image!)
                                }
                            } else {
                                print("❌ No suitable actions found.")
                                if let data = argumentsData.data(using: .utf8) {
                                    print("Received arguments: \(String(data: data, encoding: .utf8) ?? "")")
                                }
                            }
                        }
                    case .failure(let error):
                        print("❌ Error running model: \(error.localizedDescription)")
                    }
                })
            case .failure(let error):
                print("❌ Error capturing screen: \(error.localizedDescription)")
            }
        })
    }
    
    // Immediately stop all ongoing and future operations
    func stopAllExecution() {
        DispatchQueue.main.async {
            self.isStopped = true
        }
        AppDelegate.shared?.removeCursorWindow()
    }
    
    static func getRunningAppNames() -> [String] {
        let runningApps = NSWorkspace.shared.runningApplications
        // Filter apps to only include those with a localizedName (visible apps)
        let appNames = runningApps.compactMap { $0.localizedName }
        return appNames
    }
}


class Prompts {
    var accessibilityService: AccessibilityService = AccessibilityService()
}


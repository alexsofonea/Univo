//
//  WebView.swift
//  Controller
//
//  Created by Alex on 04.04.2025.
//

import SwiftUI
import WebKit
import Cocoa
import AVFoundation

struct WebView: NSViewRepresentable {
    var fileName: String // Add fileName property to accept the file name
    
    var onWebViewCreated: ((WKWebView) -> Void)?
    
    var univo: Univo = Univo.shared
    var accessibilityService = AccessibilityService.shared
    private var menuService = MenuService.shared
    
    private var screenCaptureService = ScreenCaptureService.shared
    
    // Add an initializer to accept the file name
    init(fileName: String, onWebViewCreated: ((WKWebView) -> Void)? = nil) {
        self.fileName = fileName
        self.onWebViewCreated = onWebViewCreated
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Enable non-persistent data storage
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.suppressesIncrementalRendering = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Enable web debugging through the Web Inspector
        //webView.isInspectable = true
        
        webView.setValue(false, forKey: "drawsBackground")
        
        // Configure the user content controller
        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "callbackHandler")
        
        onWebViewCreated?(webView)
        
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.allowsBackForwardNavigationGestures = false
        
        /*if let resourcePath = Bundle.main.resourcePath {
            let wwwPath = resourcePath + "/www"
            do {
                let fileNames = try FileManager.default.contentsOfDirectory(atPath: wwwPath)
                print("Files in www folder: \(fileNames)")
            } catch {
                print("Error listing files: \(error)")
            }
        }*/
        
        PermissionsService.acquireAccessibilityPrivileges(completion: { _ in })
        PermissionsService.acquireScreenRecordingPrivileges(completion: { _ in })

        // Load the local index.html file
        if let indexPath = Bundle.main.path(forResource: fileName, ofType: "html", inDirectory: "www") {
            let indexURL = URL(fileURLWithPath: indexPath)
            let request = URLRequest(url: indexURL)
            nsView.load(request)
        } else {
            print("Error: index.html not found in the bundle.")
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        var webView: WKWebView?
        var selectedFolderURL: URL?  // Store the selected folder path

        init(_ parent: WebView) {
            self.parent = parent
            super.init()
            
            NotificationCenter.default.addObserver(self, selector: #selector(commandSettings), name: NSNotification.Name("settings"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(commandAbout), name: NSNotification.Name("about"), object: nil)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func commandSettings() {
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript("changeContent(3)", completionHandler: nil)
            }
        }
        @objc func commandAbout() {
            openURLInBrowser("https://tecky.tech/")
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            //print("WebView started loading.")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation error: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation error: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
            //print("WebView finished loading.")
            
            passApps(webView: webView)
            
            requestMicrophoneAccess { granted in
                if granted {
                    self.webView?.evaluateJavaScript("startAudio();", completionHandler: nil)
                } else {
                    print("Microphone permission denied")
                }
            }
            
            let onboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboardingUIWelcome")
            if onboarding == false {
                onboardingWelcome(webView: webView)
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboardingUIWelcome")
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "callbackHandler" {
                if let messageBody = message.body as? [String: Any],
                   let action = messageBody["action"] as? String {
                    switch action {
                    case "permission_accesibility":
                        PermissionsService.acquireAccessibilityPrivileges(completion: { result in
                            if result {
                                self.callJavaScriptFunction(functionName: "handlePermission", parameters: ["status": "success", "action": "permission_accesibility"])
                            } else {
                                self.callJavaScriptFunction(functionName: "handlePermission", parameters: ["status": "error", "action": "permission_accesibility"])
                            }
                        })
                    case "permission_vision":
                        PermissionsService.acquireScreenRecordingPrivileges(completion: { result in
                            if result {
                                self.callJavaScriptFunction(functionName: "handlePermission", parameters: ["status": "success", "action": "permission_vision"])
                            } else {
                                self.callJavaScriptFunction(functionName: "handlePermission", parameters: ["status": "error", "action": "permission_vision"])
                            }
                        })
                    case "openURL":
                        if let urlString = messageBody["url"] as? String {
                            openURLInBrowser(urlString)
                        }
                    case "feedback":
                        triggerHapticFeedback()
                        break;
                    case "litefeedback":
                        triggerLiteHapticFeedback()
                        break;
                    case "errorfeedback":
                        triggerHapticErrorFeedback()
                        break;
                    case "alert":
                        print(messageBody["data"] as? String ?? "")
                        break;
                    case "userAlert":
                        let alert = NSAlert()
                        alert.messageText = messageBody["title"] as? String ?? "Alert"
                        alert.informativeText = messageBody["data"] as? String ?? ""
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                        
                    case "taskInit":
                        if let taskName = messageBody["data"] as? String {
                            //print("Initializing task: \(taskName)")
                            parent.univo.handleNewTask(prompt: taskName)
                        }
                    case "taskCancel":
                        parent.univo.stopAllExecution()
                    case "glow":
                        if let glowData = messageBody["data"] as? String {
                            if glowData == "true" {
                                AppDelegate.shared?.triggerGlow(glow: true)
                            } else {
                                AppDelegate.shared?.triggerGlow(glow: false)
                            }
                        }
                        
                    case "saveSettings":
                        if let settings = messageBody["data"] as? [String: Bool] {
                            for (key, value) in settings {
                                UserDefaults.standard.set(value, forKey: key)
                                if key.contains("access_") && value == true {
                                    parent.accessibilityService.allowedToAccessApps.insert(key.replacingOccurrences(of: "access_", with: ""))
                                } else if key.contains("access_") && value == false {
                                    parent.accessibilityService.allowedToAccessApps.remove(key.replacingOccurrences(of: "access_", with: ""))
                                }
                            }
                            //print("Allowed apps: \(parent.accessibilityService.allowedToAccessApps)")
                        }
                    case "loadSettings":
                        if let settings = messageBody["data"] as? [String: Bool] {
                            var settingsDict: [String: Bool] = [:]
                            for (key, _) in settings {
                                settingsDict[key] = UserDefaults.standard.bool(forKey: key)
                            }
                            if let jsonData = try? JSONSerialization.data(withJSONObject: settingsDict, options: []),
                               var jsonString = String(data: jsonData, encoding: .utf8) {
                                jsonString = jsonString.replacingOccurrences(of: "[", with: "{")
                                                       .replacingOccurrences(of: "]", with: "}")
                                let jsCode = "loadSettings(\(jsonString));"
                                self.webView?.evaluateJavaScript(jsCode, completionHandler: nil)
                            }
                        }
                            
                        
                    case "factory_reset":
                        let alert = NSAlert()
                        alert.messageText = "Reset Univo?"
                        alert.informativeText = "This will clear onboarding progress and quit the app. Are you sure?"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Reset and Quit")
                        alert.addButton(withTitle: "Cancel")
                        let response = alert.runModal()
                        
                        if response == .alertFirstButtonReturn {
                            UserDefaults.standard.set(false, forKey: "hasCompletedOnboardingUIWelcome")
                            UserDefaults.standard.set(false, forKey: "hasCompletedOnboardingPermissions")
                            UserDefaults.standard.synchronize()
                            NSApplication.shared.terminate(nil)
                        }
                    case "factory_quit":
                        let task = Process()
                        task.launchPath = "/usr/bin/open"
                        task.arguments = [Bundle.main.bundlePath]
                        task.launch()

                        NSApplication.shared.terminate(nil)
                        
                    case "playSound":
                        if let soundType = messageBody["data"] as? String {
                            parent.univo.playSound(for: soundType)
                        }
                    
                    default:
                        break
                    }
                }
            }
        }


        func callJavaScriptFunction(functionName: String, parameters: [String: Any]) {
            guard let webView = webView else { return }
            let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)!
            let jsCode = "\(functionName)(\(jsonString));"
            print(jsCode)
            DispatchQueue.main.async {
                webView.evaluateJavaScript(jsCode, completionHandler: nil)
            }
        }

        private func openURLInBrowser(_ urlString: String) {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
        
        func triggerHapticFeedback() {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
        func triggerLiteHapticFeedback() {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
        func triggerHapticErrorFeedback() {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
        
        func passApps(webView: WKWebView) {
            Task {
                do {
                    let allApps = parent.accessibilityService.getAllInstalledAppNames().sorted()
                    let jsonData = try JSONSerialization.data(withJSONObject: allApps, options: [])
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                    let jsCode = "handleAppInfo(\(jsonString));"
                    _ = try await webView.evaluateJavaScript(jsCode)
                } catch {
                    let jsCode = "handleAppInfo([]);"
                    print("Error fetching apps: \(error)")
                    _ = try await webView.evaluateJavaScript(jsCode)
                }
            }
        }
        func onboardingWelcome(webView: WKWebView) {
            let jsCode = "onboardingWelcome();"
            webView.evaluateJavaScript(jsCode, completionHandler: nil)
        }
        
        func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                completion(true)
            case .denied, .restricted:
                // Inform user to enable manually
                showMicrophoneSettingsAlert()
                completion(false)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        if !granted {
                            self.showMicrophoneSettingsAlert()
                        }
                        completion(granted)
                    }
                }
            @unknown default:
                completion(false)
            }
        }

        private func showMicrophoneSettingsAlert() {
            let alert = NSAlert()
            alert.messageText = "Microphone Access Required"
            alert.informativeText = "Please enable microphone access in System Settings → Security & Privacy → Microphone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}


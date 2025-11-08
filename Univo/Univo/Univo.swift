import AVFoundation
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
        
        //AppDelegate.shared?.createCursorWindow()
        //CursorStateManager.shared.showLoader()
        
        let appNames = accessibilityService.getAllInstalledAppNames().map { "\"\($0)\"" }
        
        self.takeAction(appChoices: appNames, prompt: prompt)
    }
    
    func takeAction(appChoices: [String], prompt: String) {
        let webview = AppDelegate.shared?.mainWebView
        
        playSound(for: "loading")
        
        DispatchQueue.main.async {
            guard !self.isStopped else { return }
            if Thread.isMainThread {
                webview?.evaluateJavaScript("addLoader('Processing next tasks ...')", completionHandler: nil)
            } else {
                DispatchQueue.main.async {
                    webview?.evaluateJavaScript("addLoader('Processing next tasks ...')", completionHandler: nil)
                }
            }
            // Use CursorStateManager to show loader
            //CursorStateManager.shared.showLoader()
        }
        
        screenCaptureService.captureFullScreen(completion: { result in
            guard !self.isStopped else { return }
            switch result {
            case .success(let image):
                // AppFocusManager.shared.bringTeckyToFront()
                VLMModelManager.shared.run(input: self.mlxPrompts.controlTask(prompt: prompt, openApps: Univo.getRunningAppNames(), appChoices: appChoices, image: image), completion: { result in
                    guard !self.isStopped else { return }
                    switch result {
                    case .success(let argumentsData):
                        if let data = argumentsData.data(using: .utf8),
                           let arguments = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            
                            let actionsRaw = arguments["actions"]
                            
                            let speechRaw = arguments["speech"]
                            
                            if let actions = actionsRaw as? [[String: Any]],
                               let speech = speechRaw as? String {
                                guard !self.isStopped else { return }
                                DispatchQueue.main.async {
                                    self.playSound(for: "stop")
                                    self.playSound(for: "close")
                                    TeckyAudioPlayer.shared.play(base64: speech)
                                    AppDelegate.shared?.mainWebView?.evaluateJavaScript("playBase64Audio('\(speech)')", completionHandler: nil)
                                }
                                Task {
                                    print("✅ Suitable actions found: \(actions)")
                                    await self.actionExecutor.performActions(actions, image: image!)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        AppFocusManager.shared.bringTeckyToFront()
                                    }
                                }
                            } else {
                                print("❌ No suitable actions found.")
                                if let data = argumentsData.data(using: .utf8) {
                                    print("Received arguments: \(String(data: data, encoding: .utf8) ?? "")")
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    AppFocusManager.shared.bringTeckyToFront()
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


    // MARK: - Audio Playback

    // Properties needed
    private var loadingAudioPlayers: [AVAudioPlayer] = []
    private var loadingSoundTimer: Timer?
    private var isLoadingSoundsActive: Bool = false

    func playSound(for caseType: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch caseType {
            case "open":
                self.playSingleSound(named: "www/audio/open.wav")
            case "close":
                self.playSingleSound(named: "www/audio/close.wav")
            case "loading":
                self.startLoadingSounds()
            case "stop":
                self.stopLoadingSounds()
            default:
                break
            }
        }
    }

    private func playSingleSound(named filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = 0.6
            player.play()
            self.loadingAudioPlayers.append(player)
            Timer.scheduledTimer(withTimeInterval: player.duration + 0.1, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.loadingAudioPlayers.removeAll { $0 === player }
            }
        } catch {
            print("❌ Error playing sound: \(error)")
        }
    }

    private func startLoadingSounds() {
        guard !isLoadingSoundsActive else { return }
        isLoadingSoundsActive = true

        loadingSoundTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self, self.isLoadingSoundsActive else { return }
            let soundFiles = [
                "www/audio/1.wav",
                "www/audio/2.wav",
                "www/audio/3.wav",
                "www/audio/4.wav"
            ]
            guard let randomFile = soundFiles.randomElement(),
                  let url = Bundle.main.url(forResource: randomFile, withExtension: nil) else {
                return
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.volume = 0.6
                player.play()
                self.loadingAudioPlayers.append(player)
                Timer.scheduledTimer(withTimeInterval: player.duration + 0.1, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    self.loadingAudioPlayers.removeAll { $0 === player }
                }
            } catch {
                print("❌ Error playing loading sound: \(error.localizedDescription)")
            }
        }
    }

    private func stopLoadingSounds() {
        isLoadingSoundsActive = false
        loadingSoundTimer?.invalidate()
        loadingSoundTimer = nil
        for player in loadingAudioPlayers {
            player.stop()
        }
        loadingAudioPlayers.removeAll()
    }
}


class Prompts {
    var accessibilityService: AccessibilityService = AccessibilityService()
}


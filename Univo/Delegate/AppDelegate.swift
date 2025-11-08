//  AppDelegate.swift
//  Controller
//
//  Created by Alex on 31.03.2025.
//

import Foundation
import Cocoa
import WebKit
import SwiftUI

class DraggableView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only capture clicks inside the strip’s bounds
        let localPoint = convert(point, from: superview)
        if bounds.contains(localPoint) {
            return super.hitTest(point)
        }
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

import AVFoundation
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

class AppDelegate: NSObject, NSApplicationDelegate {
    
    static weak var shared: AppDelegate?
    
    var window: NSWindow!
    
    public var glowController = GlowController()
    
    private var accessibilityService = AccessibilityService()

    var mainWindow: NSWindow?
    var miniWindow: NSWindow?
    var cursorWindowInstance: NSWindow?
    
    public var mainWebView: WKWebView?
    public var miniWebView: WKWebView?
    public var cursorWebView: WKWebView?
    
    // When the application finishes launching, request the
    //  accessibility permissions from the service class we
    //  made earlier.
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        let didComplete = UserDefaults.standard.bool(forKey: "hasCompletedOnboardingPermissions")
        
        // NSApp.appearance = NSAppearance(named: .darkAqua)
        
        //if !didComplete {
            recreateWindow()
        /*} else {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboardingUIWelcome")
            recreateWindow(fileName: "onboarding", onboarding: true)
        }*/
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if window == nil || window.isVisible == false {
            //recreateWindow()
        }
    }
    
    func triggerGlow(glow: Bool) {
        glowController.isPulsing = glow
    }
    

    private func createWindow(fileName: String,
                              windowSize: NSSize,
                              initialOrigin: NSPoint? = nil,
                              setWebView: @escaping (WKWebView) -> Void,
                              onboarding: Bool = false,
                              hasTitleBar: Bool = true,
                              hasGlowOverlay: Bool = true,
                              hasBorder: Bool = true,
                              cornerRadius: CGFloat = 26.0,
                              assignWindow: ((NSWindow) -> Void)? = nil) {
        let containerView = NSView()
        // ✅ Glass blur view or Liquid Glass
        let visualEffectView: NSView
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.cornerRadius = cornerRadius
            glassView.translatesAutoresizingMaskIntoConstraints = false
            glassView.alphaValue = 0.0
            glassView.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0)
            visualEffectView = glassView
        } else {
            let fallbackBlur = NSVisualEffectView()
            fallbackBlur.material = .menu
            fallbackBlur.blendingMode = .behindWindow
            fallbackBlur.state = .active
            fallbackBlur.translatesAutoresizingMaskIntoConstraints = false
            fallbackBlur.alphaValue = 0.0
            fallbackBlur.layer?.cornerRadius = cornerRadius
            visualEffectView = fallbackBlur
        }
        // ✅ Web content
        let contentView = NSHostingView(rootView: WebView(fileName: fileName, onWebViewCreated: { webView in
            setWebView(webView)
        }).padding(.top, hasTitleBar ? -28 : 0)) // Shift content up if title bar is present
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.alphaValue = 1.0
        
        // Add in correct order: visualEffectView, contentView, glowOverlay, draggableArea
        containerView.addSubview(visualEffectView)
        containerView.addSubview(contentView)
        
        // Pin them all to edges
        for view in [visualEffectView, contentView] {
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                view.topAnchor.constraint(equalTo: containerView.topAnchor),
                view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])
        }
        
        // Glowing animated border
        /*if hasGlowOverlay {
            let glowOverlay = NSHostingView(rootView: GlowEffect(controller: glowController))
            glowOverlay.translatesAutoresizingMaskIntoConstraints = false
            glowOverlay.wantsLayer = true
            glowOverlay.layer?.backgroundColor = .clear
            
            containerView.addSubview(glowOverlay)
            
            // Pin to edges
            NSLayoutConstraint.activate([
                glowOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                glowOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                glowOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
                glowOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])
        }*/
        // Draggable area (added last so it's above others, but only in the strip)
        let draggableArea = DraggableView()
        draggableArea.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(draggableArea)
        NSLayoutConstraint.activate([
            draggableArea.topAnchor.constraint(equalTo: containerView.topAnchor),
            draggableArea.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            draggableArea.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            draggableArea.heightAnchor.constraint(equalToConstant: 28)
        ])

        // Create the window
        let styleMask: NSWindow.StyleMask = hasTitleBar
                ? [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                : [.borderless]
            
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        assignWindow?(window)
        
        window.alphaValue = 0.0
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.contentView = containerView
        window.isOpaque = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.managed, .fullScreenNone]
        window.setFrame(window.frame, display: true)
        window.contentView?.wantsLayer = true

        if let titlebarView = window.standardWindowButton(.closeButton)?.superview {
            var frame = titlebarView.frame
            frame.origin.x += 8
            frame.origin.y -= 8 // AppKit's coordinate system: down is negative
            titlebarView.frame = frame
        }

        // Position window
        if let origin = initialOrigin {
            window.setFrameOrigin(origin)
        } else if let screen = NSScreen.main {
            // Center by default
            let screenFrame = screen.visibleFrame
            let centeredOrigin = NSPoint(
                x: screenFrame.origin.x + (screenFrame.size.width - windowSize.width) / 2,
                y: screenFrame.origin.y + (screenFrame.size.height - windowSize.height) / 2
            )
            window.setFrameOrigin(centeredOrigin)
        }

        if onboarding {
            window.makeKeyAndOrderFront(nil)
            // Fade out the traffic light button container (NSTitlebarView) initially
            if let titlebarView = window.standardWindowButton(.closeButton)?.superview {
                titlebarView.alphaValue = 0.0
            }
            let dimWindowControllers = NSScreen.screens.map { DimWindowController(screen: $0) }
            dimWindowControllers.forEach {
                $0.window?.alphaValue = 0.0
                $0.showWindow(nil)
            }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 2.0
                dimWindowControllers.forEach {
                    $0.window?.animator().alphaValue = 1.0
                }
            }, completionHandler: {
                if let videoURL = Bundle.main.url(forResource: "render", withExtension: "mov", subdirectory: "www/assets") {
                    let overlays = NSScreen.screens.map {
                        VideoOverlayWindowController(videoURL: videoURL, screen: $0)
                    }
                    overlays.forEach {
                        $0.showAndPlay()
                        $0.window?.level = .screenSaver + 1
                        $0.window!.makeKeyAndOrderFront(nil)
                    }
                    // Optionally fade them out later
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                        overlays.forEach { $0.fadeOutAndClose() }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    window.alphaValue = 0.0
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 1.0
                        window.animator().alphaValue = 1.0
                    }, completionHandler: nil)
                    AppDelegate.shared?.triggerGlow(glow: true)
                    // After 5 seconds, show window background + title bar
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        window.contentView?.wantsLayer = true
                        window.backgroundColor = .clear
                        window.contentView?.alphaValue = 0.0
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 1.0
                            window.contentView?.animator().alphaValue = 1.0
                            visualEffectView.animator().alphaValue = 1.0
                            if let titlebarView = window.standardWindowButton(.closeButton)?.superview {
                                titlebarView.animator().alphaValue = 1.0
                            }
                        }, completionHandler: {
                            window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0)
                            if let layer = window.contentView?.layer {
                                layer.borderColor = NSColor(calibratedWhite: 0.5, alpha: 0.5).cgColor
                                layer.borderWidth = 1.0
                                layer.cornerRadius = 26.0
                            }
                        })
                        // After another 3 seconds, fade out dim effect
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            NSAnimationContext.runAnimationGroup({ context in
                                context.duration = 0.5
                                dimWindowControllers.forEach {
                                    $0.window?.animator().alphaValue = 0.0
                                }
                            }, completionHandler: {
                                dimWindowControllers.forEach { $0.window?.orderOut(nil) }
                                window.level = .normal
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                AppDelegate.shared?.triggerGlow(glow: false)
                            }
                        }
                    }
                }
            })
        } else {
            window.makeKeyAndOrderFront(nil)
            if let titlebarView = window.standardWindowButton(.closeButton)?.superview {
                titlebarView.alphaValue = 1.0
            }
            visualEffectView.alphaValue = 1.0
            window.contentView?.wantsLayer = true
            window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0)
            if let layer = window.contentView?.layer {
                layer.borderWidth = hasBorder ? 1.0 : 0.0
                layer.cornerRadius = cornerRadius
            }
            window.alphaValue = 1.0
            window.level = .normal
        }
    }

    func recreateWindow(fileName: String = "index", onboarding: Bool = false) {
        createWindow(fileName: fileName,
                     windowSize: NSSize(width: 500, height: 500),
                     setWebView: { self.mainWebView = $0 },
                     onboarding: onboarding,
                     assignWindow: { self.mainWindow = $0 })
    }

    func recreateMiniWindow(fileName: String = "mini") {
        // Position bottom-right
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = NSSize(width: 300, height: 200)
        let bottomRightOrigin = NSPoint(
            x: screenFrame.maxX - windowSize.width - 20,
            y: screenFrame.minY + 20
        )
        createWindow(fileName: fileName,
                     windowSize: windowSize,
                     initialOrigin: bottomRightOrigin,
                     setWebView: { self.miniWebView = $0 },
                     assignWindow: { self.miniWindow = $0 })
        // Set miniWindow always on top
        self.miniWindow?.level = .floating
    }

    func removeMiniWindow() {
        if let window = self.miniWindow {
            window.orderOut(nil)
        }
        self.miniWebView = nil
        self.miniWindow = nil
    }
    
    private var cursorTimer: Timer?
    
    func createCursorWindow() {
        removeCursorWindow() // Ensure no duplicates

        let size = NSSize(width: 140, height: 40)
        
        createWindow(fileName: "cursor",
                     windowSize: size,
                     setWebView: { self.cursorWebView = $0 },
                     hasTitleBar: false,
                     hasGlowOverlay: false,
                     hasBorder: false,
                     cornerRadius: 20.0,
                     assignWindow: { self.cursorWindowInstance = $0 }) // <-- no title bar
        
        guard let cursorWindow = self.cursorWindowInstance else { return }

        cursorWindow.level = .floating
        cursorWindow.ignoresMouseEvents = true
        cursorWindow.hasShadow = false

        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak cursorWindow] _ in
            guard let window = cursorWindow else { return }
            let mouseLoc = NSEvent.mouseLocation
            let origin = NSPoint(
                x: mouseLoc.x + 20,
                y: mouseLoc.y - size.height + 20 // subtract height to position above cursor
            )
            window.setFrameOrigin(origin)
        }
    }
    
    func removeCursorWindow() {
        cursorTimer?.invalidate()
        cursorTimer = nil
        cursorWebView = nil
        if let window = self.cursorWindowInstance {
            window.orderOut(nil)
            self.cursorWindowInstance = nil
        }
    }
    
    func toggleCursorBackground(_ show: Bool) {
        guard let containerView = cursorWindowInstance?.contentView else { return }
        // visualEffectView is the first subview
        if let visualEffectView = containerView.subviews.first {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                visualEffectView.animator().alphaValue = show ? 1.0 : 0.0
            }, completionHandler: nil)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    // This method is called when the application is about to terminate.
    func applicationWillTerminate(_ notification: Notification) {
        // Call a method to terminate any running server processes
        
        
    }
    
    func hasScreenRecordingPermission() -> Bool {
        if #available(macOS 13.0, *) {
#if canImport(ScreenCaptureKit)
            let semaphore = DispatchSemaphore(value: 0)
            var hasPermission = false
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let error = error as? SCStreamError, error.code == .userDeclined { // Permission denied
                    hasPermission = false
                } else if error == nil {
                    hasPermission = true
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 2)
            return hasPermission
#else
            // Fallback, should not be needed
            return false
#endif
        } else {
            // Deprecated in macOS 14.0
            let image = CGWindowListCreateImage(.infinite, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])
            return image != nil
        }
    }
    
    @objc func handleMiniWindowDrag(_ sender: NSPanGestureRecognizer) {
            guard let window = self.window else { return }
            //let location = sender.location(in: window.contentView)
            switch sender.state {
            case .began:
                sender.setTranslation(.zero, in: window.contentView)
            case .changed:
                let translation = sender.translation(in: window.contentView)
                var newOrigin = window.frame.origin
                newOrigin.x += translation.x
                newOrigin.y += translation.y
                window.setFrameOrigin(newOrigin)
                sender.setTranslation(.zero, in: window.contentView)
            default:
                break
            }
        }
}

class CursorStateManager {
    static let shared = CursorStateManager()
    
    private var queue: [() -> Void] = []
    private var isRunning = false
    
    private let minDelay: TimeInterval = 2.0
    
    private func processNext() {
        guard !queue.isEmpty else {
            isRunning = false
            return
        }
        
        isRunning = true
        let next = queue.removeFirst()
        next()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + minDelay) {
            self.processNext()
        }
    }
    
    func enqueue(_ action: @escaping () -> Void) {
        queue.append(action)
        if !isRunning {
            processNext()
        }
    }
    
    // Convenience wrappers for each cursor state:
    func showLoader() {
        enqueue {
            AppDelegate.shared?.cursorWebView?.evaluateJavaScript("cursorShowLoader()", completionHandler: nil)
            AppDelegate.shared?.toggleCursorBackground(false)
        }
    }
    
    func showUpdate(_ reasoning: String) {
        enqueue {
            AppDelegate.shared?.cursorWebView?.evaluateJavaScript("cursorContinueLoader('\(reasoning)')", completionHandler: nil)
            AppDelegate.shared?.toggleCursorBackground(true)
        }
    }
    
    func showMessage(_ text: String) {
        enqueue {
            AppDelegate.shared?.cursorWebView?.evaluateJavaScript("cursorContinueLoader('\(text)')", completionHandler: nil)
            AppDelegate.shared?.toggleCursorBackground(true)
        }
    }
}

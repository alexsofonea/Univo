//
//  Onboarding.swift
//  Controller
//
//  Created by Alex on 03.05.2025.
//

import Cocoa
import AVKit

class DimWindowController: NSWindowController {
    init(screen: NSScreen) {
        let screenFrame = screen.frame
        let dimWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        dimWindow.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        dimWindow.level = .screenSaver  // Above all regular windows
        dimWindow.ignoresMouseEvents = true
        dimWindow.isOpaque = false
        dimWindow.hasShadow = false

        super.init(window: dimWindow)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class VideoOverlayWindowController: NSWindowController {
    private var player: AVPlayer?

    init(videoURL: URL, screen: NSScreen) {
        let screenFrame = screen.frame

        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let playerView = NSView(frame: screenFrame)
        let playerLayer = AVPlayerLayer()

        playerLayer.frame = screenFrame
        playerLayer.videoGravity = .resizeAspectFill
        playerView.wantsLayer = true
        playerView.layer = playerLayer
        window.contentView = playerView

        super.init(window: window)

        self.player = AVPlayer(url: videoURL)
        playerLayer.player = self.player
        playerLayer.backgroundColor = nil
        playerLayer.isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndPlay() {
        guard let window = self.window else { return }

        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)

        // Force it to top again just in case
        window.level = .screenSaver + 1
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 1.0
            window.animator().alphaValue = 1.0
        }, completionHandler: {
            self.player?.play()
        })
    }

    func fadeOutAndClose(after delay: TimeInterval = 3.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 1.0
                self.window?.animator().alphaValue = 0.0
            }, completionHandler: {
                //self.window?.orderOut(nil)
                self.player?.pause()
                self.player = nil
            })
            self.player?.pause()
            self.player = nil
        }
    }
}

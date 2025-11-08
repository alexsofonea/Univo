//
//  Glow.swift
//  Controller
//
//  Created by Alex on 15.04.2025.
//

import SwiftUI


class GlowWindowController {
    private var screenControllers: [GlowWindowScreenController] = []

    init() {
        screenControllers = NSScreen.screens.map { GlowWindowScreenController(screen: $0) }
    }

    func show() {
        screenControllers.forEach { $0.show() }
    }

    func dismiss() {
        screenControllers.forEach { $0.dismiss() }
    }
}

class GlowWindowScreenController {
    private var window: NSWindow!
    private var hostingView: NSHostingView<ScreenGlowEffect>!
    private var controller = ScreenGlowController()

    init(screen: NSScreen) {
        let screenFrame = screen.frame

        window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        hostingView = NSHostingView(rootView: ScreenGlowEffect(controller: controller))
        hostingView.frame = screenFrame
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        
        window.hasShadow = false
        window.hidesOnDeactivate = true
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        controller.isPulsing = true
    }

    func dismiss() {
        controller.isPulsing = false
        window.orderOut(nil)
    }
}


class ScreenGlowController: ObservableObject {
    @Published var isPulsing: Bool = false
    @Published var pulseStrength: CGFloat = 0
}

struct ScreenGlowEffect: View {
    @ObservedObject var controller: ScreenGlowController
    @State private var gradientStops: [Gradient.Stop] = ScreenGlowEffect.generateGradientStops()
    @State private var gradientAngle: Double = 0
    let cornerRadius: CGFloat = 0

    var body: some View {
        ZStack {
            ScreenEffectNoBlur(gradientStops: gradientStops, width: controller.pulseStrength * 3, cornerRadius: cornerRadius, gradientAngle: gradientAngle)
            ScreenEffect(gradientStops: gradientStops, width: controller.pulseStrength * 6, blur: 4, cornerRadius: cornerRadius, gradientAngle: gradientAngle)
            ScreenEffect(gradientStops: gradientStops, width: controller.pulseStrength * 8, blur: 12, cornerRadius: cornerRadius, gradientAngle: gradientAngle)
            ScreenEffect(gradientStops: gradientStops, width: controller.pulseStrength * 10, blur: 15, cornerRadius: cornerRadius, gradientAngle: gradientAngle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                withAnimation(.linear(duration: 0.08)) {
                    gradientAngle += 1
                }
            }
            Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.8)) {
                    gradientStops = ScreenGlowEffect.generateGradientStops()
                }
            }
        }
        .onReceive(controller.$isPulsing) { pulsing in
            if pulsing {
                startPulsing()
            } else {
                stopPulsing()
            }
        }
        .animation(.easeInOut(duration: 0.6), value: gradientStops)
        .animation(.easeInOut(duration: 1), value: controller.pulseStrength)
    }
    
    @State private var pulsingTimer: Timer?
    @State private var internalPulseStrength: CGFloat = 0

    func startPulsing() {
        stopPulsing()
        pulsingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                internalPulseStrength = internalPulseStrength == 1 ? 0.7 : 1
                controller.pulseStrength = internalPulseStrength
            }
        }
    }

    func stopPulsing() {
        pulsingTimer?.invalidate()
        pulsingTimer = nil
        withAnimation(.easeInOut(duration: 0.5)) {
            internalPulseStrength = 0
            controller.pulseStrength = 0
        }
    }

    static func generateGradientStops() -> [Gradient.Stop] {
        [
            Gradient.Stop(color: Color(hex: "8726B7"), location: 0),
            Gradient.Stop(color: Color(hex: "98F9FF"), location: 0.25),
            Gradient.Stop(color: Color(hex: "FFFFFF"), location: 0.45), // 👈 white adds motion!
            Gradient.Stop(color: Color(hex: "98F9FF"), location: 0.7),
            Gradient.Stop(color: Color(hex: "8726B7"), location: 1)
        ].sorted { $0.location < $1.location }
    }
}

struct ScreenEffect: View {
    var gradientStops: [Gradient.Stop]
    var width: CGFloat
    var blur: CGFloat
    var cornerRadius: CGFloat
    var gradientAngle: Double

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    AngularGradient(gradient: Gradient(stops: gradientStops), center: .center, angle: .degrees(gradientAngle)),
                    lineWidth: width
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .blur(radius: blur)
        }
    }
}

struct ScreenEffectNoBlur: View {
    var gradientStops: [Gradient.Stop]
    var width: CGFloat
    var cornerRadius: CGFloat
    var gradientAngle: Double

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    AngularGradient(gradient: Gradient(stops: gradientStops), center: .center, angle: .degrees(gradientAngle)),
                    lineWidth: width
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

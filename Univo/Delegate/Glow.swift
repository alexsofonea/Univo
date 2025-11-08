//
//  Glow.swift
//  Controller
//
//  Created by Alex on 15.04.2025.
//

import SwiftUI

class GlowController: ObservableObject {
    @Published var isPulsing: Bool = false
    @Published var pulseStrength: CGFloat = 0
}

struct GlowEffect: View {
    @ObservedObject var controller: GlowController
    @State private var gradientStops: [Gradient.Stop] = GlowEffect.generateGradientStops()
    @State private var gradientAngle: Double = 0
    let cornerRadius: CGFloat = 26

    var body: some View {
        ZStack {
            EffectNoBlur(gradientStops: gradientStops, width: controller.pulseStrength * 3, cornerRadius: cornerRadius, gradientAngle: gradientAngle)
            Effect(gradientStops: gradientStops, width: controller.pulseStrength * 6, blur: 4, cornerRadius: cornerRadius, gradientAngle: gradientAngle)
            Effect(gradientStops: gradientStops, width: controller.pulseStrength * 8, blur: 12, cornerRadius: cornerRadius, gradientAngle: gradientAngle)
            Effect(gradientStops: gradientStops, width: controller.pulseStrength * 10, blur: 15, cornerRadius: cornerRadius, gradientAngle: gradientAngle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
                withAnimation(.linear(duration: 0.03)) {
                    gradientAngle += 1
                }
            }
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.6)) {
                    gradientStops = GlowEffect.generateGradientStops()
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

struct Effect: View {
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
                .frame(width: geometry.size.width, height: geometry.size.height + 32)
                .blur(radius: blur)
                .padding(.top, -32)
        }
    }
}

struct EffectNoBlur: View {
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
                .frame(width: geometry.size.width, height: geometry.size.height + 32)
                .padding(.top, -32)
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")

        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)

        let r = Double((hexNumber & 0xff0000) >> 16) / 255
        let g = Double((hexNumber & 0x00ff00) >> 8) / 255
        let b = Double(hexNumber & 0x0000ff) / 255

        self.init(red: r, green: g, blue: b)
    }
}

//
//  ConfettiView.swift
//  lab3
//
//  Created by cisstudent on 10/30/25.
//

import SwiftUI

// this is for showing some confetti when we win
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var size: Double
    var opacity: Double
    var duration: Double
}

// a view to show some confetti
struct ConfettiView: View {
    @State private var confetti = [ConfettiParticle]()
    let colors: [Color] = [
        .red, .blue, .green, .orange, .purple, .pink, .yellow,
    ]

    // Tunables
    private let particlesPerBurst: Int = 120    // was 60
    private let burstCount: Int = 1            // number of bursts
    private let burstInterval: Double = 0.25    // seconds between bursts
    private let fallDurationRange: ClosedRange<Double> = 1.2...2.4
    private let sizeRange: ClosedRange<Double> = 8...18

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(confetti) { particle in
                    Circle()
                        .fill(colors.randomElement() ?? .blue)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                        .animation(
                            .easeOut(duration: particle.duration),
                            value: particle.y
                        )
                }
            }
            .onAppear {
                // Spawn multiple bursts for "more confetti"
                for burstIndex in 0..<burstCount {
                    let delay = Double(burstIndex) * burstInterval
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        spawnBurst(in: geo.size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnBurst(in size: CGSize) {
        // Remember the starting index so we can animate only the new particles
        let startIndex = confetti.count

        // Create new particles across the width (slightly above top)
        let newParticles = (0..<particlesPerBurst).map { _ in
            ConfettiParticle(
                x: Double.random(in: 0...size.width),
                y: -20,
                size: Double.random(in: sizeRange),
                opacity: 1,
                duration: Double.random(in: fallDurationRange)
            )
        }

        confetti.append(contentsOf: newParticles)

        // Animate the newly added particles to fall to the bottom and fade out
        withAnimation(.easeOut(duration: 2)) {
            for idx in startIndex..<confetti.count {
                confetti[idx].y = size.height + 40
                confetti[idx].opacity = 0
            }
        }
    }
}
#Preview {
    ConfettiView()
}

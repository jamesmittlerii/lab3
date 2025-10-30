//
//  FireworksView.swift
//  lab3
//
//  Created by cisstudent on 10/30/25.
//

import SwiftUI

struct FireworkParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var dx: Double
    var dy: Double
    var size: Double
    var hue: Double
    var opacity: Double
    var duration: Double
}

struct FireworksView: View {
    @State private var particles: [FireworkParticle] = []
    private let launchCount = 6
    // Bigger bursts
    private let particlesPerBurst = 60
    private let gravity: Double = 140 // points/sec^2

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    // Add a soft glow to make particles feel larger/brighter
                    context.addFilter(.shadow(color: .white.opacity(0.35), radius: 6, x: 0, y: 0))
                    for p in particles {
                        let color = Color(hue: p.hue, saturation: 0.9, brightness: 1.0, opacity: p.opacity)
                        context.fill(
                            Path(ellipseIn: CGRect(x: p.x, y: p.y, width: p.size, height: p.size)),
                            with: .color(color)
                        )
                    }
                }
                .onAppear {
                    spawnFireworks(in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnFireworks(in size: CGSize) {
        particles.removeAll()

        // Schedule multiple launches
        for launchIndex in 0..<launchCount {
            let delay = Double(launchIndex) * 0.50
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let launchX = Double.random(in: size.width * 0.2...size.width * 0.8)
                let launchY = Double(size.height) + 10
                let peakY = Double.random(in: size.height * 0.25...size.height * 0.45)

                // Create a "rocket" particle that will explode at peak
                let ascentDuration = 0.6
                let rocket = FireworkParticle(
                    x: launchX,
                    y: launchY,
                    dx: 0,
                    dy: -Double.random(in: 300...420),
                    size: 10, // bigger rocket
                    hue: Double.random(in: 0...1),
                    opacity: 1.0,
                    duration: ascentDuration
                )
                particles.append(rocket)

                // Animate rocket upward
                withAnimation(.easeOut(duration: ascentDuration)) {
                    let targetY = peakY
                    if let idx = particles.firstIndex(where: { $0.id == rocket.id }) {
                        particles[idx].y = targetY
                        particles[idx].opacity = 0.0
                        particles[idx].size = 3
                    }
                }

                // After ascent, create burst particles
                DispatchQueue.main.asyncAfter(deadline: .now() + ascentDuration) {
                    let burstOrigin = CGPoint(x: launchX, y: peakY)
                    let baseHue = Double.random(in: 0...1)
                    let burst = (0..<particlesPerBurst).map { i -> FireworkParticle in
                        let angle = Double(i) / Double(particlesPerBurst) * 2.0 * .pi
                        // faster particles for a larger-looking burst
                        let speed = Double.random(in: 120...240)
                        let dx = cos(angle) * speed
                        let dy = sin(angle) * speed
                        return FireworkParticle(
                            x: burstOrigin.x,
                            y: burstOrigin.y,
                            dx: dx,
                            dy: dy,
                            size: Double.random(in: 6...12), // larger particle size
                            hue: fmod(baseHue + Double.random(in: -0.1...0.1) + 1, 1),
                            opacity: 1.0,
                            duration: 1.2
                        )
                    }
                    particles.append(contentsOf: burst)

                    // Animate burst outward + fade + gravity
                    let steps = 24
                    let stepDuration = 1.2 / Double(steps)
                    for step in 1...steps {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                            for idx in particles.indices {
                                // Only update particles that are part of the burst (size <= 12 is a cheap heuristic)
                                guard particles[idx].size <= 12 else { continue }
                                let t = Double(step) * stepDuration
                                particles[idx].x += particles[idx].dx * stepDuration
                                particles[idx].y += particles[idx].dy * stepDuration + 0.5 * gravity * stepDuration * stepDuration
                                particles[idx].dy += gravity * stepDuration
                                particles[idx].opacity = max(0, 1.0 - t / 1.2)
                            }
                        }
                    }
                }
            }
        }
    }
}
#Preview {
    FireworksView()
}

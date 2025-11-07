/**
 
 * __Partner Lab 3__
 * Jim Mittler, Dave Norvall
 * Group 11
 * 7 November  2025
 
 This view does some confetti  when we win
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import SwiftUI

// this is for showing some confetti when we win
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double // Current Y position
    var fallToY: Double // Where it ends (bottom of screen)
    var launchToY: Double // Where it launches to (top of screen)
    var size: Double
    var opacity: Double
    var duration: Double // Duration for the fall phase
}

// a view to show some confetti
struct ConfettiView: View {
    @State private var confetti = [ConfettiParticle]()
    let colors: [Color] = [
        .red, .blue, .green, .orange, .purple, .pink, .yellow,
    ]

    // Tunables
    private let particlesPerBurst: Int = 120
    private let burstCount: Int = 1
    private let burstInterval: Double = 0.25
    private let fallDurationRange: ClosedRange<Double> = 1.2...2.4 // Fall time
    private let sizeRange: ClosedRange<Double> = 8...18
    
    private let launchDuration: Double = 0.8 // Duration of the initial upward launch
    
    // How long into the fall before the fade starts (as a percentage).
        private let fadeStartFactor: Double = 0.75

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(confetti) { particle in
                    Circle()
                        .fill(colors.randomElement() ?? .blue)
                        .frame(width: particle.size, height: particle.size)
                        // Positioning based on current Y
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                        // **MODIFICATION 1: REMOVE ANIMATION HERE**
                        // We will handle all animations explicitly in spawnBurst
                }
            }
            .onAppear {
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
        let startIndex = confetti.count
        
        // --- 1. Define start and end Y values ---
        let startY = size.height + 20 // Off-screen bottom
        let endY = size.height + 20 // Off-screen bottom (The fall destination)

        // Create new particles along the bottom edge
        let newParticles = (0..<particlesPerBurst).map { _ in
            let randomX = Double.random(in: 0...size.width)
            // Launch to the top edge (y=0) or slightly beyond for a better effect
            let launchY = Double.random(in: -150.0...0.0) // was -30.0...0.0
                
            return ConfettiParticle(
                x: randomX,
                y: startY, // Start off-screen at the bottom
                fallToY: endY, // Destination for the fall
                launchToY: launchY, // Destination for the launch
                size: Double.random(in: sizeRange),
                opacity: 1,
                duration: Double.random(in: fallDurationRange)
            )
        }

        confetti.append(contentsOf: newParticles)

        // Initial Upward Launch Animation (STAGE 1) ---
        // This moves all particles to launchToY (the top)
        withAnimation(.easeOut(duration: launchDuration)) {
            for idx in startIndex..<confetti.count {
                confetti[idx].y = confetti[idx].launchToY // Move to the top
            }
        }
            
        for idx in startIndex..<confetti.count {
                let particleDuration = confetti[idx].duration
                
                DispatchQueue.main.asyncAfter(deadline: .now() + launchDuration) {
                    
                    // Calculate the duration for the quick fade (e.g., last 25% of fall time)
                    let fadeDuration = particleDuration * (1.0 - fadeStartFactor)
                    
                    // The total fall animation is a combination of two animations:
                    
                    // Move position with full opacity.
                    //    This animation covers the entire duration.
                    withAnimation(.linear(duration: particleDuration)) {
                        confetti[idx].y = confetti[idx].fallToY
                    }
                    
                    // Change opacity near the end of the fall.
                    //    We delay the opacity change until the end of the full duration.
                    DispatchQueue.main.asyncAfter(deadline: .now() + (particleDuration * fadeStartFactor)) {
                        
                        withAnimation(.easeOut(duration: fadeDuration)) {
                            confetti[idx].opacity = 0 // Fades out over the remaining time
                        }
                    }
                }
            }
            
        // Remove particles after they fall to clear memory
        let maxDuration = fallDurationRange.upperBound + launchDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + maxDuration + 0.1) {
            confetti.removeFirst(newParticles.count)
        }
    }
}

#Preview {
    ConfettiView()
}

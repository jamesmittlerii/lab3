import SwiftUI

/**
 
 * __Partner Lab 3__
 * Jim Mittler, Dave Norvall
 * Group 11
 * 7 November  2025
 
 This view does a little ballon animation we play when we win
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

// the basic particle

struct BalloonParticle: Identifiable {
    let id = UUID()
    var x: Double            // Current X position
    var y: Double            // Current Y position
    var initialX: Double     // Starting X position
    var size: Double         // Size of the balloon
    var hue: Double          // Color hue (0-1)
    var speed: Double        // How fast it moves up
    var driftMagnitude: Double // How much it drifts horizontally
    var opacity: Double      // Current opacity
    var delay: Double        // Delay before it starts animating
    var duration: Double     // Total animation duration
}

// the view
struct BalloonAscentView: View {
    @State private var balloons: [BalloonParticle] = []
    
    // Tunables
    private let numberOfBalloons: Int = 20
    private let spawnInterval: Double = 0.1 // Time between each balloon appearing
    private let minBalloonSize: Double = 40
    private let maxBalloonSize: Double = 80
    private let minSpeed: Double = 0.5     // How fast it ascends (higher value = slower ascent)
    private let maxSpeed: Double = 1.2     // How fast it ascends (lower value = faster ascent)
    private let minDriftMagnitude: Double = 0.1 // Less drift
    private let maxDriftMagnitude: Double = 0.8 // More drift
    private let minDelay: Double = 0.0
    private let maxDelay: Double = 2.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(balloons) { balloon in
                    BalloonShape() // Custom shape for a balloon
                        .fill(Color(hue: balloon.hue, saturation: 0.8, brightness: 0.9))
                        .frame(width: balloon.size, height: balloon.size * 1.3) // Balloons are taller than wide
                        .position(x: balloon.x, y: balloon.y)
                        .opacity(balloon.opacity)
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 2, y: 2)
                        .animation(.linear(duration: balloon.duration), value: balloon.y) // Animate Y position
                        .animation(.linear(duration: balloon.duration), value: balloon.x) // Animate X position
                        .animation(.easeOut(duration: balloon.duration * 0.3), value: balloon.opacity) // Fade out at end
                }
            }
            .onAppear {
                generateBalloons(in: geo.size)
            }
        }
        .allowsHitTesting(false) // Don't block interactions behind the balloons
    }
    
    // build our ballons
     private func generateBalloons(in size: CGSize) {
        for _ in 0..<numberOfBalloons {
            let delay = Double.random(in: minDelay...maxDelay)
            
            // Generate a random initial X position
            let initialX = Double.random(in: size.width * 0.1...size.width * 0.9)
            
            let balloon = BalloonParticle(
                x: initialX,
                y: size.height + (maxBalloonSize / 2), // Start slightly off-screen bottom
                initialX: initialX,
                size: Double.random(in: minBalloonSize...maxBalloonSize),
                hue: Double.random(in: 0...1), // Random color hue
                speed: Double.random(in: minSpeed...maxSpeed),
                driftMagnitude: Double.random(in: minDriftMagnitude...maxDriftMagnitude),
                opacity: 1.0,
                delay: delay,
                duration: 0 // Duration will be calculated per balloon later
            )
            
            balloons.append(balloon)
            
            // Trigger animation for each balloon after its specific delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if let index = balloons.firstIndex(where: { $0.id == balloon.id }) {
                    animateBalloon(at: index, in: size)
                }
            }
        }
    }
    
        private func animateBalloon(at index: Int, in size: CGSize) {
            var currentBalloon = balloons[index]
            
            // We'll use the randomized speed to vary the duration, but cap it near 3.0 seconds.
            let maxDuration: Double = 3.0
            
            // Calculate the base duration based on speed and cap it at maxDuration
            // The current formula is: distance / (100 / speed).
            // Let's invert it to calculate duration directly based on speed factor:
            let durationFactor = currentBalloon.speed // speed is between 0.5 and 1.2
            let duration = maxDuration * durationFactor / maxSpeed // maxSpeed is 1.2
            
            // Use a simple duration between 2.5 and 3.0 seconds for consistency
            let finalDuration = max(2.5, min(maxDuration, duration))
            
            currentBalloon.duration = finalDuration // Set the calculated duration
            
            // Final Y position (off-screen top)
            let finalY = -(currentBalloon.size / 2)
            
            // Final X position (with drift)
            let driftAmount = currentBalloon.driftMagnitude * (size.width / 4)
            let finalX = currentBalloon.initialX + (Bool.random() ? driftAmount : -driftAmount)
            
            // Update the balloon immediately to set up the animation
            balloons[index] = currentBalloon
            
            // Use the calculated finalDuration for the animation
            withAnimation(.linear(duration: finalDuration)) {
                balloons[index].y = finalY
                balloons[index].x = finalX
                balloons[index].opacity = 0.0
            }
            
            // Remove the balloon after its animation is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + finalDuration) {
                balloons.removeAll(where: { $0.id == currentBalloon.id })
            }
        }
}

// our ballon shape
struct BalloonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Main balloon body (oval)
        path.addEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.9))
        
        // Small triangle for the tie-off
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.08, y: rect.maxY * 0.9))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.08, y: rect.maxY * 0.9))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)) // Point of the tie-off
        path.closeSubpath()
        
        return path
    }
}

#Preview {
        BalloonAscentView()
}

/**
 
 * __Partner Lab 3__
 * Jim Mittler
 * 20 October 2025
 
 
 We've updated our Game to use MVVM architecture
 
 all the game logic is moved to the GameModel class
 
 ContentView contains the UI logic and the code to support showing the global leaderboard
 
 The game connects to Game Center to keep track of personal best and show a global leaderboard of all the players
 
 We show a 4x6 grid of randomly shuffled tile pairs.
 If you match two tiles they remain face up until you complete the game.
 We show some confetti when you win.
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import Combine
import GameKit
import SwiftUI

/* this is our structure for the tiled card in the UI */

import SwiftUI

struct TiledCard: View {
    // MARK: - Properties
    let card: Card // Assuming Card has var isFaceUp: Bool
    let isMatchWiggling: Bool
    let isWinWiggling: Bool
    let onTap: () -> Void

    @State private var rotationAngle: Angle = .zero
    // The rotation state tracks the current flip position (0 for back, 180 for front)
    @State private var flipRotation: Double = 0
    
    // Derived property for the 3D rotation value
    private var rotationDegrees: Double { card.isFaceUp ? 180 : 0 }

    var body: some View {
        ZStack {
            // FRONT Face: Starts facing the user. Becomes visible when flipRotation reaches 90+.
            Group {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.white)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(lineWidth: 3)
                    .foregroundColor(.blue)
                Image(card.content)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            // Opacity: Only visible when rotated halfway or more
            .opacity(flipRotation >= 90 ? 1.0 : 0.0)

            // BACK Face: Rotated 180 degrees initially so it faces away from the user.
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.blue)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            // Opacity: Only visible when rotated less than halfway
            .opacity(flipRotation < 90 ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .rotationEffect(rotationAngle)
        // The rotation is applied to the ZStack, flipping both faces simultaneously
        .rotation3DEffect(.degrees(flipRotation), axis: (x: 0, y: 1, z: 0))
        .onTapGesture { onTap() }
        
        // MARK: - State & Animation Handlers

        // Animate the card flip when isFaceUp changes
        .onChange(of: card.isFaceUp) { _, newValue in
            withAnimation(.easeInOut(duration: 0.4)) {
                // Instantly update the rotation value, letting SwiftUI animate
                flipRotation = newValue ? 180 : 0
            }
        }
        // Wiggle animations remain the same, but simplified Task syntax
        .onChange(of: isMatchWiggling) { _, shouldWiggle in
            guard shouldWiggle else { return }
            performWiggle(duration: 0.5)
        }
        .onChange(of: isWinWiggling) { _, shouldWiggle in
            guard shouldWiggle else { return }
            performWiggle(duration: 2.0)
        }
        .onAppear {
            // Set initial state without animation
            flipRotation = card.isFaceUp ? 180 : 0
        }
    }

    // MARK: - Wiggle Animation (Slightly Cleaned)

    private func performWiggle(duration: Double) {
        let singleWiggleDuration = 0.125
        let wiggles = Int(duration / singleWiggleDuration)
        let animation = Animation.linear(duration: singleWiggleDuration)
        let pause = UInt64(singleWiggleDuration * 1_000_000_000)
        let wiggleAngle: Double = 4

        Task {
            for i in 0..<wiggles {
                let angle = (i % 2 == 0) ? wiggleAngle : -wiggleAngle
                withAnimation(animation) { rotationAngle = .degrees(angle) }
                // Sleep using the Task API is excellent here
                try? await Task.sleep(nanoseconds: pause)
            }
            withAnimation(animation) { rotationAngle = .zero }
        }
    }
}





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
                confetti = (0..<60).map { _ in
                    ConfettiParticle(
                        x: Double.random(in: 0...geo.size.width),
                        y: -20,
                        size: Double.random(in: 8...18),
                        opacity: 1,
                        duration: Double.random(in: 1.0...2.2)
                    )
                }
                withAnimation(.easeOut(duration: 2)) {
                    for idx in confetti.indices {
                        confetti[idx].y = geo.size.height + 40
                        confetti[idx].opacity = 0
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}



// this is the main view for the game
struct ContentView: View {

    // use a variable to determine if we are iphone or ipad
    // unfortunately we need to tweak because the screen ratios and sizes are so different
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // our object classes for MVVM
    @StateObject private var gameCenterManager: GameCenterManager
    @StateObject private var model: GameModel

    // initialize our object classes
    // some shenanigans because the model needs to access the game manager
    init() {
        let manager = GameCenterManager()
        _gameCenterManager = StateObject(wrappedValue: manager)
        _model = StateObject(
            wrappedValue: GameModel(gameCenterManager: manager)
        )
    }

    // anything with @state will refresh the UI on change
    @State private var showConfetti = false
    @State private var showingLeaderboard = false
    @State private var wigglingIndices = Set<Int>()
    
    // the grid layout logic got nasty so moved to a function
    // this structure returns the calculations
    struct GridParameters {
        let itemWidth: CGFloat
        let itemHeight: CGFloat
        let columnCount: Int
        let spacing: CGFloat
        let columns: [GridItem]
    }

    // this is the logic to make the grid look nice
    // unfortunately it's a nightmare so it lives in a function
    
    @MainActor // Use @MainActor since it uses UIDevice.current
    private func calculateGridParameters(
        geometry: GeometryProxy,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> GridParameters {
        
        // --- Setup and Context ---
        let isLandscape = geometry.size.width > geometry.size.height
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        // Use optional chaining with a fallback for horizontalSizeClass
       // let isRegular = horizontalSizeClass == .regular
       
        let spacing: CGFloat = isPhone ? 12 : 24

        // we use 4x6 for portrait
        // 8x3 on phone landscape and 6x4 on ipad landscape
        // that seemed to look best
        
        let aspectRatio: CGFloat = 2.0 / 3.0 // Width / Height
        let columnCount: Int = isLandscape ? (isPhone ? 8 : 6) : 4
        let rowCount: Int = isLandscape ? (isPhone ? 3 : 4) : 6

        // --- Available Space Calculation ---
        let totalHorizontalSpacing = spacing * (CGFloat(columnCount) - 1)
        let totalVerticalSpacing = spacing * (CGFloat(rowCount) - 1)

        let availableWidth = max(0, geometry.size.width - totalHorizontalSpacing)
        let availableHeight = max(0, geometry.size.height - totalVerticalSpacing)

        // --- Tile Size Calculation (Constrained by Width and Height) ---
        
        // Size if constrained by width
        let widthFromWidthConstraint = availableWidth / CGFloat(columnCount)
        let heightFromWidthConstraint = widthFromWidthConstraint / aspectRatio

        // Size if constrained by height
        let heightFromHeightConstraint = availableHeight / CGFloat(rowCount)
        let widthFromHeightConstraint = heightFromHeightConstraint * aspectRatio
        
        // Choose the smaller size to ensure the grid fits entirely
        let (itemWidth, itemHeight): (CGFloat, CGFloat) =
            (heightFromWidthConstraint <= heightFromHeightConstraint)
        ? (widthFromWidthConstraint, heightFromWidthConstraint)   // Width is limiting
            : (widthFromHeightConstraint, heightFromHeightConstraint) // Height is limiting

        // create our grid item array
        // we were very determined to find the best itemWidth
        let columns = Array(
            repeating: GridItem(.fixed(itemWidth), spacing: spacing),
            count: columnCount
        )
        
        // kick back our calculations
        return GridParameters(
            itemWidth: itemWidth,
            itemHeight: itemHeight,
            columnCount: columnCount,
            spacing: spacing,
            columns: columns
        )
    }

    
    // this is our main view...finally!
    var body: some View {
        // Device-based font sizing
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let textFont: Font = isPhone ? .headline : .title
        let buttonIconFont: Font = isPhone ? .body : .title
        
        ZStack {
            VStack(spacing: 8) {
                
                // top bar is info and buttons
                
                HStack(spacing: 8) {
                    Text("Flips: \(model.flipCount)")
                        .font(textFont)
                        .foregroundColor(.blue)
                    Text(
                        {
                            if let best = model.personalBest {
                                return "High Score: \(best)"
                            } else {
                                return "High Score: --"
                            }
                        }()
                    )
                    .font(textFont)
                    .foregroundColor(.green)

                    // new game icon
                    Button {
                        model.newGame()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                            .accessibilityLabel("New Game")
                            .font(buttonIconFont)
                    }
                    .help("Start a new game")

                    // global leadboard icon
                    Button {
                        Task {
                            // Load leaderboard list (optional sanity check)
                            do {
                                _ = try await GKLeaderboard.loadLeaderboards(
                                    IDs: [gameCenterManager.leaderboardID])
                            } catch {
                                print(
                                    "Error loading leaderboard: \(error.localizedDescription)"
                                )
                            }
                            // Present Game Center leaderboard view controller
                            presentLeaderboard()
                        }
                    } label: {
                        Label("Leaderboard", systemImage: "trophy")
                            .labelStyle(.iconOnly)
                            .foregroundColor(
                                gameCenterManager.isAuthenticated ? .orange : .gray
                            )
                            .accessibilityLabel("Show Leaderboard")
                            .font(buttonIconFont)
                    }
                    .disabled(!gameCenterManager.isAuthenticated)
                    .help("Show global leaderboard")
                }
                .padding(.bottom, 4)

                // do the grid via GeometryReader and function
                
                GeometryReader { geometry in
                    let params = calculateGridParameters(
                        geometry: geometry,
                        horizontalSizeClass: horizontalSizeClass
                    )

                    VStack(spacing: 8) {
                        // trusty LazyVGrid
                        LazyVGrid(columns: params.columns, spacing: params.spacing) {
                            
                            // spin through our cards
                            // send each TileCard our wiggle flags
                            
                            ForEach(model.cards.indices, id: \.self) { idx in
                                TiledCard(
                                    card: model.cards[idx],
                                    isMatchWiggling: wigglingIndices.contains(idx),
                                    isWinWiggling: showConfetti
                                ) {
                                    // secret sauce closure to handle flip card logic in the model
                                    model.flip(cardAt: idx)
                                }
                                // Set the frame to our calculated size.
                                // The aspect ratio is already handled in the calculation.
                                .frame(width: params.itemWidth, height: params.itemHeight)
                            }
                        }
                        // Keep grid full width; it will take remaining height
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()

            // if we won, show some confetti
            // this floats on top
            if showConfetti {
                ConfettiView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        // the confetti we throw up when we win
        .animation(.default, value: showConfetti)

        // Bottom progress section pinned to the safe area
        // fitting the grid seems to be tricky
        // here we just pin to the bottom and that seems to do the trick
        .safeAreaInset(edge: .bottom) {
            let percent = Int((model.progress * 100).rounded())
            HStack {
                VStack(spacing: 6) {
                    HStack {
                        Text("Progress")
                            .font(isPhone ? .subheadline : .headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(percent)%")
                            .font(isPhone ? .subheadline : .headline)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: model.progress)
                        .tint(.blue)
                        .animation(.easeInOut(duration: 0.25), value: model.progress)
                }
                
            }
            // I tried setting the horizontal padding dynamically to no avail. 100 seems to look good for the various orientations and devices
            .padding(.horizontal,100)
            .padding(.top, 0)
            .padding(.bottom, 4)
            //.background(.ultraThinMaterial)
        }

        // ok - we got notification back from the model that we won
        .onReceive(model.$isWin) { won in
            guard won else { return }
            // Model handles reporting and refreshing personalBest.
            // Just show celebration UI here.
            showConfetti = true
            playWinSound()
            // turn the confetti off after a bit
            Task {
                try await Task.sleep(for: .seconds(2.5))
                showConfetti = false
            }
        }
        // we got a notification that we matched two cards
        .onReceive(model.matchedCardIndices) { indices in
            
            // wiggling indices gets passed to isMatchWiggling via @State trickery
            wigglingIndices.formUnion(indices)
            playMatchHaptic()
            // After the animation duration, remove the indices so they stop wiggling.
            Task {
                // The animation takes about 0.625 seconds. Wait a bit longer.
                try await Task.sleep(for: .seconds(0.65))
                wigglingIndices.subtract(indices)
            }
        }
        
    }

    // Present GKGameCenterViewController for the leaderboard
    // these function and class seem to be the preferred mechanism on newest IOS
    @MainActor
    private func presentLeaderboard() {
        guard let rootVC = currentRootViewController() else {
            print("No root view controller to present Game Center.")
            return
        }
        let gcVC = GKGameCenterViewController(
            leaderboardID: gameCenterManager.leaderboardID, playerScope: .global,
            timeScope: .allTime)
        gcVC.gameCenterDelegate = GameCenterDelegate.shared
        rootVC.present(gcVC, animated: true)
    }
}

// Simple shared delegate to dismiss GKGameCenterViewController
final class GameCenterDelegate: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDelegate()
    func gameCenterViewControllerDidFinish(
        _ gameCenterViewController: GKGameCenterViewController
    ) {
        gameCenterViewController.dismiss(animated: true)
    }
}

#Preview {
    ContentView()
}

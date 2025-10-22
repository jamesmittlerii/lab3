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

import AudioToolbox
import Combine
import GameKit
import SwiftUI

/* this is our structure for the tiled card in the UI */

struct TiledCard: View {

    // our card data structure
    let card: Card

    // whether the card should be wiggling from a match
    let isMatchWiggling: Bool

    // whether the card should be wiggling because of a win
    let isWinWiggling: Bool

    // the closure to call on tap
    let onTap: () -> Void

    // we use this to wiggle the card
    @State private var rotationAngle: Angle = .zero

    var body: some View {
        ZStack {
            // we need this white rectangle so the tile is legible in dark mode
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.white)
            // a border
            RoundedRectangle(cornerRadius: 10)
                .stroke(lineWidth: 3).foregroundColor(.blue)
            // our card image

            Image(card.content)
                .resizable()
                .scaledToFit()
                .padding() // this keeps the image a little smaller than the tile

            // a cover to hide the card
            let cover = RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.blue)

            // we show a blue rectangle to cover the image if the card isn't face up
            cover.opacity(card.isFaceUp ? 0 : 1)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        // this is set by the wiggle effect
        .rotationEffect(rotationAngle)

        // wiggle for a bit if we match
        .onChange(of: isMatchWiggling) { _, shouldWiggle in
            guard shouldWiggle else { return }
            performWiggle(duration: 0.5)
        }
        // wiggle all the tiles on win
        .onChange(of: isWinWiggling) { _, shouldWiggle in
            guard shouldWiggle else { return }
            performWiggle(duration: 2.0)
        }
        // do the card flipping
        // this closure stuff is funky we pass in a reference to the game model to do the work
        .onTapGesture {
            onTap()
        }
    }

    // wiggle the tile on match or win
    // the duration of the wiggle is a variable. short wiggle for match, longer for win
    private func performWiggle(duration: Double) {
        Task {
            let singleWiggleDuration = 0.125  //duration / Double(wiggles)
            let wiggles = Int(duration / singleWiggleDuration)
            let animation = Animation.linear(duration: singleWiggleDuration)
            let pause = UInt64(singleWiggleDuration * 1_000_000_000)
            let wiggleAngle: Double = 4

            // rotate back and forth however many times
            for i in 0..<wiggles {
                let angle = (i % 2 == 0) ? wiggleAngle : -wiggleAngle
                withAnimation(animation) { rotationAngle = .degrees(angle) }
                try await Task.sleep(nanoseconds: pause)
            }

            // reset to zero
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

// Helper to get the current key window’s root view controller in a scene-based app
// this is to support showing the global leaderboard

private func currentRootViewController() -> UIViewController? {
    guard
        let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
    else {
        return nil
    }

    let window =
        scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
    return window?.rootViewController
}

// Game Center login helper
func authenticateGameCenter(completion: ((Error?) -> Void)? = nil) {
    GKLocalPlayer.local.authenticateHandler = { gcAuthVC, error in
        if let vc = gcAuthVC {
            guard let rootVC = currentRootViewController() else {
                print(
                    "Game Center: No rootViewController available to present authentication UI."
                )
                completion?(error)
                return
            }
            rootVC.present(vc, animated: true)
            completion?(error)
            return
        }
        // No UI to present; just forward any error (or nil on success)
        completion?(error)
    }
}

// Simple haptic helpers
private func playMatchHaptic() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}

private func playMismatchHaptic() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.warning)
}

// Win sound helper (System Sound 1322 "Bloom")
private func playWinSound() {
    AudioServicesPlaySystemSound(1322)
}

// our global leaderboard

struct GameCenterView: UIViewControllerRepresentable {
    let leaderboardID: String

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        // Use the supported initializer that targets a specific leaderboard.
        let vc = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        return vc
    }

    func updateUIViewController(
        _ uiViewController: GKGameCenterViewController,
        context: Context
    ) {}
}

// this is the main view for the game
struct ContentView: View {

    // use a variable to determine if we are iphone or ipad
    // unfortunately we need to tweak because the screen ratios and sizes are so different
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Define a fixed number of columns for the grid (4x6)
    let columns = Array(repeating: GridItem(.flexible()), count: 4)

    // our object classes for MVVM
    @StateObject private var gameCenterManager = GameCenterManager()
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
    @State private var isGCAuthenticated = GKLocalPlayer.local.isAuthenticated
    @State private var wigglingIndices = Set<Int>()

    // Header view extracted so we can measure remaining height
    

    // this is our main view -
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("Flips: \(model.flipCount)")
                        .font(
                            horizontalSizeClass == .regular ? .title : .headline
                        )
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
                    .font(horizontalSizeClass == .regular ? .title : .headline)
                    .foregroundColor(.green)

                    // new game icon
                    Button {
                        model.newGame()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                            .accessibilityLabel("New Game")
                            .font(
                                horizontalSizeClass == .regular ? .title : .body
                            )
                    }
                    .help("Start a new game")

                    // global leadboard icon
                    Button {
                        showingLeaderboard = true
                    } label: {
                        Label("Leaderboard", systemImage: "trophy")
                            .labelStyle(.iconOnly)
                            .foregroundColor(
                                isGCAuthenticated ? .orange : .gray
                            )
                            .accessibilityLabel("Show Leaderboard")
                            .font(
                                horizontalSizeClass == .regular ? .title : .body
                            )
                    }
                    .disabled(!isGCAuthenticated)
                    .help("Show global leaderboard")
                }
                .padding()

                GeometryReader { geometry in

                    // use more spacing on ipad
                    // calcuate our item height so we can size the grid
                    // we don't want scrolling

                    let spacing: CGFloat =
                        horizontalSizeClass == .regular ? 24 : 12
                    let numberOfRows: CGFloat = 6  // 24 items in 4 columns
                    let totalVerticalSpacing = spacing * (numberOfRows - 1)
                    let itemHeight =
                        (geometry.size.height - totalVerticalSpacing)
                        / numberOfRows

                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(model.cards.indices, id: \.self) { idx in
                            TiledCard(
                                card: model.cards[idx],
                                isMatchWiggling: wigglingIndices.contains(idx),
                                isWinWiggling: showConfetti
                            ) {
                                model.flip(cardAt: idx)
                            }
                            // keep a nice ratio so the tiles look like tiles
                            .aspectRatio(
                                CGSize(width: 2, height: 3),
                                contentMode: .fit
                            )
                            // set to our computed height
                            .frame(height: max(0, itemHeight))
                        }
                    }
                }
            }
            .padding()
            // cap the width at 600 so the grid doesn't stretch too far out on ipad
            .frame(maxWidth: 600, maxHeight: .infinity)

            // if we won, show some confetti
            if showConfetti {
                ConfettiView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        // overlay to show the global leaderboard
        .sheet(isPresented: $showingLeaderboard) {
            GameCenterView(leaderboardID: gameCenterManager.leaderboardID)
        }
        // the confetti we throw up when we win
        .animation(.default, value: showConfetti)

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
            wigglingIndices.formUnion(indices)
            playMatchHaptic()
            // After the animation duration, remove the indices so they stop wiggling.
            Task {
                // The animation takes about 0.625 seconds. Wait a bit longer.
                try await Task.sleep(for: .seconds(0.65))
                wigglingIndices.subtract(indices)
            }
        }

        .onAppear {
            // login to game center to fetch high score
            authenticateGameCenter { error in
                if let error = error {
                    print(
                        "Game Center authentication error: \(error.localizedDescription)"
                    )
                    self.isGCAuthenticated = GKLocalPlayer.local.isAuthenticated
                } else {
                    self.isGCAuthenticated = GKLocalPlayer.local.isAuthenticated
                    // After successful auth, ask the model to refresh personal best.
                    if self.isGCAuthenticated {
                        model.loadHighScoreFromGameCenter()
                    }
                }
                print(
                    "GC isAuthenticated:",
                    GKLocalPlayer.local.isAuthenticated
                )
            }
        }
    }
}

#Preview {
    ContentView()
}

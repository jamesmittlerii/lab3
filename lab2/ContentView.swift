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

 _Italic text_
 __Bold text__
 ~~Strikethrough text~~

 */

import AudioToolbox
import GameKit
import SwiftUI
import Combine

// this class manages the game center authentication

class GameCenterManager: ObservableObject {
    // A published property to reflect the authentication status.
    @Published var isAuthenticated = false
    
    // A state to hold the view controller presented by GameKit, if needed.
    @Published var authenticationVC: UIViewController? = nil
    
    // Call this method to begin the authentication process.
    func authenticateUser() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if GKLocalPlayer.local.isAuthenticated {
                self?.isAuthenticated = true
                self?.authenticationVC = nil
            } else if let vc = viewController {
                self?.authenticationVC = vc
                self?.isAuthenticated = false
            } else {
                self?.isAuthenticated = false
                print("Error authenticating to Game Center: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

/* this is our structure for the tiled card in the UI */

struct TiledCard: View {

    // our card data structure
    let card: Card

    // the closure to call on tap
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.white)
            RoundedRectangle(cornerRadius: 10)
                .stroke(lineWidth: 3).foregroundColor(.blue)
            Image(card.content).resizable().scaledToFit().padding()
            let cover = RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.blue)
            
            // we show a blue rectangle to cover the image if the card isn't face up
            cover.opacity(card.isFaceUp ? 0 : 1)
        }
        .padding(.horizontal)
        
        // do the card flipping
        // this closure stuff is funky we pass in a reference to the game model to do the work
        .onTapGesture {
            onTap()
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

    let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
    return window?.rootViewController
}

// Game Center login helper
func authenticateGameCenter(completion: ((Error?) -> Void)? = nil) {
    GKLocalPlayer.local.authenticateHandler = { gcAuthVC, error in
        if let vc = gcAuthVC {
            guard let rootVC = currentRootViewController() else {
                print("Game Center: No rootViewController available to present authentication UI.")
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

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}
}

// this is the main view for the game
struct ContentView: View {

    @Environment(\.horizontalSizeClass) private var hSizeClass

    // our object classes
    
    @StateObject private var model = GameModel()
    @StateObject private var gameCenterManager = GameCenterManager()

    // anything with @state will refresh the UI on change
    @State private var showConfetti = false
    @State private var gameCenterError: String?
    @State private var showingLeaderboard = false
    @State private var isGCAuthenticated = GKLocalPlayer.local.isAuthenticated

    // are we running on Ipad?
    private var isPadLayout: Bool {
        // Prefer size class, fallback to idiom
        if let hSizeClass, hSizeClass == .regular { return true }
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    // Header view extracted so we can measure remaining height
    @ViewBuilder
    private func headerView() -> some View {
        HStack(spacing: 8) {
            Text("Flips: \(model.flipCount)")
                .font(.headline)
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
            .font(.headline)
            .foregroundColor(.green)

            // new game icon
            Button {
                model.newGame()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                    .accessibilityLabel("New Game")
            }
            .help("Start a new game")

            // global leadboard icon
            Button {
                if isGCAuthenticated {
                    showingLeaderboard = true
                } else {
                    gameCenterError =
                        "Please sign in to Game Center to view the leaderboard."
                }
            } label: {
                Label("Leaderboard", systemImage: "trophy")
                    .labelStyle(.iconOnly)
                    .foregroundColor(
                        isGCAuthenticated ? .orange : .gray
                    )
                    .accessibilityLabel("Show Leaderboard")
            }
            .disabled(!isGCAuthenticated)
            .help("Show global leaderboard")
        }
        .padding(.top, 12)
    }

    // this is our main view -
    var body: some View {
        GeometryReader { geo in
            
            // our grid sizes
            let rows: CGFloat = 6
            let cols: CGFloat = 4
            let numHSpaces = cols - 1 // 3
            let numVSpaces = rows - 1 // 5

            
            let isCompact = (hSizeClass == .compact)
            
            // here we try to get the best sizing for 4x6
            // tough because ipad/iphone are different ratios and sizes

            // Tighter margins/gaps on compact devices
            let horizontalPadding: CGFloat = isCompact ? 0 : 12
            let interItemSpacing: CGFloat = isCompact ? 0 : 12

            // Smaller header estimate on compact devices
            let estimatedHeaderHeight: CGFloat = isCompact ? 36 : 56 // 44 + 12 = 56

            // --- Available Area Calculation ---

            let availableWidth = geo.size.width - 2 * horizontalPadding
            let availableHeight = geo.size.height - estimatedHeaderHeight - 16 // Bottom safety margin

            // --- Tile Size Calculation ---

            // Calculate the maximum possible square tile size limited by the width
            let widthLimitedTile = (availableWidth - interItemSpacing * numHSpaces) / cols

            // Calculate the maximum possible square tile size limited by the height
            let heightLimitedTile = (availableHeight - interItemSpacing * numVSpaces) / rows

            // Choose the smaller size to ensure the grid fits
            let tileSize = max(0, min(widthLimitedTile, heightLimitedTile))

            // --- Spacing and Grid Finalization ---

            let widthIsLimiter = widthLimitedTile <= heightLimitedTile + .ulpOfOne
            let columnSpacing = interItemSpacing

            // Calculate leftover vertical space and distribute it evenly among row gaps
            let tilesTotalHeight = tileSize * rows
            let leftoverHeight = max(0, availableHeight - tilesTotalHeight)
            let extraPerGap = (widthIsLimiter && rows > 1) ? leftoverHeight / numVSpaces : 0

            let rowSpacing = interItemSpacing + extraPerGap

            let columns: [GridItem] = Array(
                repeating: GridItem(.fixed(tileSize), spacing: columnSpacing),
                count: Int(cols)
            )

            // The final calculated grid height (useful for aligning/positioning the grid)
            let gridHeight = max(0, tilesTotalHeight + rowSpacing * numVSpaces)

            ZStack {
                VStack(spacing: 8) {
                    headerView()

                    // Grid with tighter spacing and reduced side padding on iPhone
                    LazyVGrid(columns: columns, spacing: rowSpacing) {
                        // loop through all the cards and build a tiledcard view
                        // we need to pass the flip function as a closure
                        ForEach(model.cards.indices, id: \.self) { idx in
                            TiledCard(card: model.cards[idx]) {
                                model.flip(cardAt: idx)
                            }
                            .frame(width: tileSize, height: tileSize)
                        }
                    }
                    .frame(width: max(0, availableWidth), height: gridHeight)
                    .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: 0)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )

                // if we won, show some confetti
                if showConfetti {
                    ConfettiView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                        .zIndex(1)
                }

                // show any error we got from gamecenter
                if let gameCenterError = gameCenterError {
                    VStack {
                        Spacer()
                        Text("Game Center: \(gameCenterError)")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
            }
        }
        // overlay to show the global leaderboard
        .sheet(isPresented: $showingLeaderboard) {
            GameCenterView(leaderboardID: model.leaderboardID)
        }
        .animation(.default, value: showConfetti)
        // ok - we got notification back from the model that we won
        .onReceive(model.$isWin) { won in
            guard won else { return }
            // Model handles reporting and refreshing personalBest.
            // Just show celebration UI here.
            showConfetti = true
            playWinSound()
            // turn the confetti off after a bit
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                showConfetti = false
            }
        }
        .onAppear {
            // login to game center to fetch high score
            authenticateGameCenter { error in
                if let error = error {
                    self.gameCenterError = error.localizedDescription
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

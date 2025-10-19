//
//  ContentView.swift
//  lab2
//
//  Created by cisstudent on 10/7/25.
//

import AudioToolbox
import GameKit
import SwiftUI

struct TileCards: View {
    let card: Card
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
            cover.opacity(card.isFaceUp ? 0 : 1)
        }
        .padding(.horizontal)
        .onTapGesture {
            if !card.solved && !card.isFaceUp {
                onTap()
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var size: Double
    var opacity: Double
    var duration: Double
}

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
private func currentRootViewController() -> UIViewController? {
    // Find the active foreground scene
    let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }

    // Prefer key window; otherwise first window
    for scene in scenes {
        if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }),
           let root = keyWindow.rootViewController
        {
            return root
        }
        if let anyWindow = scene.windows.first,
           let root = anyWindow.rootViewController
        {
            return root
        }
    }
    return nil
}

// Game Center login helper
func authenticateGameCenter(completion: ((Error?) -> Void)? = nil) {
    GKLocalPlayer.local.authenticateHandler = { gcAuthVC, error in
        if let vc = gcAuthVC {
            // Present from the active scene’s rootViewController (iOS 15+ friendly)
            if let rootVC = currentRootViewController() {
                rootVC.present(vc, animated: true)
            } else {
                // As a fallback, try to find a top-most controller to present from
                if let windowScene = UIApplication.shared.connectedScenes.first
                    as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let root = window.rootViewController
                {
                    root.present(vc, animated: true)
                } else {
                    // Could not find a presentation anchor
                    print(
                        "Game Center: Unable to find a rootViewController to present authentication UI."
                    )
                }
            }
        }
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

// SwiftUI wrapper for GKGameCenterViewController
struct GameCenterView: UIViewControllerRepresentable {
    let leaderboardID: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        vc.gameCenterDelegate = context.coordinator
        // vc.viewState is deprecated since iOS 14; the initializer above already targets leaderboards.
        return vc
    }

    func updateUIViewController(
        _ uiViewController: GKGameCenterViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func gameCenterViewControllerDidFinish(
            _ gameCenterViewController: GKGameCenterViewController
        ) {
            dismiss()
        }
    }
}

struct ContentView: View {
  
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @StateObject private var model = GameModel()

    @State private var showConfetti = false
    @State private var confettiID = UUID()
    @State private var gameCenterError: String?
    @State private var showingLeaderboard = false
    @State private var isGCAuthenticated = GKLocalPlayer.local.isAuthenticated

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

            Button {
                model.newGame()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                    .accessibilityLabel("New Game")
            }
            .help("Start a new game")

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

    var body: some View {
        GeometryReader { geo in
            // Common layout spacing values used below
            let baseHorizontalPadding: CGFloat = 16
            let baseInterItemSpacing: CGFloat = 12
            let rows = 6
            let cols = 4

            // Compact-width (iPhone) tweaks: tighten margins/gaps to maximize tile size
            let isCompact = (hSizeClass == .compact)
            let horizontalPadding: CGFloat = isCompact ? 4 : baseHorizontalPadding
            let tightSpacing: CGFloat = isCompact ? 1 : baseInterItemSpacing

            // Estimate header height; use a smaller estimate on iPhone to give tiles more room
            let estimatedHeaderHeight: CGFloat = isCompact ? 36 : (44 + 12)

            // Available grid area
            let availableWidth = max(0, geo.size.width - horizontalPadding * 2)
            let availableHeight = max(0, geo.size.height - estimatedHeaderHeight - 16) // slightly smaller bottom safety on iPhone

            // Compute both width-limited and height-limited square tile sizes
            let widthLimitedTile =
                (availableWidth - tightSpacing * CGFloat(cols - 1)) / CGFloat(cols)
            let heightLimitedTile =
                (availableHeight - tightSpacing * CGFloat(rows - 1)) / CGFloat(rows)

            // Choose the smaller so the grid always fits
            let tileSize = max(0, min(widthLimitedTile, heightLimitedTile))

            // Determine if width or height is the limiting factor
            let widthIsLimiter = widthLimitedTile <= heightLimitedTile + .ulpOfOne

            // Use tight spacing on iPhone; keep base spacing on iPad-like widths
            let columnSpacing = tightSpacing
            // Optionally, add any remaining vertical space (when width is the limiter) into row spacing
            let tilesTotalHeight = tileSize * CGFloat(rows)
            let leftoverHeight = max(0, availableHeight - tilesTotalHeight)
            let extraPerGap = (widthIsLimiter && rows > 1) ? leftoverHeight / CGFloat(rows - 1) : 0
            let rowSpacing = tightSpacing + extraPerGap

            // Grid definition: 4 fixed columns with (possibly) tighter horizontal spacing
            let columns: [GridItem] = Array(
                repeating: GridItem(.fixed(tileSize), spacing: columnSpacing),
                count: cols
            )

            // Total grid height: tiles + (rows - 1) gaps using the computed row spacing
            let gridHeight = max(0, tilesTotalHeight + rowSpacing * CGFloat(rows - 1))

            ZStack {
                VStack(spacing: 8) {
                    headerView()

                    // Grid with tighter spacing and reduced side padding on iPhone
                    LazyVGrid(columns: columns, spacing: rowSpacing) {
                        ForEach(model.cards.indices, id: \.self) { idx in
                            TileCards(card: model.cards[idx]) {
                                model.flip(cardAt: idx)
                            }
                            .frame(width: tileSize, height: tileSize)
                        }
                    }
                    .frame(width: max(0, availableWidth), height: gridHeight)
                    .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if showConfetti {
                    ConfettiView()
                        .id(confettiID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                        .zIndex(1)
                }

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
        .sheet(isPresented: $showingLeaderboard) {
            GameCenterView(leaderboardID: model.leaderboardID)
        }
        .animation(.default, value: showConfetti)
        .onReceive(model.$isWin) { won in
            guard won else { return }
            // Model handles reporting and refreshing personalBest.
            // Just show celebration UI here.
            confettiID = UUID()
            showConfetti = true
            playWinSound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                showConfetti = false
            }
        }
        .onAppear {
            authenticateGameCenter { error in
                if let error = error {
                    self.gameCenterError = error.localizedDescription
                    self.isGCAuthenticated = GKLocalPlayer.local.isAuthenticated
                } else {
                    self.isGCAuthenticated = GKLocalPlayer.local.isAuthenticated
                    // After successful auth, ask the model to refresh personal best.
                    if self.isGCAuthenticated {
                        model.loadHighScoreFromGameCenter(
                            
                        )
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


//
//  ContentView.swift
//  lab2
//
//  Created by cisstudent on 10/7/25.
//

import SwiftUI
import GameKit

let allImages = ["Man1","Man2","Man3","Man4","Man5","Man6","Man7","Man8","Man9","Sou1","Sou2","Sou3","Sou4","Sou5","Sou6","Sou7","Sou8","Sou9"]

struct Card: Identifiable {
    let id = UUID()
    let content: String
    var isFaceUp: Bool = false
    var solved: Bool = false
}

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
    let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(confetti) { particle in
                    Circle()
                        .fill(colors.randomElement() ?? .blue)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                        .animation(.easeOut(duration: particle.duration), value: particle.y)
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
           let root = keyWindow.rootViewController {
            return root
        }
        if let anyWindow = scene.windows.first,
           let root = anyWindow.rootViewController {
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
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let root = window.rootViewController {
                    root.present(vc, animated: true)
                } else {
                    // Could not find a presentation anchor
                    print("Game Center: Unable to find a rootViewController to present authentication UI.")
                }
            }
        }
        completion?(error)
    }
}

// Report score to Game Center (modern iOS 14+ API, no fallback)
func reportScore(_ score: Int, toLeaderboard leaderboardID: String) {
    GKLeaderboard.submitScore(
        score,
        context: 0,
        player: GKLocalPlayer.local,
        leaderboardIDs: [leaderboardID]
    ) { error in
        if let error = error {
            print("Error reporting score: \(error.localizedDescription)")
        } else {
            print("Score reported successfully!")
        }
    }
}

// Load the lowest score globally from Game Center (ascending leaderboard)
func loadHighScoreFromGameCenter(leaderboardID: String, completion: @escaping (Int?) -> Void) {
    GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { leaderboards, error in
        if let error = error {
            print("Error loading leaderboard: \(error.localizedDescription)")
            completion(nil)
            return
        }
        guard let leaderboard = leaderboards?.first else {
            print("Leaderboard not found for ID: \(leaderboardID)")
            completion(nil)
            return
        }

        // Since the leaderboard is configured as "lower is better",
        // the top global entry (range 1..1) is the lowest score.
        leaderboard.loadEntries(
            for: .global,
            timeScope: .allTime,
            range: NSRange(location: 1, length: 1)
        ) { _, entries, _, error in
            if let error = error {
                print("Error loading entries: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let first = entries?.first else {
                completion(nil)
                return
            }
            completion(Int(first.score))
        }
    }
}

struct ContentView: View {
    private static let leaderboardID = "KingOfTheHill" // <-- Set your real leaderboard ID here

    @State private var cards: [Card] = ContentView.generateCards()
    @State private var indicesOfFaceUp: [Int] = []
    @State private var showConfetti = false
    @State private var confettiID = UUID()
    @State private var flipCount = 0
    @State private var gameCenterError: String?
    @State private var gameCenterBest: Int? // Only track GC best in-memory for display

    static func generateCards() -> [Card] {
        let chosen = allImages.shuffled().prefix(12)
        let pairs = Array(chosen) + Array(chosen)
        return pairs.shuffled().map { Card(content: $0) }
    }

    func handleTap(on index: Int) {
        guard !cards[index].isFaceUp, !cards[index].solved, indicesOfFaceUp.count < 2 else { return }

        // Increment flip count for a valid flip
        flipCount += 1

        var newCards = cards
        newCards[index].isFaceUp = true
        cards = newCards
        indicesOfFaceUp.append(index)

        if indicesOfFaceUp.count == 2 {
            let firstIdx = indicesOfFaceUp[0]
            let secondIdx = indicesOfFaceUp[1]
            if cards[firstIdx].content == cards[secondIdx].content {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    var newCards = cards
                    newCards[firstIdx].solved = true
                    newCards[secondIdx].solved = true
                    cards = newCards
                    indicesOfFaceUp = []
                    checkForWin()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    var newCards = cards
                    newCards[firstIdx].isFaceUp = false
                    newCards[secondIdx].isFaceUp = false
                    cards = newCards
                    indicesOfFaceUp = []
                }
            }
        }
    }

    func checkForWin() {
        if cards.allSatisfy({ $0.solved }) {
            // Fetch global lowest GC score, then decide to submit
            loadHighScoreFromGameCenter(leaderboardID: Self.leaderboardID) { globalLowest in
                let newScore = flipCount
                let shouldSubmit: Bool
                if let globalLowest = globalLowest {
                    // Lower flips is better
                    shouldSubmit = newScore < globalLowest
                } else {
                    // No GC score yet, submit ours
                    shouldSubmit = true
                }

                if shouldSubmit {
                    reportScore(newScore, toLeaderboard: Self.leaderboardID)
                }

                // Update the in-memory display of GC best (lowest globally including ours if better)
                DispatchQueue.main.async {
                    if let globalLowest = globalLowest {
                        gameCenterBest = min(globalLowest, newScore)
                    } else {
                        gameCenterBest = newScore
                    }

                    // Confetti feedback
                    confettiID = UUID()
                    showConfetti = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showConfetti = false
                    }
                }
            }
        }
    }

    func resetGame() {
        cards = ContentView.generateCards()
        indicesOfFaceUp = []
        showConfetti = false
        flipCount = 0
    }

    func refreshHighScoreFromGameCenter() {
        loadHighScoreFromGameCenter(leaderboardID: Self.leaderboardID) { score in
            DispatchQueue.main.async {
                gameCenterBest = score
            }
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Flips: \(flipCount)")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text({
                            if let best = gameCenterBest {
                                return "High Score: \(best)"
                            } else {
                                return "High Score: --"
                            }
                        }())
                        .font(.headline)
                        .foregroundColor(.green)
                        Button(action: {
                            refreshHighScoreFromGameCenter()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.gray)
                        }
                        .help("Refresh high score from Game Center")
                    }
                    .padding(.top, 12)

                    // Always 4 columns; increase vertical spacing between rows
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 4)

                    LazyVGrid(columns: columns, spacing: 12) { // row spacing = 12
                        ForEach(cards.indices, id: \.self) { idx in
                            TileCards(card: cards[idx]) {
                                handleTap(on: idx)
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .padding(.vertical, 4) // optional extra separation
                        }
                    }

                    Button("New Game") {
                        resetGame()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            if showConfetti {
                ConfettiView()
                    .id(confettiID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .zIndex(1)
            }
            // Optional: Show Game Center error alert
            if let gameCenterError = gameCenterError {
                VStack {
                    Spacer()
                    Text("Game Center Error: \(gameCenterError)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .animation(.default, value: showConfetti)
        .onAppear {
            authenticateGameCenter { error in
                if let error = error {
                    self.gameCenterError = error.localizedDescription
                } else {
                    refreshHighScoreFromGameCenter()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

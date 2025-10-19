//
//  GameModel.swift
//  lab2
//
//  Created by cisstudent on 10/7/25.
//

import Combine
import Foundation
import GameKit

let allImages: [String] = {
    let suits = ["Man", "Sou", "Pin"]
    return suits.flatMap { suit in
        (1...9).map { "\(suit)\($0)" }
    }
}()

struct Card: Identifiable, Equatable {
    let id = UUID()
    let content: String
    var isFaceUp: Bool = false
    var solved: Bool = false
}

final class GameModel: ObservableObject {
    @Published private(set) var cards: [Card] = []
    @Published private(set) var flipCount: Int = 0
    @Published var isWin: Bool = false
    @Published private(set) var personalBest: Int?

    private var indicesOfFaceUp: [Int] = []
    let leaderboardID = "KingOfTheHill"
    init() {
        newGame()
    }

    func newGame() {
        let chosen = allImages.shuffled().prefix(12)
        let pairs = Array(chosen) + Array(chosen)
        cards = pairs.shuffled().map { Card(content: $0) }
        indicesOfFaceUp = []
        flipCount = 0
        isWin = false

        // Optionally refresh the stored personal best at the start of a game.
        // Safe to call even if not authenticated; it will complete with nil.
        loadHighScoreFromGameCenter()
    }

    func flip(cardAt index: Int) {
        guard cards.indices.contains(index) else { return }
        guard !cards[index].isFaceUp, !cards[index].solved,
            indicesOfFaceUp.count < 2
        else { return }

        flipCount += 1

        cards[index].isFaceUp = true
        indicesOfFaceUp.append(index)

        if indicesOfFaceUp.count == 2 {
            let firstIdx = indicesOfFaceUp[0]
            let secondIdx = indicesOfFaceUp[1]

            if cards[firstIdx].content == cards[secondIdx].content {
                self.cards[firstIdx].solved = true
                self.cards[secondIdx].solved = true
                self.indicesOfFaceUp = []
                self.checkForWin()

            } else {
                // Mismatch: flip back after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    [weak self] in
                    guard let self = self else { return }
                    self.cards[firstIdx].isFaceUp = false
                    self.cards[secondIdx].isFaceUp = false
                    self.indicesOfFaceUp = []
                }
            }
        }
    }

    func updatePersonalBest(_ flipCount: Int?) {

        guard let newCount = flipCount else {
            return
        }

        personalBest = min(personalBest ?? newCount, newCount)
        print("updating personal best to : \(personalBest!)")
    }

    private func checkForWin() {
        if cards.allSatisfy({ $0.solved }) {
            isWin = true
            updatePersonalBest(flipCount)
            // Submit the score (using flipCount) to Game Center when the player wins.
            if GKLocalPlayer.local.isAuthenticated {
                reportScore(flipCount)

            }
        }
    }

    // Report score to Game Center (modern iOS 14+ API, no fallback)
    func reportScore(_ score: Int) {
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

    // Load the current player's personal best (lowest) score from Game Center
    func loadHighScoreFromGameCenter() {
        // Ensure the local player is authenticated
        guard GKLocalPlayer.local.isAuthenticated else {
            return
        }

        GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) {
            leaderboards,
            error in
            if let error = error {
                print(
                    "Error loading leaderboard: \(error.localizedDescription)"
                )
                return
            }
            guard let leaderboard = leaderboards?.first else {
                print("Leaderboard not found for ID: \(self.leaderboardID)")
                return
            }

            leaderboard.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: NSRange(location: 1, length: 1)
            ) { localPlayerEntry, _, _, error in
                if let error = error {
                    print(
                        "Error loading local player entry: \(error.localizedDescription)"
                    )
                    return
                }
                guard let local = localPlayerEntry, local.score > 0 else {
                    // No score submitted yet by this player
                    return
                }

                self.updatePersonalBest(Int(local.score))
            }
        }
    }
}

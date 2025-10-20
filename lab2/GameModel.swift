//
//  GameModel.swift
//  lab2
//
//  Created by cisstudent on 10/7/25.
//

import Combine
import Foundation
import GameKit

// here are all the possible images
let allImages: [String] = {
    let suits = ["Man", "Sou", "Pin"]
    return suits.flatMap { suit in
        (1...9).map { "\(suit)\($0)" }
    }
}()

// a structure to represent a card
struct Card: Identifiable, Equatable {
    let id = UUID()
    let content: String
    var isFaceUp: Bool = false
    var solved: Bool = false
}

// this is our game model

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
        // grab 12 unique tiles
        let chosen = allImages.shuffled().prefix(12)
        // double that to 24...2 of each
        let pairs = Array(chosen) + Array(chosen)
        // create an array of (shuffled) cards
        cards = pairs.shuffled().map { Card(content: $0) }
        
        // nothing turned up to start
        indicesOfFaceUp = []
        
        // reset the flip count and win indicator
        flipCount = 0
        isWin = false

        // grab the high score
        loadHighScoreFromGameCenter()
    }

    // here we flip the cards
    // we are passing the index around instead of the actual card. I'm not sure which is better
    
    func flip(cardAt index: Int) {
        
        // sanity check
        guard cards.indices.contains(index) else { return }
        
        // if the card is already face up or the card is solved and we haven't got two cards flipped up, then we are ok
        guard !cards[index].isFaceUp, !cards[index].solved,
            indicesOfFaceUp.count < 2
        else { return }

        // increment our score
        flipCount += 1

        // mark this card face up
        cards[index].isFaceUp = true
        
        // keep track of cards that are face up
        indicesOfFaceUp.append(index)

        // if we've got two face up then determine if we've matched two cards
        if indicesOfFaceUp.count == 2 {
            let firstIdx = indicesOfFaceUp[0]
            let secondIdx = indicesOfFaceUp[1]

            // matched! track that and check for win
            if cards[firstIdx].content == cards[secondIdx].content {
                self.cards[firstIdx].solved = true
                self.cards[secondIdx].solved = true
                self.indicesOfFaceUp = []
                self.checkForWin()

            } else {
                // Mismatch: flip back after a short delay
                // this weak self stuff is weird but necessary
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

    // update our personal best
    func updatePersonalBest(_ flipCount: Int?) {

        // null check
        guard let newCount = flipCount else {
            return
        }

        // if we beat our best score - update our personal best
        if personalBest == nil || newCount < personalBest! {
                personalBest = newCount
            }
        
        print("updating personal best to : \(personalBest!)")
    }

    // check for a win
    private func checkForWin() {
        // if every card is solved...we win
        
        if cards.allSatisfy({ $0.solved }) {
            
            // update our flag
            isWin = true
            
            // update our personal best if needed
            
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

            // grab  my personal scores
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

                // update personal best with what we got from game center
                self.updatePersonalBest(Int(local.score))
            }
        }
    }
}

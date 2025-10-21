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
    // unique id
    let id = UUID()
    // the image
    let content: String
    // are we face up?
    var isFaceUp: Bool = false
    // did we solve...i.e. match the other card
    var solved: Bool = false
}

// this is our game model
@MainActor
final class GameModel: ObservableObject {
    
    // anything published provides notification to the UI
    @Published private(set) var cards: [Card] = []
    @Published private(set) var flipCount: Int = 0
    @Published var isWin: Bool = false
    @Published private(set) var personalBest: Int?

    
    // A subject to publish the indices of matched cards.
    // we do a little wiggle and play a haptic
    
    let matchedCardIndices = PassthroughSubject<[Int], Never>()

    // keep track of which cards are flipped up
    private var indicesOfFaceUp: [Int] = []
    
    // Reference to the Game Center manager for reporting/loading scores
    private weak var gameCenterManager: GameCenterManager?

    // need when we've got multiple classes depending on each other
    init(gameCenterManager: GameCenterManager?) {
        self.gameCenterManager = gameCenterManager
        newGame()
    }

    // lets start a new game
    
    func newGame() {
        // grab 12 unique tiles by shuffling our set and picking the first 12
        let chosen = allImages.shuffled().prefix(12)
        // double that to 24...2 of each
        let pairs = Array(chosen) + Array(chosen)
        // create an array of (shuffled again) cards
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
                // send these out so we can do the wiggle
                matchedCardIndices.send([firstIdx, secondIdx])

            } else {
                // Mismatch: flip back after a short delay
                // I don't understand the weak self stuff but seems to been required
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(0.9))
                    guard let self else { return }
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
                Task {
                    await gameCenterManager?.submitScore(flipCount)
                }
            }
        }
    }

    // Load the current player's personal best (lowest) score from Game Center
    func loadHighScoreFromGameCenter() {
        Task {
            guard let manager = gameCenterManager else { return }
            if let best = await manager.loadPersonalBest() {
                self.updatePersonalBest(best)
            }
        }
    }
}

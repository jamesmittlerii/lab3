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
 
 This class contains the GameModel logic
 
 It's all pretty straightforward but the interaction with GameCenter is a little tricky ...see the code
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

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
// we use main actor to prevent race conditions
@MainActor
final class GameModel: ObservableObject {

    // anything published provides notification to the UI
    @Published private(set) var cards: [Card] = []      // our cards
    @Published private(set) var flipCount: Int = 0      // our score
    @Published var isWin: Bool = false                  // did we win i.e. match all the cards?
    @Published private(set) var personalBest: Int?      // what is our personal best score?

    // A subject to publish the indices of matched cards.
    // we do a little wiggle in the UI and play a haptic

    let matchedCardIndices = PassthroughSubject<[Int], Never>()

    // keep track of which cards are flipped up
    private var indicesOfFaceUp: [Int] = []

    // Reference to the Game Center manager for reporting/loading scores
    private weak var gameCenterManager: GameCenterManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Progress metrics exposed to the UI

    var totalCards: Int {
        cards.count
    }

    var solvedCards: Int {
        cards.filter { $0.solved }.count
    }

    var totalPairs: Int {
        totalCards / 2
    }

    var pairsSolved: Int {
        solvedCards / 2
    }

    var progress: Double {
        guard totalCards > 0 else { return 0.0 }
        return Double(solvedCards) / Double(totalCards)
    }

    // need when we've got multiple classes depending on each other
    init(gameCenterManager: GameCenterManager?) {
        self.gameCenterManager = gameCenterManager

        // Observe authentication changes from the GameCenterManager - it's async so messy
        // we are waiting for notification from game center manager that we've authenticated...then we can udate our personal best
        // the cancellables stuff ensure our references are safe from deallocation until we release this class
        // probably overkill but seems to be the recommended approach
        
        gameCenterManager?.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.loadHighScoreFromGameCenter()
                }
            }
            .store(in: &cancellables)

        // start a new game when the class initializes
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

    // here we flip a card
    // we are passing the index around instead of the actual card. I'm not sure which is better but this works

    func flip(cardAt index: Int) {

        // sanity check
        // this guard idiom is nice btw
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

            // if we've matched, mark those cards as solved and check for win
            if cards[firstIdx].content == cards[secondIdx].content {
                self.cards[firstIdx].solved = true
                self.cards[secondIdx].solved = true
                self.indicesOfFaceUp = []
                self.checkForWin()
                // send these out to the UI so we can do the wiggle
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
            // game center doesn't care if we don't send personal best - it will figure it out
            
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
            // are we authenticated?
            guard let manager = gameCenterManager, manager.isAuthenticated
            else { return }
            
            // wait for game manager to tell us our best score
            if let best = await manager.loadPersonalBest() {
                self.updatePersonalBest(best)
            }
        }
    }
}


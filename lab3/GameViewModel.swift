/**
 
 * __Partner Lab 3__
 * Jim Mittler
 * 20 October 2025
 
 
 We've updated our Game to use MVVM architecture
 
 all the game logic is moved to the GameModel class
 
 ContentView contains the UI logic and the code to support showing the global leaderboard
 
 GameViewModel is the View Model code that coordinates between the view and model.
 
 The game connects to Game Center to keep track of personal best and show a global leaderboard of all the players
 
 We show a 4x6 grid of randomly shuffled tile pairs.
 If you match two tiles they remain face up until you complete the game.
 We show some confetti when you win.
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import Foundation
import Combine
import GameKit

@MainActor
final class GameViewModel: ObservableObject {

    // Services
    private let gameCenterManager: GameCenterManager
    private let model: GameModel

    // View-facing state
    @Published private(set) var cards: [Card] = []
    @Published private(set) var flipCount: Int = 0
    @Published private(set) var personalBest: Int?
    @Published private(set) var progress: Double = 0
    @Published private(set) var isAuthenticated: Bool = false

    // UI-only state
    @Published var showConfetti = false
    @Published var wigglingIndices = Set<Int>()
    @Published var isShowingLeaderboard = false

    // Presentation overlay: indices temporarily shown face-up after mismatch
    @Published private var transientFaceUp = Set<Int>()
    // Disable tap interaction during mismatch presentation
    @Published private(set) var isInteractionDisabled = false

    private var cancellables = Set<AnyCancellable>()

    init(gameCenterManager: GameCenterManager) {
        self.gameCenterManager = gameCenterManager
        self.model = GameModel(gameCenterManager: gameCenterManager)

        // Bridge model outputs to view-facing state
        model.$cards.assign(to: &$cards)
        model.$flipCount.assign(to: &$flipCount)
        model.$personalBest.assign(to: &$personalBest)

        // Derived progress
        model.objectWillChange
            .map { [weak model] _ in model?.progress ?? 0.0 }
            .assign(to: &$progress)

        // Auth state for enabling the leaderboard button
        gameCenterManager.$isAuthenticated
            .assign(to: &$isAuthenticated)

        // Confetti and sound on win
        model.$isWin
            .removeDuplicates()
            .sink { [weak self] won in
                guard let self else { return }
                if won {
                    self.showConfetti = true
                    playWinSound()
                    Task { [weak self] in
                        try? await Task.sleep(for: .seconds(2.5))
                        self?.showConfetti = false
                    }
                }
            }
            .store(in: &cancellables)

        // Wiggle and haptic on match
        model.matchedCardIndices
            .sink { [weak self] indices in
                guard let self else { return }
                self.wigglingIndices.formUnion(indices)
                //playMatchHaptic()
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(0.65))
                    self?.wigglingIndices.subtract(indices)
                }
            }
            .store(in: &cancellables)

        // Mismatch presentation: temporarily show mismatched cards face-up for the UI
        // this is a little janky but we keep the source of truth in the model that the cards didn't match so we turned them over
        // we want the UI to keep them turned up for a little bit longer then flip them over
        model.mismatchedCardIndices
            .sink { [weak self] indices in
                guard let self else { return }
                // lock the UI until we get the cards turned back over
                self.isInteractionDisabled = true
                self.transientFaceUp.formUnion(indices)
                playMismatchHaptic()
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1.5))
                    guard let self else { return }
                    self.transientFaceUp.subtract(indices)
                    self.isInteractionDisabled = false
                    playFlipSound()
                }
            }
            .store(in: &cancellables)
    }

    // do the needful when we start a new game
    func newGame() {
        model.newGame()
        // Clear any transient UI state
        transientFaceUp.removeAll()
        isInteractionDisabled = false
        wigglingIndices.removeAll()
        showConfetti = false
    }
    
    /* turn over a card */

    func flip(cardAt index: Int) {
        guard !isInteractionDisabled else { return }

        // Let the model validate the flip preconditions (not already up, not solved, <2 up, etc.)
        // We’ll play the flip sound only when we actually proceed with a valid flip.
        // Do a quick local check to mirror the model’s early guards and avoid
        // playing sound on ignored taps.
        guard cards.indices.contains(index),
              !cards[index].isFaceUp,
              !cards[index].solved
        else { return }

        // Play a short “slap/tock” sound for a valid user flip
        playFlipSound()

        model.flip(cardAt: index)
    }

    func showLeaderboard() {
        isShowingLeaderboard = true
    }

    // Expose leaderboard ID for the wrapper view
    var leaderboardID: String { gameCenterManager.leaderboardID }

    /* this function is moderately interesting. If we flip up two unmatched cards, we turn the back down in the game model right away
     but we want to leave them up in the UI for a short time so the player can memorize them.
     
     We keep an extra "transient faceup" data structure containing those two cards and the UI does a union between the card status and our little data structure
     */
   
    func isPresentingFaceUp(_ index: Int) -> Bool {
        // UI should show face-up if the model says so (solved or currently up),
        // or if we’re temporarily presenting due to a mismatch.
        guard cards.indices.contains(index) else { return false }
        return cards[index].isFaceUp || transientFaceUp.contains(index)
    }
}

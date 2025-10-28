//
//  GameViewModel.swift
//  lab2
//
//  Created by cisstudent on 10/27/25.
//

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
                }
            }
            .store(in: &cancellables)
    }

    func newGame() {
        model.newGame()
        // Clear any transient UI state
        transientFaceUp.removeAll()
        isInteractionDisabled = false
        wigglingIndices.removeAll()
        showConfetti = false
    }

    func flip(cardAt index: Int) {
        guard !isInteractionDisabled else { return }
        model.flip(cardAt: index)
    }

    func showLeaderboard() {
        isShowingLeaderboard = true
    }

    // Expose leaderboard ID for the wrapper view
    var leaderboardID: String { gameCenterManager.leaderboardID }

   
    func isPresentingFaceUp(_ index: Int) -> Bool {
        // UI should show face-up if the model says so (solved or currently up),
        // or if we’re temporarily presenting due to a mismatch.
        guard cards.indices.contains(index) else { return false }
        return cards[index].isFaceUp || transientFaceUp.contains(index)
    }
}


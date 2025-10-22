/**

 * __Partner Lab 3__
 * Jim Mittler
 * 20 October 2025


 We've updated our Game to use MVVM architecture
 
 all the game logic is moved to the GameModel class
 the game center logic was moved to GameCenterManager
 


 _Italic text_
 __Bold text__
 ~~Strikethrough text~~

 */

import GameKit
import SwiftUI
import Combine

// this class handles communication with game center to track scores and fetch personal bests

// use MainActor to stay on the main thread and avoid race conditions
@MainActor
class GameCenterManager: ObservableObject {
    // Leaderboard identifier used across the app
    let leaderboardID = "KingOfTheHill"

    // A published property to reflect the authentication status.
    @Published var isAuthenticated = GKLocalPlayer.local.isAuthenticated

    init() {
        // Set the handler once when the manager is initialized.
        // GameKit will call this handler whenever the authentication state changes.
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let vc = viewController {
                // If GameKit provides a view controller, it means the user needs to
                // sign in or perform some other action. We present it.
                currentRootViewController()?.present(vc, animated: true)
                return
            }

            if let error = error {
                print(
                    "Error authenticating to Game Center: \(error.localizedDescription)"
                )
                self?.isAuthenticated = false
                return
            }

            // If there's no view controller and no error, the authentication state
            // has been determined.
            self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
        }
    }

    // Submit a score to Game Center
    func submitScore(_ score: Int) async {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("Cannot submit score: player not authenticated.")
            return
        }
        do {
            // send over our score
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID]
            )
            print("Score reported successfully!")
        } catch {
            print("Error reporting score: \(error.localizedDescription)")
        }
    }

    // Load the current player's personal best (lowest) score from Game Center
    func loadPersonalBest() async -> Int? {
        guard GKLocalPlayer.local.isAuthenticated else {
            return nil
        }
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [
                leaderboardID
            ])
            guard let leaderboard = leaderboards.first else {
                print("Leaderboard not found for ID: \(self.leaderboardID)")
                return nil
            }

            // this stuff is async so calling is funky
            let (localPlayerEntry, _) = try await leaderboard.loadEntries(
                for: [GKLocalPlayer.local], timeScope: .allTime)

            // seems to return 0 if no score so deal with that
            guard let score = localPlayerEntry?.score, score > 0 else {
                return nil
            }
            return score
        } catch {
            print("Error loading personal best: \(error.localizedDescription)")
            return nil
        }
    }
}

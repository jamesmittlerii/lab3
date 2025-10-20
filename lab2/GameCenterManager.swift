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

import SwiftUI
import Combine
import UIKit
import GameKit

// this class handles communication with game center to track scores and fetch personal bests
class GameCenterManager: ObservableObject {
    // Leaderboard identifier used across the app
    let leaderboardID = "KingOfTheHill"
    
    // A published property to reflect the authentication status.
    @Published var isAuthenticated = GKLocalPlayer.local.isAuthenticated
    
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
    
    // Submit a score to Game Center
    func submitScore(_ score: Int) {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("Cannot submit score: player not authenticated.")
            return
        }
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
    func loadPersonalBest(completion: @escaping (Int?) -> Void) {
        guard GKLocalPlayer.local.isAuthenticated else {
            completion(nil)
            return
        }
        GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { leaderboards, error in
            if let error = error {
                print("Error loading leaderboard: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let leaderboard = leaderboards?.first else {
                print("Leaderboard not found for ID: \(self.leaderboardID)")
                completion(nil)
                return
            }
            leaderboard.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: NSRange(location: 1, length: 1)
            ) { localPlayerEntry, _, _, error in
                if let error = error {
                    print("Error loading local player entry: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                guard let local = localPlayerEntry, local.score > 0 else {
                    completion(nil)
                    return
                }
                completion(Int(local.score))
            }
        }
    }
}


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
 
 Helpers.swift holds some helper functions because ContentView was getting big
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import UIKit
import AudioToolbox

// Helper to get the current key window’s root view controller in a scene-based app
func currentRootViewController() -> UIViewController? {
    guard
        let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
    else {
        return nil
    }

    let window =
        scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
    return window?.rootViewController
}

// Simple haptic helpers
 func playMatchHaptic() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}

 func playMismatchHaptic() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.warning)
}

// Win sound helper (System Sound 1322 "Bloom")
 func playWinSound() {
    AudioServicesPlaySystemSound(1322)
}

/**
 
 * __Partner Lab 3__
 * Jim Mittler, Dave Norvall
 * Group 11
 * 7 November  2025
 
 
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
import AVFoundation

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


// Keep a single player around for low latency
private var flipPlayer: AVAudioPlayer?

func playFlipSound() {
    // Lazily load the "slapsound" Data asset the first time
    if flipPlayer == nil {
        if let data = NSDataAsset(name: "SlapSound")?.data {
            do {
                flipPlayer = try AVAudioPlayer(data: data)
                flipPlayer?.prepareToPlay()
            } catch {
                print("Failed to init flip sound: \(error)")
            }
        }
    }

    flipPlayer?.currentTime = 0
    flipPlayer?.play()
}

private var dealPlayer: AVAudioPlayer?

// make a deal noise
func startDealSoundLoop(volume: Float = 1.0) {
    // If already playing, restart from the beginning
    if let p = dealPlayer {
        p.currentTime = 0
        p.numberOfLoops = -1
        p.volume = volume
        p.play()
        return
    }

    guard let data = NSDataAsset(name: "Deal2Sound")?.data else {
        // Ensure you have a Data asset named exactly "DealSound" in your asset catalog
        return
    }

    do {
        let player = try AVAudioPlayer(data: data)
        player.numberOfLoops = -1 // loop indefinitely
        player.volume = volume
        player.prepareToPlay()
        player.play()
        dealPlayer = player
    } catch {
        print("Failed to init DealSound: \(error)")
    }
}

func stopDealSoundLoop() {
    dealPlayer?.stop()
    dealPlayer = nil
}

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
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 lab2App is the main app and launches our ContentView
 
 */

import SwiftUI

// standard boilerplate to get going
@main
struct lab2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

//
//  GameCenterView.swift
//  lab2
//
//  Created by cisstudent on 10/27/25.
//


// Swift code here
import SwiftUI
import GameKit

struct GameCenterView: UIViewControllerRepresentable {
    let leaderboardID: String

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let parent: GameCenterView
        init(_ parent: GameCenterView) { self.parent = parent }
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
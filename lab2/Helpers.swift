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

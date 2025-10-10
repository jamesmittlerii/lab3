/**
 
 * Lab 2
 * Dave Norvall and Jim Mittler
 * 10 October 2025
 
 Classic  Concentration Flip Game with Emojis
 
 _Italic text_
 __Bold text__
 ~~Strikethrough text~~

 */

import SwiftUI

struct ContentView: View {
    @State private var cardValues: [String] = []
    @State private var firstSelectedIndex: Int?
    @State private var secondSelectedIndex: Int?
    @State private var tapsCount: Int = 0
    @State private var cardStates: [Bool] = Array(repeating: false, count: 24)
    @State private var gameCompleted: Bool = false
    @State private var scoreHistory: [Int] = []

    var body: some View {
        VStack {
            
            // keep track of taps
            
            Text("Current Taps: \(tapsCount)")
                .font(.largeTitle)
                .padding()

            // if we haven't solved show the grid
            
            if !gameCompleted {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(0..<24, id: \.self) { index in
                        CardView(title: cardStates[index] ? cardValues[index] : "", action: {
                            cardTapped(at: index)
                        })
                    }
                }
                .padding()
            } else {
                // ok - we won! show a summary
                VStack {
                    Text("Game Completed!")
                        .font(.largeTitle)
                        .padding()

                    Text("Total Taps: \(tapsCount)")
                        .font(.title)
                        .padding()

                    Button(action: resetGame) {
                        Text("Play Again")
                            .font(.title2)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }

                    // Score History
                    Text("Score History")
                        .font(.headline)
                        .padding(.top)

                    VStack(spacing: 5) {
                        ForEach(scoreHistory.indices, id: \.self) { index in
                            HStack {
                                Text("Game \(index + 1)")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(scoreHistory[index]) Taps")
                                    .font(.subheadline)
                            }
                            .padding()
                            .border(Color.gray, width: 1)
                        }
                    }
                }
                .padding()
                .onAppear {
                    scoreHistory.append(tapsCount)
                }
            }
        }
        .onAppear(perform: setupGame)
    }

    private func setupGame() {
        let values = ["🍎", "🍌", "🍒", "🍇", "🍉", "🍓", "🍀", "💜", "🔶", "🌼", "⭐️", "🐶"]
        cardValues = (values + values).shuffled()
        cardStates = Array(repeating: false, count: 24)
        tapsCount = 0
        gameCompleted = false
    }

    // tap a card and flip
    private func cardTapped(at index: Int) {
        guard !cardStates[index], !gameCompleted else { return }

        tapsCount += 1
        cardStates[index] = true

        if firstSelectedIndex == nil {
            firstSelectedIndex = index
        } else {
            secondSelectedIndex = index
            checkMatch()
        }

        // Check if all cards are matched; delay the completion UI by 1 second
        if cardStates.allSatisfy({ $0 }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                gameCompleted = true
            }
        }
    }

    // did we match?
    private func checkMatch() {
        guard let firstIndex = firstSelectedIndex, let secondIndex = secondSelectedIndex else { return }

        if cardValues[firstIndex] != cardValues[secondIndex] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                cardStates[firstIndex] = false
                cardStates[secondIndex] = false
                firstSelectedIndex = nil
                secondSelectedIndex = nil
            }
        } else {
            firstSelectedIndex = nil
            secondSelectedIndex = nil
        }
    }

    private func resetGame() {
        setupGame()
    }
}

// this is our card

struct CardView: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.largeTitle)
                .frame(width: 70, height: 70)
                .background(Color.blue)
                .cornerRadius(10)
                .foregroundColor(.white)
                .border(Color.white, width: 2)
        }
        .disabled(!title.isEmpty) // Disable button if it's already matched
    }
}

#Preview {
    ContentView()
}

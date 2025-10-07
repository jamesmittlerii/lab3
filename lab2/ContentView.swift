//
//  ContentView.swift
//  lab2
//
//  Created by cisstudent on 10/7/25.
//

import SwiftUI

let allImages = ["Man1","Man2","Man3","Man4","Man5","Man6","Man7","Man8","Man9","Sou1","Sou2","Sou3","Sou4","Sou5","Sou6","Sou7","Sou8","Sou9"]

struct Card: Identifiable {
    let id = UUID()
    let content: String
    var isFaceUp: Bool = false
    var solved: Bool = false
}

struct TileCards: View {
    let card: Card
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.white)
            RoundedRectangle(cornerRadius: 10)
                .stroke(lineWidth: 3).foregroundColor(.blue)
            Image(card.content).resizable().scaledToFit().padding()
            let cover = RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.blue)
            cover.opacity(card.isFaceUp ? 0 : 1)
        }
        .padding(.horizontal)
        .onTapGesture {
            if !card.solved && !card.isFaceUp {
                onTap()
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var size: Double
    var opacity: Double
    var duration: Double
}

struct ConfettiView: View {
    @State private var confetti = [ConfettiParticle]()
    let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(confetti) { particle in
                    Circle()
                        .fill(colors.randomElement() ?? .blue)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                        .animation(.easeOut(duration: particle.duration), value: particle.y)
                }
            }
            .onAppear {
                confetti = (0..<60).map { _ in
                    ConfettiParticle(
                        x: Double.random(in: 0...geo.size.width),
                        y: -20,
                        size: Double.random(in: 8...18),
                        opacity: 1,
                        duration: Double.random(in: 1.0...2.2)
                    )
                }
                withAnimation(.easeOut(duration: 2)) {
                    for idx in confetti.indices {
                        confetti[idx].y = geo.size.height + 40
                        confetti[idx].opacity = 0
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ContentView: View {
    @State private var cards: [Card] = ContentView.generateCards()
    @State private var indicesOfFaceUp: [Int] = []
    @State private var showConfetti = false
    @State private var confettiID = UUID()
    @State private var flipCount = 0
    @AppStorage("highScore") private var highScore: Int = 0

    static func generateCards() -> [Card] {
        let chosen = allImages.shuffled().prefix(6)
        let pairs = Array(chosen) + Array(chosen)
        return pairs.shuffled().map { Card(content: $0) }
    }

    func handleTap(on index: Int) {
        guard !cards[index].isFaceUp, !cards[index].solved, indicesOfFaceUp.count < 2 else { return }

        // Increment flip count for a valid flip
        flipCount += 1

        var newCards = cards
        newCards[index].isFaceUp = true
        cards = newCards
        indicesOfFaceUp.append(index)

        if indicesOfFaceUp.count == 2 {
            let firstIdx = indicesOfFaceUp[0]
            let secondIdx = indicesOfFaceUp[1]
            if cards[firstIdx].content == cards[secondIdx].content {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    var newCards = cards
                    newCards[firstIdx].solved = true
                    newCards[secondIdx].solved = true
                    cards = newCards
                    indicesOfFaceUp = []
                    checkForWin()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    var newCards = cards
                    newCards[firstIdx].isFaceUp = false
                    newCards[secondIdx].isFaceUp = false
                    cards = newCards
                    indicesOfFaceUp = []
                }
            }
        }
    }

    func checkForWin() {
        if cards.allSatisfy({ $0.solved }) {
            // Update high score if it's 0 (never played) or if this game is better
            if highScore == 0 || flipCount < highScore {
                highScore = flipCount
            }
            confettiID = UUID()
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                showConfetti = false
            }
        }
    }

    func resetGame() {
        cards = ContentView.generateCards()
        indicesOfFaceUp = []
        showConfetti = false
        flipCount = 0
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 8) {
                    HStack(spacing: 30) {
                        Text("Flips: \(flipCount)")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("Best: \(highScore == 0 ? "--" : "\(highScore)")")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 12)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 1)]) {
                        ForEach(cards.indices, id: \.self) { idx in
                            TileCards(card: cards[idx]) {
                                handleTap(on: idx)
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    
                    Button("New Game") {
                        resetGame()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            if showConfetti {
                ConfettiView()
                    .id(confettiID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.default, value: showConfetti)
    }
}

#Preview {
    ContentView()
}


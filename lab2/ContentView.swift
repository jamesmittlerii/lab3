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

struct ContentView: View {
    @State private var cards: [Card] = ContentView.generateCards()
    @State private var indicesOfFaceUp: [Int] = []

    static func generateCards() -> [Card] {
        let chosen = allImages.shuffled().prefix(6)
        let pairs = Array(chosen) + Array(chosen)
        return pairs.shuffled().map { Card(content: $0) }
    }

    func handleTap(on index: Int) {
        // Prevent flipping more than two at once or tapping the same card twice
        guard !cards[index].isFaceUp, !cards[index].solved, indicesOfFaceUp.count < 2 else { return }

        cards[index].isFaceUp = true
        indicesOfFaceUp.append(index)

        // Check for a match after two are face up
        if indicesOfFaceUp.count == 2 {
            let firstIdx = indicesOfFaceUp[0]
            let secondIdx = indicesOfFaceUp[1]
            if cards[firstIdx].content == cards[secondIdx].content {
                // They're a match
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    cards[firstIdx].solved = true
                    cards[secondIdx].solved = true
                    indicesOfFaceUp = []
                }
            } else {
                // Not a match; flip them back after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    cards[firstIdx].isFaceUp = false
                    cards[secondIdx].isFaceUp = false
                    indicesOfFaceUp = []
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            Button("New Game") {
                cards = ContentView.generateCards()
                indicesOfFaceUp = []
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 1)]) {
                ForEach(cards.indices, id: \.self) { idx in
                    TileCards(card: cards[idx]) {
                        handleTap(on: idx)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

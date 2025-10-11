/**
 
 * Lab 2
 * Dave Norvall and Jim Mittler
 * 10 October 2025
 
 Classic Concentration Flip Game with Emojis
 
 _Italic text_
 __Bold text__
 ~~Strikethrough text~~

 */

import SwiftUI


// our mahjong tiles 1-9 in three suites
let allImages: [String] = {
    let suits = ["Man", "Sou", "Pin"]
    return suits.flatMap { suit in
        (1...9).map { "\(suit)\($0)" }
    }
}()

// data structure for a tile
struct Card: Identifiable {
    let id = UUID()
    let content: String
    var isFaceUp: Bool = false
    var solved: Bool = false
}

// view for our tile
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

// the main view
struct ContentView: View {
    
    // what tile was first flipped
    @State private var firstSelectedIndex: Int?
    
    // second flipped
    @State private var secondSelectedIndex: Int?
    
    // how many clicks have we done this game?
    @State private var tapsCount: Int = 0
    
    // did we win?
    
    @State private var gameCompleted: Bool = false
    
    // score keeping history
    @State private var scoreHistory: [Int] = []
    @State private var dateHistory: [String] = [] // Date array
    
    // our randomized tiles
    @State private var cards: [Card] = ContentView.generateCards()
    
    // shuffle the cards and return an array of 12 pairs
    static func generateCards() -> [Card] {
           let chosen = allImages.shuffled().prefix(12)
           let pairs = Array(chosen) + Array(chosen)
           return pairs.shuffled().map { Card(content: $0) }
       }
    
    var body: some View {
        VStack {
            
            // keep track of taps
            
            Text("Current Taps: \(tapsCount)")
                .font(.largeTitle)
                .padding()
            HStack {
                Text("RESET")
                
                Button {resetGame()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                        .accessibilityLabel("New Game")
                }
            }
            // if we haven't solved show the grid
            
            if !gameCompleted {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(cards.indices, id: \.self) { index in
                        TileCards(card: cards[index])
                        {
                            cardTapped(at: index)
                        }
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
                        Text("Play Again ?")
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
                                Text("Game \(index + 1) - Date: \(dateHistory[index])")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(scoreHistory[index]) Taps")
                                Spacer()
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
                    dateHistory.append(getCurrentDateString())
                    
                }
            }
        }
        .onAppear(perform: resetGame)
    }

    // get the current date time
private func getCurrentDateString() -> String {
        let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MM/dd '@' HH:mm"
        return dateFormatter.string(from: Date())
    }

    // reset everything for the next game
    private func resetGame() {
        tapsCount = 0
        gameCompleted = false
        cards = ContentView.generateCards()
        firstSelectedIndex = nil
        secondSelectedIndex = nil
    }

    // tap a card and flip
    
    /* flip only if the card is face down, the card hasn't been matched, the game isn't completed and there aren't already two cards flipped */
    private func cardTapped(at index: Int) {
        guard !cards[index].isFaceUp,
                !cards[index].solved,
              !gameCompleted,
              firstSelectedIndex == nil || secondSelectedIndex == nil
        else { return }

        // increment our counter
        tapsCount += 1
        
        // turn the card over
        cards[index].isFaceUp = true

        // keep track of which cards we flipped over
        if firstSelectedIndex == nil {
            firstSelectedIndex = index
        } else {
            secondSelectedIndex = index
            
            // if this is the second card flipped, did we match?
            checkMatch()
        }

        
    }

    // did we match?
    private func checkMatch() {
        guard let firstIndex = firstSelectedIndex, let secondIndex = secondSelectedIndex else { return }

        // if we didn't match, flip the cards back over after a short delay
        if cards[firstIndex].content != cards[secondIndex].content {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                cards[firstIndex].isFaceUp = false
                cards[secondIndex].isFaceUp = false
                firstSelectedIndex = nil
                secondSelectedIndex = nil
            }
        } else {
            
            // ok..we matched! mark that.
            cards[firstIndex].solved = true
            cards[secondIndex].solved = true
            firstSelectedIndex = nil
            secondSelectedIndex = nil
            // Check if all cards are matched; delay the completion UI by 1 second
            if cards.allSatisfy({ $0.solved }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    gameCompleted = true
                }
            }
        }
    }

   
}



#Preview {
    ContentView()
}

//
//  ContentView.swift
//  lab2
//
//  Created by cisstudent on 10/7/25.
//

import SwiftUI

let images = ["Man1","Man2","Man3","Man4","Man5","Man6","Man7","Man8","Man9","Sou1","Sou2","Sou3","Sou4","Sou5","Sou6","Sou7","Sou8","Sou9"]


struct TileCards: View {
    var content: String
    @State var isFaceUp: Bool = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.white)
            RoundedRectangle(cornerRadius: 10)
                .stroke(lineWidth: 3).foregroundColor(.blue)
           
            Image(content).resizable().scaledToFit().padding()
            let cover = RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.blue)
            
            cover.opacity( isFaceUp ? 0 : 1)
            
        }.padding(.horizontal)
            .onTapGesture { isFaceUp = !isFaceUp }
                
            
    }
}

struct ContentView: View {
    var body: some View {
        ScrollView {
            Text("Game").font(.largeTitle).foregroundColor(.blue)
                .bold(true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 1)]) {
                ForEach(images[0..<images.count],
                        id:\.self) {
                    im in TileCards(content:im).aspectRatio(1, contentMode: .fit)
                }
            }
            
        }
    }
}

#Preview {
    ContentView()
}

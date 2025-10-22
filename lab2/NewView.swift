//
//  NewView.swift
//  lab2
//
//  Created by cisstudent on 10/21/25.
//

import SwiftUI

struct ImageView: View {
    let index: Int
    var body: some View {
        Image("Man1")
            .resizable()
            .scaledToFit()
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(Color.secondary.opacity(0.3))
            .cornerRadius(10)
    }
}

struct NewView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Define a fixed number of columns for the grid
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Text("Flips")
                    .font(horizontalSizeClass == .regular ? .title : .headline)
                    .foregroundColor(.blue)
               
                Spacer()

                // new game icon
                Button {
                   
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(horizontalSizeClass == .regular ? .title : .body)
                        .foregroundColor(.blue)
                        .accessibilityLabel("New Game")
                }
                .help("Start a new game")

                // global leadboard icon
                Button {
                   
                } label: {
                    Label("Leaderboard", systemImage: "trophy")
                        .labelStyle(.iconOnly)
                        .font(horizontalSizeClass == .regular ? .title : .body)
                        .foregroundColor(
                             .orange
                        )
                        .accessibilityLabel("Show Leaderboard")
                }
                
                .help("Show global leaderboard")
            }
            // Use GeometryReader to calculate the height for each grid item
            GeometryReader { geometry in
                let spacing: CGFloat = 12
                let numberOfRows: CGFloat = 6 // 24 items in 4 columns
                let totalVerticalSpacing = spacing * (numberOfRows - 1)
                let itemHeight = (geometry.size.height - totalVerticalSpacing) / numberOfRows
                
                LazyVGrid(columns: columns, spacing: spacing) {
                    // Loop to generate 24 image views
                    ForEach(1..<25) { index in
                        ImageView(index: index)
                            .frame(height: max(0, itemHeight))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: 700, maxHeight: .infinity)
    }
        
    
}

#Preview {
    NewView()
}


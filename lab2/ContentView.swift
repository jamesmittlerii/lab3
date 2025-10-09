//
//  ContentView.swift
//  lab2
//
//  Created by cisstudent on 10/7/25.
//

import SwiftUI

let images = [
    "Man1","Man2","Man3","Man4","Man5","Man6","Man7","Man8","Man9",
    "Sou1","Sou2","Sou3","Sou4","Sou5","Sou6","Sou7","Sou8","Sou9"
]

// Make exactly 24 items for a 4×6 grid (example: repeat first 12)
private let gridItems24: [String] = {
    let base = Array(images.prefix(12))
    return (base + base) // 24 items total
}()

struct TileCards: View {
    var content: String
    @State var isFaceUp: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.white)
            RoundedRectangle(cornerRadius: 10)
                .stroke(lineWidth: 3)
                .foregroundColor(.blue)

            Image(content)
                .resizable()
                .scaledToFit()
                .padding()

            let cover = RoundedRectangle(cornerRadius: 10)
                .foregroundColor(.blue)

            cover.opacity(isFaceUp ? 0 : 1)
        }
        .padding(.horizontal)
        .onTapGesture { isFaceUp.toggle() }
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        GeometryReader { geo in
            // Base layout constants
            let baseHorizontalPadding: CGFloat = 16
            let baseInterItemSpacing: CGFloat = 12
            let rows = 6
            let cols = 4

            // Compact-width (iPhone) tweaks
            let isCompact = (hSizeClass == .compact)
            let horizontalPadding: CGFloat = isCompact ? 8 : baseHorizontalPadding
            let tightSpacing: CGFloat = isCompact ? 2 : baseInterItemSpacing

            // Simple header height estimate (title line + top padding)
            let estimatedHeaderHeight: CGFloat = 44 + 12

            // Available grid area
            let availableWidth = max(0, geo.size.width - horizontalPadding * 2)
            let availableHeight = max(0, geo.size.height - estimatedHeaderHeight - 24) // bottom safety

            // Compute both width-limited and height-limited square tile sizes
            let widthLimitedTile =
                (availableWidth - tightSpacing * CGFloat(cols - 1)) / CGFloat(cols)
            let heightLimitedTile =
                (availableHeight - tightSpacing * CGFloat(rows - 1)) / CGFloat(rows)

            // Choose the smaller so the grid always fits
            let tileSize = max(0, min(widthLimitedTile, heightLimitedTile))

            // Determine if width or height is the limiting factor
            let widthIsLimiter = widthLimitedTile <= heightLimitedTile + .ulpOfOne

            // Use tight spacing on iPhone; keep base spacing on iPad-like widths
            let columnSpacing = tightSpacing
            // Optionally, add any remaining vertical space (when width is the limiter) into row spacing
            let tilesTotalHeight = tileSize * CGFloat(rows)
            let leftoverHeight = max(0, availableHeight - tilesTotalHeight)
            let extraPerGap = (widthIsLimiter && rows > 1) ? leftoverHeight / CGFloat(rows - 1) : 0
            let rowSpacing = tightSpacing + extraPerGap

            // Grid definition: 4 fixed columns with (possibly) tighter horizontal spacing
            let columns: [GridItem] = Array(
                repeating: GridItem(.fixed(tileSize), spacing: columnSpacing),
                count: cols
            )

            // Total grid height: tiles + (rows - 1) gaps using the computed row spacing
            let gridHeight = max(0, tilesTotalHeight + rowSpacing * CGFloat(rows - 1))

            VStack(spacing: 8) {
                // Header
                Text("Game")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                    .bold()

                // Grid with tighter spacing and reduced side padding on iPhone
                LazyVGrid(columns: columns, spacing: rowSpacing) {
                    ForEach(gridItems24.indices, id: \.self) { idx in
                        TileCards(content: gridItems24[idx])
                            .frame(width: tileSize, height: tileSize)
                    }
                }
                .frame(width: max(0, availableWidth), height: gridHeight)
                .padding(.horizontal, horizontalPadding)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview {
    ContentView()
}

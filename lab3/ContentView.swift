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
 
 */

import Combine
import GameKit
import SwiftUI

/* this is our structure for the tiled card in the UI */
struct TiledCard: View {
    let card: Card
    let isFaceUp: Bool
    let isMatchWiggling: Bool
    let isWinWiggling: Bool
    let onTap: () -> Void
    
    let isPhone = UIDevice.current.userInterfaceIdiom == .phone

    // rotation angle is for wiggle
    @State private var rotationAngle: Angle = .zero
    @State private var flipRotation: Double = 0

    // Animation constants
    private let flipDuration: Double = 0.4
    private let wiggleAngle: Double = 4
    private let wiggleStepDuration: Double = 0.125

    var body: some View {
        ZStack {
            // FRONT face
            Group {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.white)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(lineWidth: 3)
                    .foregroundColor(.blue)
                Image(card.content)
                    .resizable()
                    .scaledToFit()
                    .padding(isPhone ? 8 : 12)
            }
            // start with the image flipped so when we rotate, it comes out looking right
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            // only show the image if the angle supports it
            // without this, the card started showing right away
            .opacity(flipRotation >= 90 ? 1 : 0)

            // BACK face - mahjong image with green background
            Group {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 54.0/255.0, green: 96.0/255.0, blue: 79.0/255.0))
                Image("mahjong")
                    .resizable()
                    .scaledToFit()
                
                    .padding(isPhone ? 6 : 12)
                    .compositingGroup()
                                       .mask(
                                           RoundedRectangle(cornerRadius: 12)
                                               .inset(by: 12)   // keep a bit of margin from the stroke
                                               .fill(.white)
                                               .blur(radius: 12)     // larger blur = softer edge
                                       )
                RoundedRectangle(cornerRadius: 10)
                    .stroke(lineWidth: 3)
                    .foregroundColor(.blue)
            }
            .opacity(flipRotation < 90 ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // for wiggle
        .rotationEffect(rotationAngle)
        
        // for our flipping
        .rotation3DEffect(
            .degrees(flipRotation),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.4 //  adds depth realism
        )
        .onTapGesture(perform: onTap)
        
        // if we've flipping the card up or down, do the animation. reverse the direction if flipping down
        .onChange(of: isFaceUp) { _, newValue in
            withAnimation(.easeInOut(duration: flipDuration)) {
                flipRotation = newValue ? 180 : 0
            }
        }
        .onChange(of: isMatchWiggling) { _, shouldWiggle in
            if shouldWiggle { performWiggle(duration: 0.5) }
        }
        .onChange(of: isWinWiggling) { _, shouldWiggle in
            if shouldWiggle { performWiggle(duration: 2.0) }
        }
        .onAppear {
            flipRotation = isFaceUp ? 180 : 0
        }
    }

    // function to wiggle the card. We use this when we've matched 2 cards or win the game.
    
    @MainActor
    private func performWiggle(duration: Double) {
        let wiggles = Int(duration / wiggleStepDuration)
        let animation = Animation.linear(duration: wiggleStepDuration)
        let pause = UInt64(wiggleStepDuration * 1_000_000_000)

        Task {
            for i in 0..<wiggles {
                let angle = (i.isMultiple(of: 2) ? wiggleAngle : -wiggleAngle)
                withAnimation(animation) { rotationAngle = .degrees(angle) }
                try? await Task.sleep(nanoseconds: pause)
            }
            withAnimation(animation) { rotationAngle = .zero }
        }
    }
}

// this is for showing some confetti when we win
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var size: Double
    var opacity: Double
    var duration: Double
}

// a view to show some confetti
struct ConfettiView: View {
    @State private var confetti = [ConfettiParticle]()
    let colors: [Color] = [
        .red, .blue, .green, .orange, .purple, .pink, .yellow,
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(confetti) { particle in
                    Circle()
                        .fill(colors.randomElement() ?? .blue)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                        .animation(
                            .easeOut(duration: particle.duration),
                            value: particle.y
                        )
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

// MARK: - Fireworks

struct FireworkParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var dx: Double
    var dy: Double
    var size: Double
    var hue: Double
    var opacity: Double
    var duration: Double
}

struct FireworksView: View {
    @State private var particles: [FireworkParticle] = []
    private let launchCount = 6
    // Bigger bursts
    private let particlesPerBurst = 60
    private let gravity: Double = 140 // points/sec^2

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    // Add a soft glow to make particles feel larger/brighter
                    context.addFilter(.shadow(color: .white.opacity(0.35), radius: 6, x: 0, y: 0))
                    for p in particles {
                        let color = Color(hue: p.hue, saturation: 0.9, brightness: 1.0, opacity: p.opacity)
                        context.fill(
                            Path(ellipseIn: CGRect(x: p.x, y: p.y, width: p.size, height: p.size)),
                            with: .color(color)
                        )
                    }
                }
                .onAppear {
                    spawnFireworks(in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnFireworks(in size: CGSize) {
        particles.removeAll()

        // Schedule multiple launches
        for launchIndex in 0..<launchCount {
            let delay = Double(launchIndex) * 0.25
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let launchX = Double.random(in: size.width * 0.2...size.width * 0.8)
                let launchY = Double(size.height) + 10
                let peakY = Double.random(in: size.height * 0.25...size.height * 0.45)

                // Create a "rocket" particle that will explode at peak
                let ascentDuration = 0.6
                let rocket = FireworkParticle(
                    x: launchX,
                    y: launchY,
                    dx: 0,
                    dy: -Double.random(in: 300...420),
                    size: 10, // bigger rocket
                    hue: Double.random(in: 0...1),
                    opacity: 1.0,
                    duration: ascentDuration
                )
                particles.append(rocket)

                // Animate rocket upward
                withAnimation(.easeOut(duration: ascentDuration)) {
                    let targetY = peakY
                    if let idx = particles.firstIndex(where: { $0.id == rocket.id }) {
                        particles[idx].y = targetY
                        particles[idx].opacity = 0.0
                        particles[idx].size = 3
                    }
                }

                // After ascent, create burst particles
                DispatchQueue.main.asyncAfter(deadline: .now() + ascentDuration) {
                    let burstOrigin = CGPoint(x: launchX, y: peakY)
                    let baseHue = Double.random(in: 0...1)
                    let burst = (0..<particlesPerBurst).map { i -> FireworkParticle in
                        let angle = Double(i) / Double(particlesPerBurst) * 2.0 * .pi
                        // faster particles for a larger-looking burst
                        let speed = Double.random(in: 120...240)
                        let dx = cos(angle) * speed
                        let dy = sin(angle) * speed
                        return FireworkParticle(
                            x: burstOrigin.x,
                            y: burstOrigin.y,
                            dx: dx,
                            dy: dy,
                            size: Double.random(in: 6...12), // larger particle size
                            hue: fmod(baseHue + Double.random(in: -0.1...0.1) + 1, 1),
                            opacity: 1.0,
                            duration: 1.2
                        )
                    }
                    particles.append(contentsOf: burst)

                    // Animate burst outward + fade + gravity
                    let steps = 24
                    let stepDuration = 1.2 / Double(steps)
                    for step in 1...steps {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                            for idx in particles.indices {
                                // Only update particles that are part of the burst (size <= 12 is a cheap heuristic)
                                guard particles[idx].size <= 12 else { continue }
                                let t = Double(step) * stepDuration
                                particles[idx].x += particles[idx].dx * stepDuration
                                particles[idx].y += particles[idx].dy * stepDuration + 0.5 * gravity * stepDuration * stepDuration
                                particles[idx].dy += gravity * stepDuration
                                particles[idx].opacity = max(0, 1.0 - t / 1.2)
                            }
                        }
                    }
                }
            }
        }
    }
}



// this is the main view for the game
struct ContentView: View {

    // use a variable to determine if we are iphone or ipad
    // unfortunately we need to tweak because the screen ratios and sizes are so different
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // ViewModel for MVVM
    @StateObject private var viewModel: GameViewModel

    init() {
        let manager = GameCenterManager()
        _viewModel = StateObject(wrappedValue: GameViewModel(gameCenterManager: manager))
    }

    // anything with @state will refresh the UI on change
    @State private var showingLeaderboard = false
    
    // Dealing animation state
    @State private var dealtIndices: Set<Int> = []

    // the grid layout logic got nasty so moved to a function
    // this structure returns the calculations
    struct GridParameters {
        let itemWidth: CGFloat
        let itemHeight: CGFloat
        let columnCount: Int
        let spacing: CGFloat
        let columns: [GridItem]
    }

    // this is the logic to make the grid look nice
    // unfortunately it's a nightmare so it lives in a function
    
    @MainActor // Use @MainActor since it uses UIDevice.current
    // function to figure out all the layout shenanigans
    private func calculateGridParameters(
        geometry: GeometryProxy,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> GridParameters {
        
        // --- Setup and Context ---
        let isLandscape = geometry.size.width > geometry.size.height
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
       
        let spacing: CGFloat = isPhone ? 12 : 24

        // we use 4x6 for portrait
        // 8x3 on phone landscape and 6x4 on ipad landscape
        // that seemed to look best
        
        let aspectRatio: CGFloat = 2.0 / 3.0 // Width / Height
        let columnCount: Int = isLandscape ? (isPhone ? 8 : 6) : 4
        let rowCount: Int = isLandscape ? (isPhone ? 3 : 4) : 6

        // --- Available Space Calculation ---
        let totalHorizontalSpacing = spacing * (CGFloat(columnCount) - 1)
        let totalVerticalSpacing = spacing * (CGFloat(rowCount) - 1)

        let availableWidth = max(0, geometry.size.width - totalHorizontalSpacing)
        let availableHeight = max(0, geometry.size.height - totalVerticalSpacing)

        // --- Tile Size Calculation (Constrained by Width and Height) ---
        
        // Size if constrained by width
        let widthFromWidthConstraint = availableWidth / CGFloat(columnCount)
        let heightFromWidthConstraint = widthFromWidthConstraint / aspectRatio

        // Size if constrained by height
        let heightFromHeightConstraint = availableHeight / CGFloat(rowCount)
        let widthFromHeightConstraint = heightFromHeightConstraint * aspectRatio
        
        // Choose the smaller size to ensure the grid fits entirely
        let (itemWidth, itemHeight): (CGFloat, CGFloat) =
            (heightFromWidthConstraint <= heightFromHeightConstraint)
        ? (widthFromWidthConstraint, heightFromWidthConstraint)   // Width is limiting
            : (widthFromHeightConstraint, heightFromHeightConstraint) // Height is limiting

        // create our grid item array
        // we were very determined to find the best itemWidth
        let columns = Array(
            repeating: GridItem(.fixed(itemWidth), spacing: spacing),
            count: columnCount
        )
        
        // kick back our calculations
        return GridParameters(
            itemWidth: itemWidth,
            itemHeight: itemHeight,
            columnCount: columnCount,
            spacing: spacing,
            columns: columns
        )
    }

    // Deal animation helper
    @MainActor
    private func dealCards() async {
        dealtIndices.removeAll()
        // Tell the ViewModel we’re starting the dealing sequence (intent-based)
        viewModel.dealDidStart()
        defer {
            // Ensure we always notify finish (even on cancellation)
            viewModel.dealDidFinish()
        }

        // Tune these to taste
        let delayStep: Double = 0.07
        let spring = Animation.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.15)
        // Deal in reverse order
        for idx in viewModel.cards.indices.reversed() {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .seconds(delayStep))
            withAnimation(spring) {
                _ = dealtIndices.insert(idx)
            }
        }
    }
    
    // this is our main view...finally!
    var body: some View {
        // Device-based font sizing
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let textFont: Font = isPhone ? .headline : .title
        let buttonIconFont: Font = isPhone ? .body : .title
        
        ZStack {
            VStack(spacing: 8) {
                
                // top bar is info and buttons
                
                HStack(spacing: 8) {
                    Text("Flips: \(viewModel.flipCount)")
                        .font(textFont)
                        .foregroundColor(.blue)
                    Text(
                        {
                            if let best = viewModel.personalBest {
                                return "High Score: \(best)"
                            } else {
                                return "High Score: --"
                            }
                        }()
                    )
                    .font(textFont)
                    .foregroundColor(.green)

                    // new game icon
                    Button {
                        viewModel.newGame()
                        Task { await dealCards() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                            .accessibilityLabel("New Game")
                            .font(buttonIconFont)
                    }
                    .help("Start a new game")

                    // global leadboard icon
                    Button {
                        viewModel.showLeaderboard()
                    } label: {
                        Label("Leaderboard", systemImage: "trophy")
                            .labelStyle(.iconOnly)
                            .foregroundColor(
                                viewModel.isAuthenticated ? .orange : .gray
                            )
                            .accessibilityLabel("Show Leaderboard")
                            .font(buttonIconFont)
                    }
                    .disabled(!viewModel.isAuthenticated)
                    .help("Show global leaderboard")
                }
                .padding(.bottom, 4)

                // do the grid via GeometryReader and function
                
                GeometryReader { geometry in
                    let params = calculateGridParameters(
                        geometry: geometry,
                        horizontalSizeClass: horizontalSizeClass
                    )

                    // Precompute a deck origin (top-center above the grid)
                    let gridWidth = params.itemWidth * CGFloat(params.columnCount)
                        + params.spacing * CGFloat(params.columnCount - 1)
                    let deckOrigin = CGPoint(
                        x: gridWidth / 2.0,
                        y: -params.itemHeight - 24 // slightly above first row
                    )

                    VStack(spacing: 8) {
                        // trusty LazyVGrid
                        LazyVGrid(columns: params.columns, spacing: params.spacing) {
                            
                            // spin through our cards
                            // send each TileCard our wiggle flags
                            
                            ForEach(viewModel.cards.indices, id: \.self) { idx in
                                let isDealt = dealtIndices.contains(idx)
                                
                                TiledCard(
                                    card: viewModel.cards[idx],
                                    isFaceUp: viewModel.isPresentingFaceUp(idx),
                                    isMatchWiggling: viewModel.wigglingIndices.contains(idx),
                                    isWinWiggling: viewModel.celebration != nil
                                ) {
                                    // secret sauce closure to handle flip card logic in the model
                                    viewModel.flip(cardAt: idx)
                                }
                                // Compute the target center of this card within the grid
                                .modifier(DealInModifier(
                                    index: idx,
                                    columnCount: params.columnCount,
                                    itemSize: CGSize(width: params.itemWidth, height: params.itemHeight),
                                    spacing: params.spacing,
                                    deckOrigin: deckOrigin,
                                    isDealt: isDealt
                                ))
                                .allowsHitTesting(!viewModel.isInteractionDisabled && isDealt)
                            }
                        }
                        // Keep grid full width; it will take remaining height
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .onAppear {
                            // trigger the initial deal when the grid appears
                            Task { await dealCards() }
                        }
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()

            // if we won, show a celebration overlay (confetti or fireworks)
            if let style = viewModel.celebration {
                Group {
                    switch style {
                    case .confetti:
                        ConfettiView()
                    case .fireworks:
                        FireworksView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        // animate overlay show/hide
        .animation(.default, value: viewModel.celebration != nil)

        // Bottom progress section pinned to the safe area
        // Hide on iPhone in landscape (compact vertical size class)
        .safeAreaInset(edge: .bottom) {
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            if isPhone, verticalSizeClass == .compact {
                // No progress bar in iPhone landscape
                EmptyView()
            } else {
                let percent = Int((viewModel.progress * 100).rounded())
                HStack {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Progress")
                                .font(isPhone ? .subheadline : .headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(percent)%")
                                .font(isPhone ? .subheadline : .headline)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: viewModel.progress)
                            .tint(.blue)
                            .animation(.easeInOut(duration: 0.25), value: viewModel.progress)
                    }
                }
                .padding(.horizontal,100)
                .padding(.top, 0)
                .padding(.bottom, 4)
            }
        }
        .sheet(isPresented: $viewModel.isShowingLeaderboard) {
            GameCenterView(leaderboardID: viewModel.leaderboardID)
                .ignoresSafeArea()
        }
    }
}

// Helper view modifier to make each card fly in from a shared "deck" origin
private struct DealInModifier: ViewModifier {
    let index: Int
    let columnCount: Int
    let itemSize: CGSize
    let spacing: CGFloat
    let deckOrigin: CGPoint
    let isDealt: Bool

    func body(content: Content) -> some View {
        // Determine row/column
        let col = index % columnCount
        let row = index / columnCount

        // Compute the target center within the grid's coordinate space
        let targetCenter = CGPoint(
            x: CGFloat(col) * (itemSize.width + spacing) + itemSize.width / 2.0,
            y: CGFloat(row) * (itemSize.height + spacing) + itemSize.height / 2.0
        )

        // Offset needed to place this card at the deck origin
        let dx = deckOrigin.x - targetCenter.x
        let dy = deckOrigin.y - targetCenter.y

        // Spin parameters
        let turns: Double = 1.5 // number of full spins while flying in
        let direction: Double = 1 // index.isMultiple(of: 2) ? 1 : -1 // alternate direction for variety
        let spinDegrees = direction * 360.0 * turns

        return content
            .frame(width: itemSize.width, height: itemSize.height)
            .opacity(isDealt ? 1 : 0)
            .scaleEffect(isDealt ? 1 : 0.6)
            .rotationEffect(.degrees(isDealt ? 0 : spinDegrees))
            .offset(x: isDealt ? 0 : dx, y: isDealt ? 0 : dy)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: isDealt)
    }
}

// Simple shared delegate to dismiss GKGameCenterViewController
final class GameCenterDelegate: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDelegate()
    func gameCenterViewControllerDidFinish(
        _ gameCenterViewController: GKGameCenterViewController
    ) {
        gameCenterViewController.dismiss(animated: true)
    }
}

#Preview {
    ContentView()
}

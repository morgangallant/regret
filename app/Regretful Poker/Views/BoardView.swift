//
//  BoardView.swift
//  Regretful Poker
//
//  The middle of the table: the pot, the five community card positions, and
//  the shoe the cards come from.
//

import SwiftUI

struct BoardView: View {
    var state: GameState
    /// Width of one community card.
    var cardWidth: CGFloat = 54

    /// Cards forming the winning hand, ringed in gold at showdown.
    var highlighted: Set<Card> = []

    var body: some View {
        VStack(spacing: 14) {
            potDisplay
            communityCards
            if state.street == .complete {
                HandResultBanner(state: state)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else if !state.narration.isEmpty {
                Text(state.narration)
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .transition(.opacity)
                    .id(state.narration)
            }
        }
        .animation(.spring(duration: 0.45), value: state.board)
        .animation(.snappy(duration: 0.3), value: state.pot)
    }

    // MARK: Pot

    private var potDisplay: some View {
        VStack(spacing: 6) {
            Text(state.street.name.uppercased())
                .font(Theme.display(9.5, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.gold.opacity(0.75))

            HStack(spacing: 8) {
                ChipStackView(amount: state.pot, diameter: 17)
                Text(Theme.chips(state.pot))
                    .font(Theme.numeric(20, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.black.opacity(0.35)))
            .overlay(
                Capsule().strokeBorder(Theme.gold.opacity(0.28), lineWidth: 1))
            .opacity(state.pot > 0 ? 1 : 0.25)
        }
    }

    // MARK: Community cards

    private var communityCards: some View {
        HStack(spacing: cardWidth * 0.13) {
            ForEach(0..<5, id: \.self) { index in
                ZStack {
                    CardSlotView(width: cardWidth)
                    if index < state.board.count {
                        let card = state.board[index]
                        CardView(card: card, width: cardWidth,
                                 isHighlighted: highlighted.contains(card))
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .top)
                                        .combined(with: .opacity)
                                        .combined(with: .scale(scale: 0.7)),
                                    removal: .opacity))
                    }
                }
            }
        }
    }
}

/// Who took the pot, shown under the board once the hand is over.
struct HandResultBanner: View {
    var state: GameState

    var body: some View {
        let winners = state.winners
        VStack(spacing: 3) {
            Text(winners.count > 1 ? "SPLIT POT" : "WINNER")
                .font(Theme.display(9, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Theme.gold.opacity(0.8))

            ForEach(winners) { winner in
                HStack(spacing: 8) {
                    Text(winner.name)
                        .font(Theme.display(15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("+\(Theme.chips(winner.won))")
                        .font(Theme.numeric(15, weight: .bold))
                        .foregroundStyle(Theme.winGreen)
                }
                if winner.handCategory != .none {
                    Text(winner.handCategory.name)
                        .font(Theme.display(11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.6), radius: 14, y: 5)
    }
}

/// The undealt shoe, drawn as a few stacked card backs.
struct DeckView: View {
    var cardWidth: CGFloat = 34
    /// Hidden between hands, when there is nothing to deal.
    var isVisible: Bool = true

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                CardView(card: nil, width: cardWidth)
                    .offset(x: CGFloat(index) * -1.1,
                            y: CGFloat(index) * -1.1)
            }
        }
        .rotationEffect(.degrees(-8))
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .accessibilityHidden(true)
    }
}

#Preview("Board") {
    var state = GameState()
    state.board = [Card(.queen, .heart), Card(.nine, .spade),
                   Card(.two, .diamond), Card(.queen, .club)]
    state.pot = 1840
    state.street = .turn
    state.narration = "Nash bets 240"

    return BoardView(state: state,
                     highlighted: [Card(.queen, .heart), Card(.queen, .club)])
        .padding(50)
        .background(Theme.feltGradient)
}

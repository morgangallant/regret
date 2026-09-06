//
//  CardView.swift
//  Regretful Poker
//
//  A single playing card, face up or face down, plus the empty slot used for
//  board positions that haven't been dealt yet.
//

import SwiftUI

/// Standard playing card proportions (2.5" x 3.5").
private let cardAspect: CGFloat = 5.0 / 7.0

struct CardView: View {
    /// The card to show, or nil to draw the back.
    var card: Card?
    /// Width in points; height and all interior metrics derive from it.
    var width: CGFloat
    /// Muted, for a folded seat's cards.
    var isDimmed: Bool = false
    /// Ringed in gold, for cards making up a winning hand.
    var isHighlighted: Bool = false

    private var height: CGFloat { width / cardAspect }
    private var radius: CGFloat { width * 0.11 }

    var body: some View {
        Group {
            if let card {
                face(card)
            } else {
                back
            }
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: radius))
        .overlay {
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(
                    isHighlighted ? Theme.gold : Color.black.opacity(0.35),
                    lineWidth: isHighlighted ? max(1.5, width * 0.045) : 0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: width * 0.07,
                x: 0, y: width * 0.035)
        .saturation(isDimmed ? 0.15 : 1)
        .opacity(isDimmed ? 0.55 : 1)
    }

    // MARK: Face

    private func face(_ card: Card) -> some View {
        let tint = Theme.suitColor(card.suit)
        return ZStack {
            Theme.cardFace

            // A large, low-contrast pip so the suit reads at a glance even
            // when the card is small.
            Text(card.suit.glyph)
                .font(.system(size: width * 0.72))
                .foregroundStyle(tint.opacity(0.16))
                .offset(y: height * 0.06)

            VStack(alignment: .leading, spacing: -width * 0.06) {
                Text(card.rank.label)
                    .font(.system(size: width * 0.42, weight: .bold,
                                  design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(card.suit.glyph)
                    .font(.system(size: width * 0.32))
            }
            .foregroundStyle(tint)
            .padding(.leading, width * 0.10)
            .padding(.top, width * 0.07)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .topLeading)

            // Mirrored index in the opposite corner, as on a real card.
            VStack(alignment: .trailing, spacing: -width * 0.06) {
                Text(card.suit.glyph)
                    .font(.system(size: width * 0.22))
                Text(card.rank.label)
                    .font(.system(size: width * 0.28, weight: .bold,
                                  design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .foregroundStyle(tint.opacity(0.8))
            .rotationEffect(.degrees(180))
            .padding(.trailing, width * 0.10)
            .padding(.bottom, width * 0.07)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .bottomTrailing)
        }
        .accessibilityElement()
        .accessibilityLabel("\(card.rank.name) of \(card.suit.name)")
    }

    // MARK: Back

    private var back: some View {
        ZStack {
            Theme.cardBackGradient

            // Diagonal lattice.
            Canvas { context, size in
                let spacing = width * 0.16
                var path = Path()
                var x = -size.height
                while x < size.width + size.height {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += spacing
                }
                context.stroke(path, with: .color(.white.opacity(0.09)),
                               lineWidth: 0.8)
            }

            RoundedRectangle(cornerRadius: radius * 0.6)
                .strokeBorder(Theme.gold.opacity(0.55), lineWidth: width * 0.02)
                .padding(width * 0.09)

            Text("R")
                .font(.system(size: width * 0.34, weight: .heavy,
                              design: .serif))
                .foregroundStyle(Theme.gold.opacity(0.65))
        }
        .accessibilityElement()
        .accessibilityLabel("Face down card")
    }
}

/// The dashed outline that marks a board position not yet dealt.
struct CardSlotView: View {
    var width: CGFloat

    private var height: CGFloat { width / cardAspect }

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.11)
            .strokeBorder(
                Color.white.opacity(0.13),
                style: StrokeStyle(lineWidth: 1.2, dash: [width * 0.10,
                                                          width * 0.08]))
            .frame(width: width, height: height)
    }
}

#Preview("Cards") {
    HStack(spacing: 12) {
        CardView(card: Card(.ace, .spade), width: 70)
        CardView(card: Card(.queen, .heart), width: 70)
        CardView(card: Card(.ten, .diamond), width: 70, isHighlighted: true)
        CardView(card: Card(.two, .club), width: 70, isDimmed: true)
        CardView(card: nil, width: 70)
        CardSlotView(width: 70)
    }
    .padding(40)
    .background(Theme.feltGradient)
}

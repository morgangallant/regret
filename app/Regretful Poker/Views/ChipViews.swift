//
//  ChipViews.swift
//  Regretful Poker
//
//  Chip rendering: a single disc, a stack of them, and the labelled pile that
//  sits in front of a seat showing what it has committed this street.
//

import SwiftUI

/// A single chip seen slightly from above, so stacks read as physical.
struct ChipView: View {
    var color: Color
    var diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(1.0),
                                 color.opacity(0.72)],
                        startPoint: .top, endPoint: .bottom))

            // Edge spots, the dashes around a real chip's rim.
            Circle()
                .strokeBorder(
                    Color.white.opacity(0.75),
                    style: StrokeStyle(lineWidth: diameter * 0.13,
                                       dash: [diameter * 0.16,
                                              diameter * 0.20]))
                .padding(diameter * 0.065)

            Circle()
                .strokeBorder(Color.black.opacity(0.28),
                              lineWidth: diameter * 0.04)

            Circle()
                .fill(Color.white.opacity(0.10))
                .padding(diameter * 0.26)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// A vertical pile of chips totalling `amount`.
struct ChipStackView: View {
    var amount: UInt64
    var diameter: CGFloat = 18

    private var colors: [Color] { Theme.chipBreakdown(amount) }

    var body: some View {
        // Chips overlap heavily so the pile reads as edge-on discs.
        let step = diameter * 0.17
        ZStack(alignment: .bottom) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                ChipView(color: color, diameter: diameter)
                    .offset(y: -step * CGFloat(index))
            }
        }
        .frame(width: diameter,
               height: diameter + step * CGFloat(max(colors.count - 1, 0)),
               alignment: .bottom)
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }
}

/// The chips a seat has pushed forward this street, with the amount beside
/// them. Renders nothing when the seat has committed nothing.
struct BetPileView: View {
    var amount: UInt64
    var diameter: CGFloat = 15

    var body: some View {
        if amount > 0 {
            HStack(spacing: 5) {
                ChipStackView(amount: amount, diameter: diameter)
                Text(Theme.chips(amount))
                    .font(Theme.numeric(diameter * 0.78, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.black.opacity(0.45)))
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.10),
                                       lineWidth: 0.5))
            .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }
}

#Preview("Chips") {
    HStack(alignment: .bottom, spacing: 26) {
        ChipStackView(amount: 3, diameter: 24)
        ChipStackView(amount: 27, diameter: 24)
        ChipStackView(amount: 640, diameter: 24)
        BetPileView(amount: 125, diameter: 20)
    }
    .padding(40)
    .background(Theme.feltGradient)
}

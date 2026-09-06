//
//  Theme.swift
//  Regretful Poker
//
//  Colors, gradients, and metrics for the table. Kept in code rather than an
//  asset catalog so the whole look can be adjusted in one place.
//

import SwiftUI

enum Theme {

    // MARK: Palette

    static let gold = Color(red: 0.85, green: 0.70, blue: 0.36)
    static let goldDim = Color(red: 0.55, green: 0.45, blue: 0.22)
    static let chrome = Color(red: 0.62, green: 0.65, blue: 0.68)

    static let foldRed = Color(red: 0.78, green: 0.26, blue: 0.28)
    static let callBlue = Color(red: 0.31, green: 0.56, blue: 0.78)
    static let raiseAmber = Color(red: 0.87, green: 0.58, blue: 0.24)
    static let winGreen = Color(red: 0.36, green: 0.76, blue: 0.50)

    static let ink = Color(red: 0.05, green: 0.06, blue: 0.06)
    static let pod = Color(red: 0.10, green: 0.12, blue: 0.13)
    static let podRaised = Color(red: 0.15, green: 0.17, blue: 0.18)

    // MARK: Room and felt

    /// The space the table sits in.
    static let roomGradient = RadialGradient(
        colors: [
            Color(red: 0.09, green: 0.11, blue: 0.11),
            Color(red: 0.03, green: 0.04, blue: 0.04),
        ],
        center: .center, startRadius: 40, endRadius: 900)

    /// The playing surface.
    static let feltGradient = RadialGradient(
        colors: [
            Color(red: 0.13, green: 0.42, blue: 0.31),
            Color(red: 0.07, green: 0.26, blue: 0.20),
            Color(red: 0.04, green: 0.17, blue: 0.13),
        ],
        center: .center, startRadius: 10, endRadius: 620)

    /// The padded rail around the felt.
    static let railGradient = LinearGradient(
        colors: [
            Color(red: 0.19, green: 0.13, blue: 0.11),
            Color(red: 0.10, green: 0.07, blue: 0.06),
        ],
        startPoint: .top, endPoint: .bottom)

    // MARK: Cards

    static let cardFace = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let cardRed = Color(red: 0.76, green: 0.16, blue: 0.20)
    static let cardBlack = Color(red: 0.11, green: 0.11, blue: 0.13)

    static let cardBackGradient = LinearGradient(
        colors: [
            Color(red: 0.42, green: 0.11, blue: 0.16),
            Color(red: 0.21, green: 0.05, blue: 0.09),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static func suitColor(_ suit: Suit) -> Color {
        suit.isRed ? cardRed : cardBlack
    }

    // MARK: Chips

    /// Casino-ish denomination colors, largest denomination first.
    static let chipDenominations: [(value: UInt64, color: Color)] = [
        (1000, Color(red: 0.44, green: 0.29, blue: 0.62)),
        (500, Color(red: 0.16, green: 0.17, blue: 0.20)),
        (100, Color(red: 0.13, green: 0.13, blue: 0.14)),
        (25, Color(red: 0.16, green: 0.50, blue: 0.32)),
        (5, Color(red: 0.72, green: 0.21, blue: 0.24)),
        (1, Color(red: 0.90, green: 0.90, blue: 0.89)),
    ]

    /// Breaks an amount into stacked chips, largest first, capped so a huge
    /// bet doesn't try to draw a thousand discs.
    static func chipBreakdown(_ amount: UInt64, maxChips: Int = 8) -> [Color] {
        guard amount > 0 else { return [] }
        var remaining = amount
        var chips: [Color] = []
        for (value, color) in chipDenominations {
            while remaining >= value && chips.count < maxChips {
                remaining -= value
                chips.append(color)
            }
        }
        if chips.isEmpty { chips.append(chipDenominations.last!.color) }
        return chips
    }

    // MARK: Type

    /// Chip counts and pot sizes, so digits don't jitter as they animate.
    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: Formatting

    /// Renders a chip count compactly: 1250 becomes "1.25K".
    static func chips(_ amount: UInt64) -> String {
        switch amount {
        case 0: return "0"
        case ..<10_000:
            return amount.formatted(.number.grouping(.automatic))
        case ..<1_000_000:
            let k = Double(amount) / 1000
            return k.formatted(.number.precision(.fractionLength(0...2))) + "K"
        default:
            let m = Double(amount) / 1_000_000
            return m.formatted(.number.precision(.fractionLength(0...2))) + "M"
        }
    }
}

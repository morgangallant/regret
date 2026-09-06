//
//  Card.swift
//  Regretful Poker
//
//  Playing card primitives. These deliberately mirror the encoding in
//  `include/regret.h` so that a `regret_card_t` converts to a `Card` with
//  arithmetic and no lookup table.
//

import SwiftUI

/// A card rank.
///
/// Raw values match the `Rank` enum in `src/poker.zig`: Ace is 0 and Two is 12,
/// so a *lower* raw value is a *stronger* rank. Don't sort on `rawValue`
/// expecting ascending strength — use ``isStronger(than:)``.
enum Rank: UInt8, CaseIterable, Hashable, Sendable {
    case ace, king, queen, jack, ten, nine, eight, seven, six, five, four, three, two

    /// The one or two character label printed on the card face.
    var label: String {
        switch self {
        case .ace: "A"
        case .king: "K"
        case .queen: "Q"
        case .jack: "J"
        case .ten: "10"
        case .nine: "9"
        case .eight: "8"
        case .seven: "7"
        case .six: "6"
        case .five: "5"
        case .four: "4"
        case .three: "3"
        case .two: "2"
        }
    }

    /// The name used in prose, e.g. "Pair of Queens".
    var name: String {
        switch self {
        case .ace: "Ace"
        case .king: "King"
        case .queen: "Queen"
        case .jack: "Jack"
        case .ten: "Ten"
        case .nine: "Nine"
        case .eight: "Eight"
        case .seven: "Seven"
        case .six: "Six"
        case .five: "Five"
        case .four: "Four"
        case .three: "Three"
        case .two: "Two"
        }
    }

    var pluralName: String { self == .six ? "Sixes" : name + "s" }

    func isStronger(than other: Rank) -> Bool { rawValue < other.rawValue }
}

/// A card suit.
///
/// Raw values match the `Suit` enum in `src/poker.zig`, which orders suits by
/// the American high-card-by-suit ranking so the core can break ties without
/// splitting pots.
enum Suit: UInt8, CaseIterable, Hashable, Sendable {
    case spade, heart, diamond, club

    var glyph: String {
        switch self {
        case .spade: "\u{2660}"
        case .heart: "\u{2665}"
        case .diamond: "\u{2666}"
        case .club: "\u{2663}"
        }
    }

    var name: String {
        switch self {
        case .spade: "Spades"
        case .heart: "Hearts"
        case .diamond: "Diamonds"
        case .club: "Clubs"
        }
    }

    var isRed: Bool { self == .heart || self == .diamond }
}

/// A single playing card.
struct Card: Hashable, Identifiable, Sendable {
    var rank: Rank
    var suit: Suit

    init(_ rank: Rank, _ suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    /// The wire encoding shared with the Zig core: `rank * 4 + suit`.
    var code: UInt8 { rank.rawValue * 4 + suit.rawValue }

    /// Decodes the wire encoding. Returns nil for `REGRET_CARD_NONE` and any
    /// other out-of-range byte.
    init?(code: UInt8) {
        guard code < 52,
              let rank = Rank(rawValue: code / 4),
              let suit = Suit(rawValue: code % 4)
        else { return nil }
        self.init(rank, suit)
    }

    var id: UInt8 { code }

    /// Compact notation, e.g. "Qh".
    var shorthand: String {
        let s = switch suit {
        case .spade: "s"
        case .heart: "h"
        case .diamond: "d"
        case .club: "c"
        }
        return label + s
    }

    var label: String { rank.label }

    static let fullDeck: [Card] = Rank.allCases.flatMap { rank in
        Suit.allCases.map { Card(rank, $0) }
    }
}

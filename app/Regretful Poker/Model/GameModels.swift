//
//  GameModels.swift
//  Regretful Poker
//
//  Swift mirrors of the snapshot types in `include/regret.h`.
//
//  These are pure value types with no rules in them. Every one is produced by
//  the poker core and consumed by the views; nothing in the UI decides what is
//  legal, who wins, or how big the pot is.
//

import SwiftUI

// MARK: - Enumerations

/// Which betting round a hand is in.
enum Street: UInt8, CaseIterable, Hashable, Sendable {
    case preflop, flop, turn, river, showdown, complete

    var name: String {
        switch self {
        case .preflop: "Pre-Flop"
        case .flop: "Flop"
        case .turn: "Turn"
        case .river: "River"
        case .showdown: "Showdown"
        case .complete: "Hand Complete"
        }
    }

    /// How many community cards are face up during this street.
    var boardCount: Int {
        switch self {
        case .preflop: 0
        case .flop: 3
        case .turn: 4
        case .river, .showdown, .complete: 5
        }
    }
}

/// A seat's participation in the current hand.
enum PlayerStatus: UInt8, Hashable, Sendable {
    case active, folded, allIn, busted

    /// Whether the seat still has a claim on the pot.
    var isContesting: Bool { self == .active || self == .allIn }
}

/// The kind of a betting action.
enum ActionKind: UInt8, Hashable, Sendable {
    case none, fold, check, call, bet, raise, post

    var label: String {
        switch self {
        case .none: ""
        case .fold: "Fold"
        case .check: "Check"
        case .call: "Call"
        case .bet: "Bet"
        case .raise: "Raise"
        case .post: "Post"
        }
    }

    /// Tint for the badge that floats over a seat after it acts.
    var badgeColor: Color {
        switch self {
        case .fold: Theme.foldRed
        case .check, .call: Theme.callBlue
        case .bet, .raise: Theme.raiseAmber
        case .post, .none: Theme.chrome
        }
    }
}

/// The category of a made five-card hand, weakest to strongest.
enum HandCategory: UInt8, Hashable, Comparable, Sendable {
    case none, highCard, onePair, twoPair, threeOfAKind, straight
    case flush, fullHouse, fourOfAKind, straightFlush, royalFlush

    var name: String {
        switch self {
        case .none: ""
        case .highCard: "High Card"
        case .onePair: "Pair"
        case .twoPair: "Two Pair"
        case .threeOfAKind: "Three of a Kind"
        case .straight: "Straight"
        case .flush: "Flush"
        case .fullHouse: "Full House"
        case .fourOfAKind: "Four of a Kind"
        case .straightFlush: "Straight Flush"
        case .royalFlush: "Royal Flush"
        }
    }

    static func < (a: HandCategory, b: HandCategory) -> Bool {
        a.rawValue < b.rawValue
    }
}

// MARK: - Snapshot types

/// One seat at the table, as of the moment the snapshot was taken.
struct PlayerView: Identifiable, Hashable, Sendable {
    var seat: Int
    var name: String
    /// Chips behind, not yet committed.
    var stack: UInt64
    /// Chips pushed forward on the current street.
    var committed: UInt64

    /// Hole cards. `nil` entries are cards this viewer isn't entitled to see —
    /// the core redacts them, so a snapshot never leaks opponent holdings.
    var hole: [Card?]

    var status: PlayerStatus
    var isHuman: Bool

    var lastAction: ActionKind

    /// Set only at showdown, once the hand is face up.
    var handCategory: HandCategory
    /// Chips awarded when the hand completed.
    var won: UInt64

    var id: Int { seat }

    /// Whether this seat's cards are face up to everyone.
    var isFaceUp: Bool { hole.contains { $0 != nil } && !isHuman }

    static func seat(_ seat: Int, name: String) -> PlayerView {
        PlayerView(
            seat: seat, name: name, stack: 0, committed: 0,
            hole: [nil, nil], status: .active, isHuman: false,
            lastAction: .none, handCategory: .none, won: 0)
    }
}

/// A complete, self-contained description of the table.
struct GameState: Hashable, Sendable {
    var players: [PlayerView] = []

    /// Community cards that are face up. Always 0, 3, 4, or 5 entries.
    var board: [Card] = []

    /// Everything in the middle, including chips committed this street.
    var pot: UInt64 = 0

    var street: Street = .preflop

    var buttonSeat: Int = 0
    var smallBlindSeat: Int = 0
    var bigBlindSeat: Int = 0
    /// Seat currently on the clock, or nil when nobody is.
    var actingSeat: Int?

    var smallBlind: UInt64 = 1
    var bigBlind: UInt64 = 2

    /// Highest amount committed by any seat on this street.
    var currentBet: UInt64 = 0

    var handNumber: UInt32 = 0

    /// A short line describing what just happened. Presentation only — the
    /// core doesn't produce this.
    var narration: String = ""

    var human: PlayerView? { players.first(where: \.isHuman) }

    func player(at seat: Int) -> PlayerView? {
        players.first { $0.seat == seat }
    }

    /// Seats still contesting the pot.
    var contenders: [PlayerView] { players.filter { $0.status.isContesting } }

    /// Winners of the hand, once it has completed.
    var winners: [PlayerView] { players.filter { $0.won > 0 } }
}

/// What the seat on the clock is allowed to do.
///
/// The UI enables buttons and clamps its slider from this; it never works out
/// legality itself.
struct LegalActions: Hashable, Sendable {
    var seat: Int

    var canFold = false
    var canCheck = false
    var canCall = false
    var canBet = false
    var canRaise = false

    /// Extra chips required to call.
    var callAmount: UInt64 = 0

    /// Bet/raise bounds as *raise-to totals* for the street — what the seat's
    /// `committed` becomes, not the delta. Going all in means raising to
    /// ``maxRaiseTo``.
    var minRaiseTo: UInt64 = 0
    var maxRaiseTo: UInt64 = 0

    /// Whether a bet or raise is possible at all.
    var canAggress: Bool { canBet || canRaise }
    /// Whether the sizing slider has any room to move.
    var canSize: Bool { canAggress && maxRaiseTo > minRaiseTo }

    static func none(seat: Int) -> LegalActions { LegalActions(seat: seat) }
}

/// An action submitted by the UI.
struct PlayerAction: Hashable, Sendable {
    var kind: ActionKind
    /// For `.bet` and `.raise`, the raise-to total for the street.
    var amount: UInt64 = 0

    static let fold = PlayerAction(kind: .fold)
    static let check = PlayerAction(kind: .check)
    static let call = PlayerAction(kind: .call)

    static func bet(to amount: UInt64) -> PlayerAction {
        PlayerAction(kind: .bet, amount: amount)
    }

    static func raise(to amount: UInt64) -> PlayerAction {
        PlayerAction(kind: .raise, amount: amount)
    }
}

/// Table setup, handed to the core once when a game starts.
struct GameConfig: Hashable, Sendable, Codable {
    var playerCount: Int = 6
    var humanSeat: Int = 0
    var startingStack: UInt64 = 200
    var smallBlind: UInt64 = 1
    var bigBlind: UInt64 = 2
    /// 0 lets the core pick a seed.
    var rngSeed: UInt64 = 0

    static let seatRange = 2...10
}

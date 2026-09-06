//
//  PokerEngine.swift
//  Regretful Poker
//
//  The seam between the UI and the poker core.
//
//  This mirrors the API in `include/regret.h` one-for-one. The app talks to
//  the core only through this protocol, so the scripted fixture used for UI
//  work and the real Zig implementation are interchangeable.
//

import Foundation

@MainActor
protocol PokerEngine: AnyObject {
    /// The current table snapshot.
    var state: GameState { get }

    /// What the seat on the clock may do, or nil when nobody is on the clock.
    var legalActions: LegalActions? { get }

    /// Shuffle, post blinds, and deal. Returns false if a hand is already in
    /// progress or fewer than two seats have chips.
    @discardableResult
    func startHand() -> Bool

    /// Submit an action for the seat on the clock. Returns false and changes
    /// nothing if the action is illegal.
    @discardableResult
    func apply(_ action: PlayerAction) -> Bool

    /// Advance by one step that needs no human input: a bot's turn, a street
    /// deal, the showdown, or awarding the pot. Returns true if anything
    /// changed.
    @discardableResult
    func step() -> Bool

    /// Cards making up the winning hand, for highlighting at showdown.
    ///
    /// Not part of the C ABI yet — see the note in `include/regret.h`. Returns
    /// an empty set when unknown.
    var winningCards: Set<Card> { get }
}

extension PokerEngine {
    var winningCards: Set<Card> { [] }
}

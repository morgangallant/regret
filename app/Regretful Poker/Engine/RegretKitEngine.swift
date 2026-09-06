//
//  RegretKitEngine.swift
//  Regretful Poker
//
//  Bridges the Zig core to the app.
//
//  The whole file is behind `#if canImport(RegretKit)`, so it compiles to
//  nothing until `RegretKit.xcframework` is built and linked. Nothing else in
//  the app needs to change when that happens — see `EngineSelection`.
//

#if canImport(RegretKit)

import Foundation
import RegretKit

@MainActor
final class RegretKitEngine: PokerEngine {

    private let game: OpaquePointer
    private(set) var state = GameState()
    private(set) var legalActions: LegalActions?

    init?(config: GameConfig) {
        var raw = regret_config_t(
            player_count: UInt8(config.playerCount),
            human_seat: UInt8(config.humanSeat),
            starting_stack: config.startingStack,
            small_blind: config.smallBlind,
            big_blind: config.bigBlind,
            rng_seed: config.rngSeed)

        guard let game = regret_game_new(&raw) else { return nil }
        self.game = game
        refresh()
    }

    deinit {
        // `regret_game_free` is documented as safe to call from any thread as
        // long as nothing else is touching the handle, which holds here.
        regret_game_free(game)
    }

    // MARK: PokerEngine

    @discardableResult
    func startHand() -> Bool {
        let ok = regret_game_start_hand(game)
        refresh()
        return ok
    }

    @discardableResult
    func apply(_ action: PlayerAction) -> Bool {
        let raw = regret_action_t(
            kind: regret_action_kind_t(rawValue: action.kind.rawValue),
            amount: action.amount)
        let ok = regret_game_apply(game, raw)
        refresh()
        return ok
    }

    @discardableResult
    func step() -> Bool {
        let changed = regret_game_step(game)
        if changed { refresh() }
        return changed
    }

    // MARK: Snapshot conversion

    private func refresh() {
        var snapshot = regret_game_state_t()
        regret_game_state(game, &snapshot)
        state = Self.convert(snapshot)

        var actions = regret_legal_actions_t()
        legalActions = regret_game_legal_actions(game, &actions)
            ? Self.convert(actions)
            : nil
    }

    private static func convert(_ raw: regret_game_state_t) -> GameState {
        var state = GameState()

        state.players = fixedArray(raw.players, count: Int(raw.player_count))
            .map(convert)
        state.board = fixedArray(raw.board, count: Int(raw.board_count))
            .compactMap(Card.init(code:))
        state.pot = raw.pot
        state.street = Street(rawValue: raw.street.rawValue) ?? .preflop
        state.buttonSeat = Int(raw.button_seat)
        state.smallBlindSeat = Int(raw.small_blind_seat)
        state.bigBlindSeat = Int(raw.big_blind_seat)
        state.actingSeat = raw.acting_seat == 0xFF ? nil : Int(raw.acting_seat)
        state.smallBlind = raw.small_blind
        state.bigBlind = raw.big_blind
        state.currentBet = raw.current_bet
        state.handNumber = raw.hand_number
        return state
    }

    private static func convert(_ raw: regret_player_view_t) -> PlayerView {
        PlayerView(
            seat: Int(raw.seat),
            name: string(from: raw.name),
            stack: raw.stack,
            committed: raw.committed,
            hole: [Card(code: raw.hole.0), Card(code: raw.hole.1)],
            status: PlayerStatus(rawValue: raw.status.rawValue) ?? .active,
            isHuman: raw.is_human,
            lastAction: ActionKind(rawValue: raw.last_action.rawValue) ?? .none,
            handCategory: HandCategory(rawValue: raw.hand_category.rawValue)
                ?? .none,
            won: raw.won)
    }

    private static func convert(_ raw: regret_legal_actions_t) -> LegalActions {
        LegalActions(
            seat: Int(raw.seat),
            canFold: raw.can_fold,
            canCheck: raw.can_check,
            canCall: raw.can_call,
            canBet: raw.can_bet,
            canRaise: raw.can_raise,
            callAmount: raw.call_amount,
            minRaiseTo: raw.min_raise_to,
            maxRaiseTo: raw.max_raise_to)
    }

    // MARK: C interop helpers

    /// Reads the first `count` elements out of a fixed-size C array, which
    /// Swift imports as a homogeneous tuple.
    private static func fixedArray<Tuple, Element>(
        _ tuple: Tuple, count: Int
    ) -> [Element] {
        withUnsafeBytes(of: tuple) { raw in
            let buffer = raw.bindMemory(to: Element.self)
            return Array(buffer.prefix(count))
        }
    }

    /// Reads a NUL-terminated `char[N]` field.
    private static func string<Tuple>(from tuple: Tuple) -> String {
        withUnsafeBytes(of: tuple) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

#endif

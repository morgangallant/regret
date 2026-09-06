//
//  ScriptedEngine.swift
//  Regretful Poker
//
//  A stand-in for the poker core, used to build and exercise the UI before any
//  of it exists in Zig.
//
//  This is deliberately NOT a poker implementation. It has no rules in it: it
//  replays a hand-written tape of beats and does the bookkeeping arithmetic
//  each beat spells out. It cannot evaluate a hand, work out who is entitled
//  to act, or decide what is legal — every one of those answers is baked into
//  the tape below.
//
//  Delete this file once `RegretKitEngine` is wired up.
//

import Foundation

@MainActor
final class ScriptedEngine: PokerEngine {

    private(set) var state = GameState()
    private(set) var legalActions: LegalActions?
    private(set) var winningCards: Set<Card> = []

    private let config: GameConfig
    private var tape: [Beat] = []
    private var cursor = 0
    /// Set while the tape is parked on a hero decision.
    private var awaitingHero = false

    init(config: GameConfig) {
        self.config = config
        state = Self.emptyTable(config)
    }

    // MARK: PokerEngine

    @discardableResult
    func startHand() -> Bool {
        winningCards = []
        cursor = 0
        awaitingHero = false
        legalActions = nil

        let handNumber = state.handNumber + 1
        var fresh = state
        fresh.handNumber = handNumber
        fresh.board = []
        fresh.pot = 0
        fresh.currentBet = 0
        fresh.street = .preflop
        fresh.narration = ""
        fresh.actingSeat = nil
        for index in fresh.players.indices {
            fresh.players[index].committed = 0
            fresh.players[index].hole = [nil, nil]
            fresh.players[index].lastAction = .none
            fresh.players[index].handCategory = .none
            fresh.players[index].won = 0
            fresh.players[index].status =
                fresh.players[index].stack > 0 ? .active : .busted
        }

        // Move the button one seat on for each new hand.
        let count = fresh.players.count
        fresh.buttonSeat = Int(handNumber - 1) % count
        fresh.smallBlindSeat = (fresh.buttonSeat + 1) % count
        fresh.bigBlindSeat = (fresh.buttonSeat + 2) % count
        state = fresh

        tape = Self.demoTape(state: state, config: config)
        return true
    }

    @discardableResult
    func apply(_ action: PlayerAction) -> Bool {
        guard awaitingHero, let legal = legalActions,
              let hero = state.player(at: legal.seat) else { return false }

        switch action.kind {
        case .fold:
            guard legal.canFold else { return false }
            commit(seat: hero.seat, to: hero.committed, kind: .fold)
            state.players[index(of: hero.seat)].status = .folded
            // Everyone else takes it down; jump to the folded ending.
            tape = Self.heroFoldedTape(state: state)
            cursor = 0

        case .check:
            guard legal.canCheck else { return false }
            commit(seat: hero.seat, to: hero.committed, kind: .check)

        case .call:
            guard legal.canCall else { return false }
            commit(seat: hero.seat, to: hero.committed + legal.callAmount,
                   kind: .call)

        case .bet, .raise:
            guard legal.canAggress,
                  action.amount >= legal.minRaiseTo,
                  action.amount <= legal.maxRaiseTo else { return false }
            commit(seat: hero.seat, to: action.amount, kind: action.kind)

        case .none, .post:
            return false
        }

        awaitingHero = false
        legalActions = nil
        return true
    }

    @discardableResult
    func step() -> Bool {
        guard !awaitingHero, cursor < tape.count else { return false }
        let beat = tape[cursor]
        cursor += 1
        perform(beat)
        return true
    }

    // MARK: Beats

    /// One scripted moment. Each case carries every number it needs; nothing
    /// here works anything out for itself.
    private enum Beat {
        /// Set a seat's committed chips for the street to an exact total.
        case act(seat: Int, kind: ActionKind, to: UInt64)
        /// Mark a seat as folded.
        case fold(seat: Int)
        /// Deal the hero's hole cards.
        case dealHole(seat: Int, cards: [Card])
        /// Move to a new street and reveal the given board.
        case street(Street, board: [Card])
        /// Park until the person picks an action.
        case heroDecision(LegalActions)
        /// Turn opponents' cards face up and label their hands.
        case reveal([Int: (cards: [Card], category: HandCategory)])
        /// Award the pot and end the hand.
        case award(seat: Int, category: HandCategory, winning: [Card])
        /// Table talk shown under the board.
        case narrate(String)
        /// Put a seat on the clock, for the "thinking" indicator.
        case clock(Int?)
    }

    private func perform(_ beat: Beat) {
        switch beat {
        case let .act(seat, kind, to):
            commit(seat: seat, to: to, kind: kind)
            state.narration = narration(seat: seat, kind: kind, to: to)

        case let .fold(seat):
            state.players[index(of: seat)].status = .folded
            state.players[index(of: seat)].lastAction = .fold
            state.narration = "\(name(seat)) folds"

        case let .dealHole(seat, cards):
            state.players[index(of: seat)].hole = cards

        case let .street(street, board):
            state.street = street
            state.board = board
            state.currentBet = 0
            for index in state.players.indices {
                state.players[index].committed = 0
                if state.players[index].status == .active {
                    state.players[index].lastAction = .none
                }
            }
            state.narration = street == .preflop ? "" : "\(street.name) is dealt"

        case let .heroDecision(legal):
            legalActions = clampToStack(legal)
            state.actingSeat = legal.seat
            awaitingHero = true

        case let .reveal(hands):
            state.street = .showdown
            for (seat, hand) in hands {
                state.players[index(of: seat)].hole = hand.cards
                state.players[index(of: seat)].handCategory = hand.category
            }
            state.actingSeat = nil
            state.narration = "Showdown"

        case let .award(seat, category, winning):
            state.street = .complete
            state.players[index(of: seat)].stack += state.pot
            state.players[index(of: seat)].won = state.pot
            state.players[index(of: seat)].handCategory = category
            winningCards = Set(winning)
            state.actingSeat = nil
            for index in state.players.indices {
                state.players[index].committed = 0
            }
            state.narration = "\(name(seat)) \(winVerb(seat)) \(Theme.chips(state.pot))"

        case let .narrate(text):
            state.narration = text

        case let .clock(seat):
            state.actingSeat = seat
        }
    }

    // MARK: Bookkeeping

    /// The tape is written before the hand starts, so its amounts can exceed
    /// what a seat still has by the time a later street arrives. Pull them
    /// back to the seat's real chips. The core will do this properly; here it
    /// just keeps the fixture from offering a bet nobody can make.
    private func clampToStack(_ legal: LegalActions) -> LegalActions {
        guard let player = state.player(at: legal.seat) else { return legal }
        let ceiling = player.stack + player.committed

        var clamped = legal
        clamped.callAmount = min(legal.callAmount, player.stack)
        clamped.maxRaiseTo = min(legal.maxRaiseTo, ceiling)
        clamped.minRaiseTo = min(legal.minRaiseTo, clamped.maxRaiseTo)
        // A seat with nothing behind can only fold or check.
        if player.stack == 0 {
            clamped.canBet = false
            clamped.canRaise = false
            clamped.canCall = false
        }
        return clamped
    }

    /// Moves a seat's committed total to `to`, taking the difference out of
    /// its stack and adding it to the pot. Pure arithmetic.
    private func commit(seat: Int, to total: UInt64, kind: ActionKind) {
        let i = index(of: seat)
        let previous = state.players[i].committed
        let delta = total > previous ? total - previous : 0
        let paid = min(delta, state.players[i].stack)

        state.players[i].stack -= paid
        state.players[i].committed = previous + paid
        state.players[i].lastAction = kind
        state.pot += paid
        state.currentBet = max(state.currentBet, state.players[i].committed)
        if state.players[i].stack == 0 && kind != .fold {
            state.players[i].status = .allIn
        }
        state.actingSeat = nil
    }

    private func index(of seat: Int) -> Int {
        state.players.firstIndex { $0.seat == seat } ?? 0
    }

    /// "You win", but "Nash wins".
    private func winVerb(_ seat: Int) -> String {
        (state.player(at: seat)?.isHuman ?? false) ? "win" : "wins"
    }

    private func name(_ seat: Int) -> String {
        state.player(at: seat)?.name ?? "Seat \(seat)"
    }

    private func narration(seat: Int, kind: ActionKind, to: UInt64) -> String {
        switch kind {
        case .post: "\(name(seat)) posts \(Theme.chips(to))"
        case .check: "\(name(seat)) checks"
        case .call: "\(name(seat)) calls"
        case .bet: "\(name(seat)) bets \(Theme.chips(to))"
        case .raise: "\(name(seat)) raises to \(Theme.chips(to))"
        case .fold: "\(name(seat)) folds"
        case .none: ""
        }
    }

    // MARK: Fixture data

    private static let botNames = [
        "Nash", "Kuhn", "Selten", "Harsanyi", "Aumann",
        "Shapley", "Myerson", "Zermelo", "Borel",
    ]

    private static func emptyTable(_ config: GameConfig) -> GameState {
        var state = GameState()
        state.smallBlind = config.smallBlind
        state.bigBlind = config.bigBlind
        state.players = (0..<config.playerCount).map { seat in
            var player = PlayerView.seat(seat, name: "")
            player.isHuman = seat == config.humanSeat
            player.stack = config.startingStack
            if player.isHuman {
                player.name = "You"
            } else {
                let offset = seat > config.humanSeat ? seat - 1 : seat
                player.name = botNames[offset % botNames.count]
            }
            return player
        }
        return state
    }

    /// The scripted hand. Every number here is hand-authored — this is a
    /// storyboard for the UI, not a simulation.
    private static func demoTape(state: GameState,
                                 config: GameConfig) -> [Beat] {
        let hero = config.humanSeat
        let sb = state.smallBlindSeat
        let bb = state.bigBlindSeat
        let big = config.bigBlind

        // Opponents in seat order, skipping the hero.
        let others = state.players.map(\.seat).filter { $0 != hero }
        let first = others.first ?? hero
        let second = others.count > 1 ? others[1] : first
        let third = others.count > 2 ? others[2] : second

        let heroHole = [Card(.ace, .spade), Card(.king, .spade)]
        let flop = [Card(.king, .diamond), Card(.seven, .spade),
                    Card(.two, .heart)]
        let turn = flop + [Card(.ace, .club)]
        let river = turn + [Card(.nine, .diamond)]

        var beats: [Beat] = [
            .dealHole(seat: hero, cards: heroHole),
            .act(seat: sb, kind: .post, to: config.smallBlind),
            .act(seat: bb, kind: .post, to: big),
            .narrate("Blinds are in"),
        ]

        // Pre-flop: one opponent opens, hero decides, the rest come along.
        beats += [
            .clock(first), .fold(seat: first),
            .clock(second), .act(seat: second, kind: .raise, to: big * 3),
            .heroDecision(LegalActions(
                seat: hero, canFold: true, canCheck: false, canCall: true,
                canBet: false, canRaise: true,
                callAmount: big * 3,
                minRaiseTo: big * 6,
                maxRaiseTo: state.player(at: hero)?.stack ?? big * 50)),
            .clock(third), .act(seat: third, kind: .call, to: big * 3),
        ]

        // Flop.
        beats += [
            .street(.flop, board: flop),
            .clock(second), .act(seat: second, kind: .check, to: 0),
            .clock(third), .act(seat: third, kind: .bet, to: big * 4),
            .heroDecision(LegalActions(
                seat: hero, canFold: true, canCheck: false, canCall: true,
                canBet: false, canRaise: true,
                callAmount: big * 4,
                minRaiseTo: big * 8,
                maxRaiseTo: state.player(at: hero)?.stack ?? big * 40)),
            .clock(second), .fold(seat: second),
        ]

        // Turn.
        beats += [
            .street(.turn, board: turn),
            .clock(third), .act(seat: third, kind: .check, to: 0),
            .heroDecision(LegalActions(
                seat: hero, canFold: true, canCheck: true, canCall: false,
                canBet: true, canRaise: false,
                callAmount: 0,
                minRaiseTo: big,
                maxRaiseTo: state.player(at: hero)?.stack ?? big * 30)),
            .clock(third), .act(seat: third, kind: .call, to: big * 5),
        ]

        // River, showdown, and the pot going the hero's way.
        beats += [
            .street(.river, board: river),
            .clock(third), .act(seat: third, kind: .check, to: 0),
            .heroDecision(LegalActions(
                seat: hero, canFold: true, canCheck: true, canCall: false,
                canBet: true, canRaise: false,
                callAmount: 0,
                minRaiseTo: big,
                maxRaiseTo: state.player(at: hero)?.stack ?? big * 20)),
            .clock(third), .act(seat: third, kind: .call, to: big * 6),
            .reveal([third: (cards: [Card(.queen, .heart),
                                     Card(.queen, .club)],
                             category: .onePair)]),
            .award(seat: hero, category: .twoPair,
                   winning: [Card(.ace, .spade), Card(.ace, .club),
                             Card(.king, .spade), Card(.king, .diamond),
                             Card(.nine, .diamond)]),
        ]

        return beats
    }

    /// What happens after the person folds: the pot goes to whoever is left.
    private static func heroFoldedTape(state: GameState) -> [Beat] {
        let winner = state.players.first {
            !$0.isHuman && $0.status != .folded && $0.status != .busted
        }
        guard let winner else { return [] }
        return [
            .narrate("\(winner.name) takes it down"),
            .award(seat: winner.seat, category: .none, winning: []),
        ]
    }
}

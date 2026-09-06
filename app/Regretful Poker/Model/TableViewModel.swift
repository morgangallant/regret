//
//  TableViewModel.swift
//  Regretful Poker
//
//  Owns the engine and paces it.
//
//  The core exposes one discrete step at a time so each bot turn and street
//  deal animates on its own. This drives that loop on a timer and republishes
//  the snapshot for the views.
//

import SwiftUI

/// Chooses which implementation of ``PokerEngine`` the app runs against.
enum EngineSelection {
    /// Flip to `true` once libregret actually implements the API in
    /// `include/regret.h`. Until then the app runs the scripted UI fixture.
    ///
    /// This has no effect unless `RegretKit.xcframework` is linked; without it
    /// the native bridge compiles to nothing and the fixture is used anyway.
    static let useNativeCore = false
}

@MainActor
@Observable
final class TableViewModel {

    private(set) var state = GameState()
    private(set) var legal: LegalActions?
    /// True while the core is working through steps nobody needs to answer.
    private(set) var isBusy = false
    private(set) var winningCards: Set<Card> = []

    /// True when the app is running the scripted fixture rather than the core.
    let isFixture: Bool

    private let engine: PokerEngine
    private var ticker: Task<Void, Never>?

    /// How long each automatic step is held on screen.
    private let stepInterval = Duration.milliseconds(700)
    /// A longer beat before the pot is pushed, so a showdown can be read.
    private let showdownInterval = Duration.milliseconds(1400)

    init(config: GameConfig) {
        let (engine, isFixture) = Self.makeEngine(config: config)
        self.engine = engine
        self.isFixture = isFixture

        engine.startHand()
        sync()
        advance()
    }

    // MARK: Intents

    func submit(_ action: PlayerAction) {
        guard engine.apply(action) else { return }
        withAnimation(.spring(duration: 0.35)) { sync() }
        advance()
    }

    func dealNextHand() {
        engine.startHand()
        withAnimation(.spring(duration: 0.35)) { sync() }
        advance()
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
    }

    // MARK: Stepping

    /// Runs the core forward until it needs a human answer or the hand ends.
    private func advance() {
        ticker?.cancel()
        ticker = Task {
            isBusy = true
            defer { isBusy = false }

            while !Task.isCancelled {
                let pause = state.street == .showdown
                    ? showdownInterval
                    : stepInterval
                try? await Task.sleep(for: pause)
                guard !Task.isCancelled, engine.step() else { break }
                withAnimation(.spring(duration: 0.4)) { sync() }
            }
        }
    }

    private func sync() {
        state = engine.state
        legal = engine.legalActions
        winningCards = engine.winningCards
    }

    // MARK: Engine selection

    private static func makeEngine(
        config: GameConfig
    ) -> (engine: PokerEngine, isFixture: Bool) {
        #if canImport(RegretKit)
        if EngineSelection.useNativeCore,
           let native = RegretKitEngine(config: config) {
            return (native, false)
        }
        #endif
        return (ScriptedEngine(config: config), true)
    }
}

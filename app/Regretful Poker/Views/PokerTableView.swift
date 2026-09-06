//
//  PokerTableView.swift
//  Regretful Poker
//
//  Composes the whole table: felt, seats around the oval, the board in the
//  middle, and the action bar underneath.
//

import SwiftUI

struct PokerTableView: View {
    var model: TableViewModel
    var onExit: () -> Void

    var body: some View {
        ZStack {
            Theme.roomGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                TableStatusBar(state: model.state, onExit: onExit)

                GeometryReader { geo in
                    table(in: geo.size)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 40)

                ActionBarView(
                    state: model.state,
                    legal: model.legal,
                    isBusy: model.isBusy,
                    onAction: model.submit,
                    onDeal: model.dealNextHand)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 620)
        #endif
    }

    // MARK: Table

    private func table(in size: CGSize) -> some View {
        let metrics = TableMetrics(size: size)
        let layout = SeatLayout(
            playerCount: max(model.state.players.count, 1),
            heroSeat: model.state.human?.seat ?? 0)

        return ZStack {
            TableFeltView()
                .padding(.horizontal, metrics.feltInsetX)
                .padding(.vertical, metrics.feltInsetY)

            DeckView(cardWidth: metrics.deckCardWidth,
                     isVisible: model.state.street != .complete)
                .position(x: size.width * 0.5 - metrics.boardWidth * 0.5
                          - metrics.deckCardWidth * 1.1,
                          y: size.height * 0.5 + metrics.deckCardWidth * 0.4)
                // Hidden on narrow layouts, where it would crowd the board.
                .opacity(size.width > 560 ? 1 : 0)

            BoardView(state: model.state,
                      cardWidth: metrics.boardCardWidth,
                      highlighted: model.winningCards)
                .position(x: size.width * 0.5, y: size.height * 0.5)

            ForEach(model.state.players) { player in
                betPile(for: player, layout: layout, size: size,
                        metrics: metrics)
            }

            ForEach(model.state.players) { player in
                seat(for: player, layout: layout, size: size, metrics: metrics)
            }
        }
        .animation(.spring(duration: 0.4), value: model.state.street)
    }

    private func seat(for player: PlayerView, layout: SeatLayout,
                      size: CGSize, metrics: TableMetrics) -> some View {
        let isHero = layout.isHero(player.seat)
        let point = layout.point(
            for: player.seat, in: size,
            radiusX: metrics.seatRadiusX, radiusY: metrics.seatRadiusY)

        return SeatView(
            player: player,
            isActing: model.state.actingSeat == player.seat,
            isDealer: model.state.buttonSeat == player.seat,
            blind: blindMarker(for: player.seat),
            isWinner: player.won > 0,
            scale: isHero ? metrics.heroScale : metrics.seatScale)
            .position(point)
    }

    private func betPile(for player: PlayerView, layout: SeatLayout,
                         size: CGSize, metrics: TableMetrics) -> some View {
        BetPileView(amount: player.committed, diameter: metrics.chipDiameter)
            .position(betPilePoint(for: player.seat, layout: layout,
                                   size: size, metrics: metrics))
            .animation(.spring(duration: 0.35), value: player.committed)
    }

    /// Where a seat's committed chips sit: between the seat and the pot.
    ///
    /// The hero's pod is drawn much larger than the rest, so sharing one
    /// ellipse inset would tuck its chips underneath its own cards. Its chips
    /// are instead placed a fixed gap above the pod it belongs to.
    private func betPilePoint(for seat: Int, layout: SeatLayout,
                              size: CGSize, metrics: TableMetrics) -> CGPoint {
        guard layout.isHero(seat) else {
            return layout.point(
                for: seat, in: size,
                radiusX: metrics.seatRadiusX * metrics.betInset,
                radiusY: metrics.seatRadiusY * metrics.betInset)
        }

        let pod = layout.point(for: seat, in: size,
                               radiusX: metrics.seatRadiusX,
                               radiusY: metrics.seatRadiusY)
        return CGPoint(x: pod.x,
                       y: pod.y - metrics.heroSeatHeight * 0.5
                          - metrics.chipDiameter * 1.4)
    }

    private func blindMarker(for seat: Int) -> SeatView.BlindMarker? {
        if seat == model.state.smallBlindSeat { return .small }
        if seat == model.state.bigBlindSeat { return .big }
        return nil
    }
}

// MARK: - Metrics

/// Sizes everything on the table off the space actually available, so the
/// same layout works on an iPhone and a full-screen Mac window.
private struct TableMetrics {
    let size: CGSize

    private var minimum: CGFloat { min(size.width, size.height) }

    /// Leaves room around the oval for the seat pods to sit on the rail.
    var feltInsetX: CGFloat { size.width * 0.14 }
    var feltInsetY: CGFloat { size.height * 0.13 }

    var seatRadiusX: Double { 0.40 }
    var seatRadiusY: Double { 0.41 }
    /// How far in from the seats the bet chips sit.
    var betInset: Double { 0.66 }

    var seatScale: CGFloat { clamp(minimum / 400, 0.72, 1.1) }
    var heroScale: CGFloat { seatScale * 1.45 }

    /// Height of the hero's cards-plus-pod stack, used to keep its bet chips
    /// clear of it.
    var heroSeatHeight: CGFloat { 30 * heroScale / 0.714 + 46 * heroScale }

    var boardCardWidth: CGFloat { clamp(size.width * 0.072, 30, 52) }
    var boardWidth: CGFloat { boardCardWidth * 5.65 }
    var deckCardWidth: CGFloat { boardCardWidth * 0.62 }
    var chipDiameter: CGFloat { clamp(minimum / 28, 12, 18) }

    private func clamp(_ value: CGFloat, _ low: CGFloat,
                       _ high: CGFloat) -> CGFloat {
        min(max(value, low), high)
    }
}

// MARK: - Status bar

private struct TableStatusBar: View {
    var state: GameState
    var onExit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onExit) {
                Label("Leave", systemImage: "chevron.left")
                    .font(Theme.display(13, weight: .medium))
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.6))

            Spacer()

            statistic("HAND", "#\(state.handNumber)")
            statistic("BLINDS",
                      "\(Theme.chips(state.smallBlind))/\(Theme.chips(state.bigBlind))")
            statistic("SEATS", "\(state.players.count)")

            Spacer()

            // Balances the leading button so the statistics stay centred.
            Label("Leave", systemImage: "chevron.left")
                .font(Theme.display(13, weight: .medium))
                .opacity(0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func statistic(_ title: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(Theme.display(8, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.35))
            Text(value)
                .font(Theme.numeric(13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(minWidth: 62)
    }
}

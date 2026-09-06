//
//  SeatView.swift
//  Regretful Poker
//
//  One seat at the table: name, stack, hole cards, dealer button, and the
//  badge showing what the seat last did.
//

import SwiftUI

struct SeatView: View {
    var player: PlayerView
    /// True while this seat is on the clock.
    var isActing: Bool
    /// True when the seat has the dealer button.
    var isDealer: Bool
    /// Blind marker to show, if any.
    var blind: BlindMarker?
    /// True once the hand is over and this seat took part of the pot.
    var isWinner: Bool
    /// Scales the whole pod. The human's seat is drawn larger.
    var scale: CGFloat = 1

    enum BlindMarker: String {
        case small = "SB"
        case big = "BB"
    }

    private var isFolded: Bool { player.status == .folded }
    private var isBusted: Bool { player.status == .busted }
    private var cardWidth: CGFloat { 30 * scale }

    var body: some View {
        VStack(spacing: 4 * scale) {
            holeCards
            pod
        }
        .opacity(isBusted ? 0.35 : 1)
        .overlay(alignment: .topTrailing) { actionBadge }
        .overlay(alignment: .bottomLeading) { dealerButton }
        .animation(.spring(duration: 0.3), value: player.lastAction)
        .animation(.spring(duration: 0.3), value: isActing)
    }

    // MARK: Hole cards

    private var holeCards: some View {
        HStack(spacing: -cardWidth * 0.32) {
            ForEach(Array(player.hole.enumerated()), id: \.offset) { index, card in
                let facedown = card == nil && player.status != .busted
                if card != nil || facedown {
                    CardView(card: card, width: cardWidth, isDimmed: isFolded)
                        .rotationEffect(.degrees(index == 0 ? -5 : 5))
                        .zIndex(Double(index))
                }
            }
        }
        .frame(height: cardWidth / (5.0 / 7.0))
        .opacity(isBusted ? 0 : 1)
    }

    // MARK: Name plate

    private var pod: some View {
        VStack(spacing: 1) {
            Text(player.name)
                .font(Theme.display(11 * scale, weight: .semibold))
                .foregroundStyle(.white.opacity(isFolded ? 0.45 : 0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(stackLabel)
                .font(Theme.numeric(13 * scale, weight: .bold))
                .foregroundStyle(stackColor)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12 * scale)
        .padding(.vertical, 5 * scale)
        .frame(minWidth: 84 * scale)
        .background {
            RoundedRectangle(cornerRadius: 10 * scale)
                .fill(isActing ? Theme.podRaised : Theme.pod)
                .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10 * scale)
                .strokeBorder(borderColor, lineWidth: isActing || isWinner ? 2 : 1)
        }
        .overlay(alignment: .bottom) { blindChip }
        .shadow(color: haloColor, radius: isActing || isWinner ? 12 : 0)
    }

    private var stackLabel: String {
        if isBusted { return "Busted" }
        if player.status == .allIn { return "All In" }
        return Theme.chips(player.stack)
    }

    private var stackColor: Color {
        if isBusted { return .white.opacity(0.4) }
        if isWinner { return Theme.winGreen }
        if player.status == .allIn { return Theme.raiseAmber }
        return Theme.gold
    }

    private var borderColor: Color {
        if isWinner { return Theme.winGreen }
        if isActing { return Theme.gold }
        return .white.opacity(0.08)
    }

    private var haloColor: Color {
        if isWinner { return Theme.winGreen.opacity(0.55) }
        if isActing { return Theme.gold.opacity(0.45) }
        return .clear
    }

    // MARK: Adornments

    @ViewBuilder
    private var blindChip: some View {
        if let blind, !isBusted {
            Text(blind.rawValue)
                .font(Theme.display(8 * scale, weight: .heavy))
                .foregroundStyle(.black.opacity(0.8))
                .padding(.horizontal, 5 * scale)
                .padding(.vertical, 1.5 * scale)
                .background(Capsule().fill(Theme.chrome))
                .offset(y: 7 * scale)
        }
    }

    @ViewBuilder
    private var dealerButton: some View {
        if isDealer && !isBusted {
            Text("D")
                .font(Theme.display(10 * scale, weight: .heavy))
                .foregroundStyle(.black.opacity(0.85))
                .frame(width: 19 * scale, height: 19 * scale)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(white: 0.78)],
                                startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .offset(x: -10 * scale, y: 4 * scale)
        }
    }

    @ViewBuilder
    private var actionBadge: some View {
        if player.lastAction != .none, !isBusted {
            Text(player.lastAction.label.uppercased())
                .font(Theme.display(8.5 * scale, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 6 * scale)
                .padding(.vertical, 2 * scale)
                .background(
                    Capsule().fill(player.lastAction.badgeColor.opacity(0.92)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                .offset(x: 12 * scale, y: -4 * scale)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }
}

#Preview("Seats") {
    let acting = PlayerView(
        seat: 1, name: "Nash", stack: 4820, committed: 120,
        hole: [nil, nil], status: .active, isHuman: false,
        lastAction: .raise, handCategory: .none, won: 0)
    let folded = PlayerView(
        seat: 2, name: "Kuhn", stack: 1200, committed: 0,
        hole: [nil, nil], status: .folded, isHuman: false,
        lastAction: .fold, handCategory: .none, won: 0)
    let hero = PlayerView(
        seat: 0, name: "You", stack: 9250, committed: 240,
        hole: [Card(.ace, .spade), Card(.king, .spade)], status: .active,
        isHuman: true, lastAction: .call, handCategory: .none, won: 640)

    return HStack(spacing: 40) {
        SeatView(player: acting, isActing: true, isDealer: false,
                 blind: .big, isWinner: false)
        SeatView(player: folded, isActing: false, isDealer: true,
                 blind: nil, isWinner: false)
        SeatView(player: hero, isActing: false, isDealer: false,
                 blind: nil, isWinner: true, scale: 1.35)
    }
    .padding(60)
    .background(Theme.feltGradient)
}

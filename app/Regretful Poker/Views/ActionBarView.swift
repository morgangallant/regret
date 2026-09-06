//
//  ActionBarView.swift
//  Regretful Poker
//
//  The controls along the bottom of the table. Every button is enabled purely
//  from the `LegalActions` the core handed back, and the sizing slider is
//  clamped to the bounds it reported, so the UI can't submit an illegal
//  action even if it gets out of sync.
//

import SwiftUI

struct ActionBarView: View {
    var state: GameState
    var legal: LegalActions?
    /// True while the core is working through bot turns and street deals.
    var isBusy: Bool
    var onAction: (PlayerAction) -> Void
    var onDeal: () -> Void

    /// The raise-to total currently selected on the slider.
    @State private var raiseTo: UInt64 = 0

    private var isHeroTurn: Bool {
        guard let legal, let human = state.human else { return false }
        return legal.seat == human.seat
    }

    var body: some View {
        VStack(spacing: 12) {
            if isHeroTurn, let legal {
                if legal.canSize { sizingRow(legal) }
                actionRow(legal)
            } else {
                statusRow
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: isHeroTurn ? 620 : 320)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1))
        }
        .animation(.spring(duration: 0.3), value: isHeroTurn)
        .onChange(of: legal) { _, new in
            // Start every decision at the minimum legal raise.
            raiseTo = new?.minRaiseTo ?? 0
        }
        .onAppear { raiseTo = legal?.minRaiseTo ?? 0 }
    }

    // MARK: Sizing

    private func sizingRow(_ legal: LegalActions) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(legal.canBet ? "Bet" : "Raise to")
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(Theme.chips(clampedRaise(legal)))
                    .font(Theme.numeric(19, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(clampedRaise(legal)) },
                    set: { raiseTo = UInt64($0.rounded()) }),
                in: Double(legal.minRaiseTo)...Double(legal.maxRaiseTo),
                step: 1)
            .tint(Theme.gold)

            HStack(spacing: 6) {
                ForEach(quickSizes(legal), id: \.label) { quick in
                    Button(quick.label) { raiseTo = quick.amount }
                        .buttonStyle(QuickSizeButtonStyle(
                            isSelected: clampedRaise(legal) == quick.amount))
                }
            }
        }
    }

    /// Preset sizings, expressed as fractions of the pot and clamped into the
    /// legal range. These are a convenience, not a rule — the core still
    /// validates whatever is submitted.
    private func quickSizes(_ legal: LegalActions) -> [(label: String, amount: UInt64)] {
        func clamp(_ value: UInt64) -> UInt64 {
            min(max(value, legal.minRaiseTo), legal.maxRaiseTo)
        }
        let pot = Double(state.pot)
        let base = Double(state.currentBet)
        var sizes: [(String, UInt64)] = [("Min", legal.minRaiseTo)]
        for (label, fraction) in [("½ Pot", 0.5), ("¾ Pot", 0.75), ("Pot", 1.0)] {
            let amount = clamp(UInt64(max(0, base + pot * fraction)))
            if amount > legal.minRaiseTo && amount < legal.maxRaiseTo {
                sizes.append((label, amount))
            }
        }
        sizes.append(("All In", legal.maxRaiseTo))
        return sizes.map { (label: $0.0, amount: $0.1) }
    }

    private func clampedRaise(_ legal: LegalActions) -> UInt64 {
        min(max(raiseTo, legal.minRaiseTo), legal.maxRaiseTo)
    }

    // MARK: Actions

    private func actionRow(_ legal: LegalActions) -> some View {
        HStack(spacing: 10) {
            if legal.canFold {
                Button("Fold") { onAction(.fold) }
                    .buttonStyle(ActionButtonStyle(tint: Theme.foldRed))
            }

            if legal.canCheck {
                Button("Check") { onAction(.check) }
                    .buttonStyle(ActionButtonStyle(tint: Theme.callBlue))
            } else if legal.canCall {
                Button("Call \(Theme.chips(legal.callAmount))") { onAction(.call) }
                    .buttonStyle(ActionButtonStyle(tint: Theme.callBlue))
            }

            if legal.canAggress {
                let amount = clampedRaise(legal)
                let isShove = amount == legal.maxRaiseTo && legal.maxRaiseTo > 0
                let verb = isShove ? "All In" : (legal.canBet ? "Bet" : "Raise")
                let title = isShove ? verb : "\(verb) \(Theme.chips(amount))"
                Button(title) {
                    onAction(legal.canBet ? .bet(to: amount) : .raise(to: amount))
                }
                .buttonStyle(ActionButtonStyle(tint: Theme.raiseAmber))
            }
        }
    }

    // MARK: Idle state

    @ViewBuilder
    private var statusRow: some View {
        if state.street == .complete {
            Button("Deal Next Hand") { onDeal() }
                .buttonStyle(ActionButtonStyle(tint: Theme.winGreen))
        } else if let seat = state.actingSeat,
                  let player = state.player(at: seat) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("\(player.name) is thinking\u{2026}")
                    .font(Theme.display(14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .frame(height: 44)
        } else {
            Text(isBusy ? "Dealing\u{2026}" : state.street.name)
                .font(Theme.display(14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(height: 44)
        }
    }
}

// MARK: - Button styles

private struct ActionButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(15, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.72)],
                            startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.35), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

private struct QuickSizeButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(11, weight: .semibold))
            .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Theme.gold : Color.white.opacity(0.08))
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

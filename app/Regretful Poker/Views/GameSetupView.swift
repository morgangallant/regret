//
//  GameSetupView.swift
//  Regretful Poker
//
//  Table configuration, shown before sitting down.
//

import SwiftUI

struct GameSetupView: View {
    @Binding var config: GameConfig
    var isFixtureBuild: Bool
    var onStart: () -> Void

    private let stackOptions: [UInt64] = [100, 200, 500, 1000, 2500]
    private let blindOptions: [(small: UInt64, big: UInt64)] = [
        (1, 2), (2, 5), (5, 10), (25, 50), (100, 200),
    ]

    var body: some View {
        ZStack {
            Theme.roomGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    header
                    panel
                    if isFixtureBuild { fixtureNotice }
                    startButton
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("REGRETFUL POKER")
                .font(Theme.display(26, weight: .heavy))
                .tracking(3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.gold, Theme.goldDim],
                        startPoint: .top, endPoint: .bottom))

            Text("No-limit hold\u{2019}em against the solver")
                .font(Theme.display(13, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.bottom, 6)
    }

    // MARK: Settings

    private var panel: some View {
        VStack(spacing: 0) {
            playerCountRow
            divider
            stackRow
            divider
            blindsRow
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 1)
            .padding(.vertical, 16)
    }

    private var playerCountRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingLabel("Players at the table",
                         detail: "\(config.playerCount)")
            HStack(spacing: 8) {
                ForEach(GameConfig.seatRange, id: \.self) { count in
                    Button("\(count)") {
                        config.playerCount = count
                        config.humanSeat = 0
                    }
                    .buttonStyle(ChoiceButtonStyle(
                        isSelected: config.playerCount == count))
                }
            }
            Text("You take one seat; the rest are played by the core.")
                .font(Theme.display(11))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var stackRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingLabel("Starting stack",
                         detail: Theme.chips(config.startingStack))
            HStack(spacing: 8) {
                ForEach(stackOptions, id: \.self) { amount in
                    Button(Theme.chips(amount)) { config.startingStack = amount }
                        .buttonStyle(ChoiceButtonStyle(
                            isSelected: config.startingStack == amount))
                }
            }
        }
    }

    private var blindsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingLabel(
                "Blinds",
                detail: "\(Theme.chips(config.smallBlind))/\(Theme.chips(config.bigBlind))")
            HStack(spacing: 8) {
                ForEach(blindOptions, id: \.big) { option in
                    Button("\(Theme.chips(option.small))/\(Theme.chips(option.big))") {
                        config.smallBlind = option.small
                        config.bigBlind = option.big
                    }
                    .buttonStyle(ChoiceButtonStyle(
                        isSelected: config.bigBlind == option.big))
                }
            }
            Text("\(config.startingStack / max(config.bigBlind, 1)) big blinds deep.")
                .font(Theme.display(11))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func settingLabel(_ title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.display(14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(detail)
                .font(Theme.numeric(14, weight: .bold))
                .foregroundStyle(Theme.gold)
        }
    }

    // MARK: Footer

    private var fixtureNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hammer.fill")
                .foregroundStyle(Theme.raiseAmber)
            VStack(alignment: .leading, spacing: 3) {
                Text("Running the UI fixture")
                    .font(Theme.display(12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("The Zig core isn\u{2019}t linked yet, so hands follow a "
                     + "scripted demo. Settings still shape the table.")
                    .font(Theme.display(11))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.raiseAmber.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.raiseAmber.opacity(0.25),
                                      lineWidth: 1))
        }
    }

    private var startButton: some View {
        Button("Take a Seat", action: onStart)
            .buttonStyle(PrimaryButtonStyle())
    }
}

// MARK: - Button styles

private struct ChoiceButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(12, weight: .semibold))
            .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background {
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? Theme.gold : Color.white.opacity(0.07))
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(17, weight: .bold))
            .foregroundStyle(.black.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Theme.gold, Theme.goldDim],
                            startPoint: .top, endPoint: .bottom))
            }
            .shadow(color: Theme.gold.opacity(0.3), radius: 14, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview("Setup") {
    GameSetupView(config: .constant(GameConfig()), isFixtureBuild: true) {}
}

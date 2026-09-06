//
//  TableFeltView.swift
//  Regretful Poker
//
//  The physical table: rail, felt, and the hairline that marks the betting
//  line. Purely decorative — it takes whatever space it is given.
//

import SwiftUI

struct TableFeltView: View {
    var body: some View {
        GeometryReader { geo in
            let inset = min(geo.size.width, geo.size.height) * 0.045

            ZStack {
                // Padded rail.
                Capsule()
                    .fill(Theme.railGradient)
                    .overlay(
                        Capsule()
                            .strokeBorder(Theme.gold.opacity(0.22),
                                          lineWidth: 1))
                    .shadow(color: .black.opacity(0.65), radius: 28, y: 14)

                // Playing surface.
                Capsule()
                    .fill(Theme.feltGradient)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.black.opacity(0.4),
                                          lineWidth: 1.5))
                    .padding(inset)

                // Betting line.
                Capsule()
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    .padding(inset * 3.4)

                // Soft vignette so the middle reads brighter than the edges.
                Capsule()
                    .fill(
                        RadialGradient(
                            colors: [.clear, .black.opacity(0.32)],
                            center: .center,
                            startRadius: min(geo.size.width, geo.size.height) * 0.2,
                            endRadius: max(geo.size.width, geo.size.height) * 0.62))
                    .padding(inset)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Felt") {
    TableFeltView()
        .padding(40)
        .frame(width: 700, height: 420)
        .background(Theme.roomGradient)
}

//
//  ContentView.swift
//  Regretful Poker
//
//  Routes between table setup and the table itself.
//

import SwiftUI

struct ContentView: View {
    @State private var config = GameConfig()
    @State private var model: TableViewModel?

    var body: some View {
        Group {
            if let model {
                PokerTableView(model: model) {
                    model.stop()
                    self.model = nil
                }
                .transition(.opacity)
            } else {
                GameSetupView(
                    config: $config,
                    isFixtureBuild: !EngineSelection.useNativeCore
                ) {
                    model = TableViewModel(config: config)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model == nil)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}

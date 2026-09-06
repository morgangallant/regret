//
//  Regretful_PokerApp.swift
//  Regretful Poker
//
//  Created by Morgan Gallant on 9/5/26.
//

import SwiftUI

@main
struct Regretful_PokerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 760)
        .windowResizability(.contentMinSize)
        #endif
    }
}

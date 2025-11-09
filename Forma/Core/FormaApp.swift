//
//  FormaApp.swift
//  Forma
//
//  Entry point for the app.
//
//  Created by Forma.
//

import SwiftUI

@main
struct FormaApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

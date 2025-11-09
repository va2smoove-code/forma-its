//
//  FocusView.swift
//  Forma
//
//  Purpose:
//  - Basic skeleton; full features to be added later.
//
//  Created by Forma.
//

import SwiftUI

struct FocusView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Focus Mode")
                    .font(.title.bold())
                Text("Pomodoro + app blocking + progress garden (coming soon).")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .navigationTitle("Focus")
        }
    }
}

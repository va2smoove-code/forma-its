//
//  TodayFiltersRow.swift
//  Forma
//
//  Purpose:
//  - Horizontal chips showing the active filters on Today view.
//  - Lets the user clear importance and remove tags quickly.
//
//  Created by Forma.
//

import SwiftUI

struct ActiveFiltersRow: View {
    // MARK: Inputs
    let importance: TodayView.Task.Importance?
    let tags: [String]
    let onClearImportance: () -> Void
    let onRemoveTag: (String) -> Void
    let onClearAll: () -> Void

    // MARK: Body
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let imp = importance {
                    Chip(text: imp.rawValue, roleColor: imp == .high ? .red : .orange) {
                        onClearImportance()
                    }
                }

                ForEach(tags, id: \.self) { tag in
                    Chip(text: tag, roleColor: .secondary) {
                        onRemoveTag(tag)
                    }
                }

                if importance != nil || !tags.isEmpty {
                    Button(role: .destructive) {
                        onClearAll()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Active filters")
    }
}

// MARK: - Small pill
private struct Chip: View {
    let text: String
    var roleColor: Color = .secondary
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption2)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(text)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.12))
        .foregroundStyle(roleColor)
        .clipShape(Capsule())
    }
}

//
//  ShareSheet.swift
//  FitNotes iOS
//
//  UIKit share sheet wrapper for sharing workout text and images
//  (product_roadmap.md 1.26, 3.10).
//  Wraps UIActivityViewController for SwiftUI presentation.
//

import SwiftUI

struct ShareSheet: View {
    var text: String = ""
    var image: UIImage? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ShareSheetRepresentable(items: shareItems)
            .ignoresSafeArea()
    }

    private var shareItems: [Any] {
        var items: [Any] = []
        if let image { items.append(image) }
        if !text.isEmpty { items.append(text) }
        return items
    }
}

private struct ShareSheetRepresentable: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

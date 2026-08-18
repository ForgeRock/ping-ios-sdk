//
//  ImageView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingDavinci

/// A display-only view that renders the image provided by an `ImageCollector`.
///
/// The collector carries the URL of an image to display, along with an optional
/// hyperlink. This view converts the URL string to a `URL` locally and displays
/// the image using `AsyncImage`. If the URL is absent or malformed a placeholder
/// icon is shown instead. When `hyperlinkUrl` is non-nil and non-empty, a tappable
/// `Link` is shown below the image.
struct ImageView: View {
    let collector: ImageCollector

    @ViewBuilder
    private var imagePlaceholder: some View {
        Image(systemName: "photo")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .foregroundColor(.secondary)
        Text("Image unavailable")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    var body: some View {
        VStack(spacing: 12) {
            if !collector.imageUrl.isEmpty, let imageURL = URL(string: collector.imageUrl) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 240, maxHeight: 240)
                            .accessibilityLabel(collector.description.isEmpty ? "Image" : collector.description)
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(width: 120, height: 120)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                imagePlaceholder
            }

            if !collector.description.isEmpty {
                Text(collector.description)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let hyperlinkUrl = collector.hyperlinkUrl,
               !hyperlinkUrl.isEmpty,
               let linkURL = URL(string: hyperlinkUrl),
               let scheme = linkURL.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                Link(collector.description.isEmpty ? "Open link" : collector.description, destination: linkURL)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
    }
}

//
//  ToastView.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import SwiftUI

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack {
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                Text(toast.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                if let message = toast.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: SkyAwareRadius.chip, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1),
                        radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SkyAwareRadius.chip, style: .continuous)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}


struct ToastContainer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let toasts: [ToastMessage]
    
    var body: some View {
        VStack {
            if toasts.contains(where: { $0.position == .top }) {
                VStack(spacing: 8) {
                    ForEach(toasts.filter { $0.position == .top }) { toast in
                        ToastView(toast: toast)
                    }
                }
                .transition(SkyAwareMotion.toastTransition(edge: .top, reduceMotion: reduceMotion))
                
                Spacer()
            } else {
                Spacer()
            }
            
            if toasts.contains(where: { $0.position == .bottom }) {
                Spacer()
                VStack(spacing: 8) {
                    ForEach(toasts.filter { $0.position == .bottom }) { toast in
                        ToastView(toast: toast)
                    }
                }
                .transition(SkyAwareMotion.toastTransition(edge: .bottom, reduceMotion: reduceMotion))
            }
        }
        .animation(SkyAwareMotion.toastPresentation(reduceMotion), value: toasts.count)
    }
}

#Preview {
    ToastContainer(toasts: [
        ToastMessage(id: UUID(), title: "Success", message: "Data loaded successfully", type: .success, duration: 5.0, position: .top),
        ToastMessage(id: UUID(), title: "Error", message: "Data not loaded", type: .error, duration: 5.0, position: .top)
    ])
}

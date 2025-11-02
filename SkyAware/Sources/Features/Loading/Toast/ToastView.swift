//
//  ToastView.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import SwiftUI

struct ToastView: View {
    let toast: ToastMessage
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var offset: CGFloat = -100
    
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
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1),
                        radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .offset(y: offset)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)){
                isVisible = true
                offset = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                
            }
        }
    }
    
    private func dismissToast() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
            offset = toast.position == .top ? -100 : 100
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}


struct ToastContainer: View {
    let toasts: [ToastMessage]
    let onDismiss: (ToastMessage) -> Void
    
    var body: some View {
        VStack{
            if (toasts.contains(where: { $0.position == .top})) {
                VStack(spacing: 8) {
                    ForEach(toasts.filter { $0.position == .top }) { toast in
                        ToastView(toast: toast) {
                            onDismiss(toast)
                        }
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)
                                       ))
                
                Spacer()
            } else {
                Spacer()
            }
            
            if (toasts.contains(where: { $0.position == .top})) {
                Spacer()
                VStack(spacing: 8) {
                    ForEach(toasts.filter { $0.position == .top }) { toast in
                        ToastView(toast: toast) {
                            onDismiss(toast)
                        }
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .bottom).combined(with: .opacity)
                                       ))
            }
        }.animation(.spring(response: 0.5, dampingFraction: 0.8), value: toasts.count)
    }
}

#Preview {
    ToastContainer(toasts: [
        ToastMessage(id: UUID(), title: "Success", message: "Data loaded successfully", type: .success, duration: 5.0, position: .top),
        ToastMessage(id: UUID(), title: "Error", message: "Data not loaded", type: .error, duration: 5.0, position: .top)
    ], onDismiss: {_ in }
    )
    
}

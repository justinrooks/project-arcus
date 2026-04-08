//
//  ToastManager.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation
import SwiftUI

class ToastManager: ObservableObject {
    @MainActor static let shared = ToastManager()
    
    var toasts: [ToastMessage] = []
    
    private init () {}
    
    @MainActor
    private func display(_ toast: ToastMessage) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            toasts.append(toast)
        }
    }
    
    @MainActor
    private func createAndDisplay(type: ToastType, title: String, message: String? = nil, duration: Double = 3.0, position: ToastPosition = .top) {
        let toast = ToastMessage(id: UUID(), title: title, message: message, type: type, duration: duration, position: position)
        display(toast)
    }
    
    @MainActor
    func showSuccess(title: String, message: String? = nil, duration: Double = 0.3, position: ToastPosition = .top) {
        createAndDisplay(type: .success, title: title, message: message, duration: duration, position: position)
    }
    
    @MainActor
    func showError(title: String, message: String? = nil, duration: Double = 0.3, position: ToastPosition = .top) {
        createAndDisplay(type: .error, title: title, message: message, duration: duration, position: position)
    }
    
    @MainActor
    func showWarning(title: String, message: String? = nil, duration: Double = 0.3, position: ToastPosition = .top) {
        createAndDisplay(type: .warning, title: title, message: message, duration: duration, position: position)
    }
    
    @MainActor
    func showInfo(title: String, message: String? = nil, duration: Double = 0.3, position: ToastPosition = .top) {
        createAndDisplay(type: .info, title: title, message: message, duration: duration, position: position)
    }
    
    @MainActor
    func dismissToast(_ toast: ToastMessage) {
        withAnimation(.easeInOut(duration: 0.3)) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
    
    @MainActor
    func dismissAllToasts() {
        withAnimation(.easeInOut(duration: 0.3)) {
            toasts.removeAll()
        }
    }
}

struct ToastModifier: ViewModifier {
    @StateObject private var toastManager = ToastManager.shared
    
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            ToastContainer(toasts: toastManager.toasts, onDismiss: {toast in
                toastManager.dismissToast(toast)
            })
        }
    }
}

extension View {
    func toasting() -> some View {
        modifier(ToastModifier())
    }
}

//
//  ToastMessage.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation
import SwiftUI

enum ToastType: CaseIterable {
    case success
    case error
    case warning
    case info
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .yellow
        case .info:
            return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

enum ToastPosition: CaseIterable {
    case top
    case bottom
}

struct ToastMessage: Identifiable {
    var id: UUID = UUID()
    var title: String
    var message: String?
    var type: ToastType
    var duration: Double
    var position: ToastPosition
    
    init(id: UUID, title: String, message: String? = nil, type: ToastType, duration: Double, position: ToastPosition) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.duration = duration
        self.position = position
    }
}

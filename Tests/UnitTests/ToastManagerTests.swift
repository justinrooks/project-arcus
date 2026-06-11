import Foundation
import Testing
@testable import SkyAware

@Suite("Toast manager")
struct ToastManagerTests {
    @MainActor
    @Test("showing and dismissing a toast mutates the published toast list")
    func showingAndDismissingAToastMutatesThePublishedToastList() {
        let manager = ToastManager.shared
        let originalToasts = manager.toasts
        defer {
            manager.toasts = originalToasts
        }

        manager.toasts = []
        let toast = ToastMessage(
            id: UUID(),
            title: "Test",
            message: "Toast state should update",
            type: .info,
            duration: 0.3,
            position: .top
        )

        manager.showInfo(title: toast.title, message: toast.message, duration: toast.duration, position: toast.position)
        #expect(manager.toasts.count == 1)
        #expect(manager.toasts.first?.title == toast.title)

        manager.dismissToast(manager.toasts[0])
        #expect(manager.toasts.isEmpty)
    }
}

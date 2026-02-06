import Testing
@testable import SkyAware

@Suite("HomeView Loading Overlay State")
struct HomeViewLoadingOverlayStateTests {
    @Test("begin shows overlay and message")
    func begin_showsOverlayAndMessage() {
        var state = HomeView.LoadingOverlayState()

        state.begin(message: "Refreshing alerts...")

        #expect(state.activeRefreshes == 1)
        #expect(state.isVisible)
        #expect(state.displayMessage == "Refreshing alerts...")
    }

    @Test("nested begin/end keeps overlay until all refreshes complete")
    func nestedBeginEnd_keepsOverlayUntilZero() {
        var state = HomeView.LoadingOverlayState()

        state.begin(message: "Refreshing data...")
        state.begin(message: "Syncing outlooks...")
        state.end()

        #expect(state.activeRefreshes == 1)
        #expect(state.isVisible)
        #expect(state.displayMessage == "Syncing outlooks...")

        state.end()

        #expect(state.activeRefreshes == 0)
        #expect(state.isVisible == false)
        #expect(state.message == nil)
        #expect(state.displayMessage == "Refreshing data...")
    }

    @Test("setMessage updates display text while active")
    func setMessage_updatesDisplayMessage() {
        var state = HomeView.LoadingOverlayState()
        state.begin(message: "Refreshing data...")

        state.setMessage("Updating local risks...")

        #expect(state.displayMessage == "Updating local risks...")
    }

    @Test("end clamps at zero and keeps state hidden")
    func end_clampsAtZero() {
        var state = HomeView.LoadingOverlayState()

        state.end()

        #expect(state.activeRefreshes == 0)
        #expect(state.isVisible == false)
        #expect(state.message == nil)
    }
}

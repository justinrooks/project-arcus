import Foundation
import Testing
@testable import SkyAware

@Suite("Alert detail reconciliation")
@MainActor
struct AlertDetailReconciliationTests {
    private let initial = makeAlert(id: "alert-1", revision: 100, headline: "Initial headline")

    @Test("detail renders its seed before any accepted update")
    func seed_rendersImmediately() {
        let model = AlertDetailReconciliationModel(seed: initial)

        #expect(model.alert == initial)
    }

    @Test("newer accepted revision replaces the matching detail")
    func acceptedRevision_replacesMatchingDetail() async {
        let revised = makeAlert(id: "alert-1", revision: 200, headline: "Revised headline")
        let model = AlertDetailReconciliationModel(seed: initial)
        let (updates, continuation) = AsyncStream<FeedStateGenerationUpdate>.makeStream()
        let recorder = AlertDetailReloadRecorder(result: revised)
        let observer = Task { @MainActor in
            await model.observe(acceptedUpdates: updates) { id in
                await recorder.reload(id: id)
            }
        }

        await Task.yield()
        continuation.yield(.init(feedID: "arcus.alerts", generation: 2))
        await waitUntil { model.alert == revised }
        observer.cancel()

        #expect(model.alert == revised)
        #expect(await recorder.ids == [initial.id])
    }

    @Test("older accepted revisions leave matching detail unchanged")
    func olderAcceptedRevision_doesNotReplaceMatchingDetail() async {
        let model = AlertDetailReconciliationModel(seed: initial)
        let (updates, continuation) = AsyncStream<FeedStateGenerationUpdate>.makeStream()
        let recorder = AlertDetailReloadRecorder(result: makeAlert(id: "alert-1", revision: 50, headline: "Older headline"))
        let observer = Task { @MainActor in
            await model.observe(acceptedUpdates: updates) { id in
                await recorder.reload(id: id)
            }
        }

        await Task.yield()
        continuation.yield(.init(feedID: "arcus.alerts", generation: 3))
        await waitUntil { await recorder.ids.count == 1 }
        observer.cancel()

        #expect(model.alert == initial)
    }

    @Test("initial reconciliation adopts an already accepted newer revision")
    func initialReconciliation_adoptsNewerRevisionWithoutEvent() async {
        let revised = makeAlert(id: "alert-1", revision: 200, headline: "Revised headline")
        let model = AlertDetailReconciliationModel(seed: initial)

        await model.reconcile { _ in revised }

        #expect(model.alert == revised)
    }

    @Test("accepted revisions for another identity leave detail unchanged")
    func acceptedRevision_otherIdentityIsIgnored() async {
        let model = AlertDetailReconciliationModel(seed: initial)
        let (updates, continuation) = AsyncStream<FeedStateGenerationUpdate>.makeStream()
        let recorder = AlertDetailReloadRecorder(result: makeAlert(id: "alert-2", revision: 200, headline: "Other alert"))
        let observer = Task { @MainActor in
            await model.observe(acceptedUpdates: updates) { id in
                await recorder.reload(id: id)
            }
        }

        await Task.yield()
        continuation.yield(.init(feedID: "arcus.alert", generation: 1))
        await waitUntil { await recorder.ids.count == 1 }
        observer.cancel()

        #expect(model.alert == initial)
    }

    @Test("unaccepted and unavailable updates leave detail unchanged")
    func unacceptedOrUnavailableUpdates_areIgnored() async {
        let model = AlertDetailReconciliationModel(seed: initial)
        let (updates, continuation) = AsyncStream<FeedStateGenerationUpdate>.makeStream()
        let recorder = AlertDetailReloadRecorder(result: nil)
        let observer = Task { @MainActor in
            await model.observe(acceptedUpdates: updates) { id in
                await recorder.reload(id: id)
            }
        }

        await Task.yield()
        continuation.yield(.init(feedID: "spc.outlook", generation: 1))
        await Task.yield()
        #expect(await recorder.ids.isEmpty)

        continuation.yield(.init(feedID: "arcus.alerts", generation: 1))
        await waitUntil { await recorder.ids.count == 1 }
        observer.cancel()

        #expect(model.alert == initial)
    }

    @Test("cancelling detail observation prevents later reloads")
    func dismissal_cancelsObservation() async {
        let model = AlertDetailReconciliationModel(seed: initial)
        let (updates, continuation) = AsyncStream<FeedStateGenerationUpdate>.makeStream()
        let recorder = AlertDetailReloadRecorder(result: makeAlert(id: "alert-1", revision: 200, headline: "Revised headline"))
        let observer = Task { @MainActor in
            await model.observe(acceptedUpdates: updates) { id in
                await recorder.reload(id: id)
            }
        }

        await Task.yield()
        observer.cancel()
        continuation.yield(.init(feedID: "arcus.alerts", generation: 1))
        await Task.yield()

        #expect(model.alert == initial)
        #expect(await recorder.ids.isEmpty)
    }

    @Test("cancelling while a reread is in flight retains the visible detail")
    func dismissal_cancelsInFlightReconciliation() async {
        let model = AlertDetailReconciliationModel(seed: initial)
        let reload = SuspendedAlertReload()
        let observer = Task { @MainActor in
            await model.reconcile { _ in
                await reload.value()
            }
        }

        await reload.waitUntilStarted()
        observer.cancel()
        await reload.resume(with: makeAlert(id: "alert-1", revision: 200, headline: "Revised headline"))
        await observer.value

        #expect(model.alert == initial)
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool
    ) async {
        while await condition() == false {
            await Task.yield()
        }
    }
}

private actor AlertDetailReloadRecorder {
    private(set) var ids: [String] = []
    private let result: AlertDTO?

    init(result: AlertDTO?) {
        self.result = result
    }

    func reload(id: String) -> AlertDTO? {
        ids.append(id)
        return result
    }
}

private actor SuspendedAlertReload {
    private var resultContinuation: CheckedContinuation<AlertDTO?, Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    func value() async -> AlertDTO? {
        await withCheckedContinuation { continuation in
            resultContinuation = continuation
            hasStarted = true
            startedContinuation?.resume()
            startedContinuation = nil
        }
    }

    func waitUntilStarted() async {
        if hasStarted { return }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func resume(with result: AlertDTO?) {
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
}

private func makeAlert(id: String, revision: TimeInterval, headline: String) -> AlertDTO {
    let issued = Date(timeIntervalSince1970: revision)
    return AlertDTO(
        id: id,
        messageId: "urn:\(id):\(revision)",
        currentRevisionSent: issued,
        title: "Tornado Warning",
        headline: headline,
        issued: issued,
        expires: issued.addingTimeInterval(3_600),
        ends: issued.addingTimeInterval(3_600),
        messageType: "Update",
        sender: "NWS",
        severity: "Severe",
        urgency: "Immediate",
        certainty: "Observed",
        description: headline,
        instruction: nil,
        response: nil,
        areaSummary: "Test area",
        geometryData: nil,
        tornadoDetection: nil,
        tornadoDamageThreat: nil,
        maxWindGust: nil,
        maxHailSize: nil,
        windThreat: nil,
        hailThreat: nil,
        thunderstormDamageThreat: nil,
        flashFloodDetection: nil,
        flashFloodDamageThreat: nil
    )
}

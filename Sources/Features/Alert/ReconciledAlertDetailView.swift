//
//  ReconciledAlertDetailView.swift
//  SkyAware
//

import Observation
import SwiftUI

@MainActor
@Observable
final class AlertDetailReconciliationModel {
    private(set) var alert: AlertDTO

    init(seed: AlertDTO) {
        self.alert = seed
    }

    func observe(
        acceptedUpdates: AsyncStream<FeedStateGenerationUpdate>,
        reload: @escaping @Sendable (String) async -> AlertDTO?
    ) async {
        for await update in acceptedUpdates {
            guard Task.isCancelled == false else { return }
            guard Self.isRelevantAcceptedUpdate(update) else { continue }
            await reconcile(reload: reload)
        }
    }

    func reconcile(reload: @escaping @Sendable (String) async -> AlertDTO?) async {
        guard Task.isCancelled == false else { return }
        let id = alert.id
        guard let candidate = await reload(id) else { return }
        guard Task.isCancelled == false, Self.shouldReplace(alert, with: candidate) else { return }

        alert = candidate
    }

    static func isRelevantAcceptedUpdate(_ update: FeedStateGenerationUpdate) -> Bool {
        update.feedID == "arcus.alert" || update.feedID == "arcus.alerts"
    }

    static func shouldReplace(_ current: AlertDTO, with candidate: AlertDTO) -> Bool {
        guard current.id == candidate.id else { return false }

        switch (current.currentRevisionSent, candidate.currentRevisionSent) {
        case let (.some(currentRevision), .some(candidateRevision)):
            return candidateRevision > currentRevision
        case (.none, .some):
            return true
        case (.some, .none), (.none, .none):
            return false
        }
    }
}

struct ReconciledAlertDetailView: View {
    @Environment(\.dependencies) private var dependencies

    let layout: DetailLayout
    let isExpanded: Bool

    @State private var model: AlertDetailReconciliationModel

    init(alert: AlertDTO, layout: DetailLayout, isExpanded: Bool = true) {
        self.layout = layout
        self.isExpanded = isExpanded
        _model = State(initialValue: AlertDetailReconciliationModel(seed: alert))
    }

    var body: some View {
        AlertDetailView(alert: model.alert, layout: layout, isExpanded: isExpanded)
            .task {
                guard let observation = dependencies.alertDetailReconciliationObservation else { return }
                let updates = await observation.feedStateStore.acceptedGenerationUpdates()
                let alertRepo = observation.alertRepo
                let reload: @Sendable (String) async -> AlertDTO? = { id in
                    try? await alertRepo.alert(id: id)
                }
                await model.reconcile(reload: reload)
                await model.observe(acceptedUpdates: updates, reload: reload)
            }
    }
}

//
//  SummaryResolving.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import SwiftUI

enum SummarySection: Hashable {
    case conditions
    case stormRisk
    case severeRisk
    case fireRisk
    case atmosphere
    case alerts
    case outlook
}

extension SummarySection {
    static let resolveForwardSections: [SummarySection] = [
        .conditions,
        .stormRisk,
        .severeRisk,
        .fireRisk,
        .atmosphere,
        .alerts,
        .outlook,
    ]
}

enum SummaryProviderTask: Hashable {
    case location
    case weather
    case stormRisk
    case alerts
    case finalizing

    var statusMessage: String {
        switch self {
        case .location:
            "Getting your conditions ready…"
        case .weather:
            "Updating your conditions…"
        case .stormRisk:
            "Getting storm risk…"
        case .alerts:
            "Bringing in local alerts…"
        case .finalizing:
            "Updating your conditions…"
        }
    }
}

struct SummaryResolutionState: Equatable {
    private(set) var activeTasks: [SummaryProviderTask] = []
    private(set) var resolvingSections: Set<SummarySection> = []
    private(set) var lastCompletedTask: SummaryProviderTask?
    private(set) var lastCompletedAt: Date?
    private var taskSections: [SummaryProviderTask: Set<SummarySection>] = [:]

    var isRefreshing: Bool {
        activeTasks.isEmpty == false
    }

    var primaryActiveMessage: String? {
        activeTasks
            .min(by: { $0.priority < $1.priority })?
            .statusMessage
    }

    var activeMessages: [String] {
        activeTasks.map(\.statusMessage)
    }

    var recentCompletedDeadline: Date? {
        guard let lastCompletedAt else { return nil }
        return lastCompletedAt.addingTimeInterval(1.25)
    }

    var recentCompletedMessage: String? {
        guard
            let lastCompletedTask,
            let recentCompletedDeadline,
            Date() <= recentCompletedDeadline
        else {
            return nil
        }

        switch lastCompletedTask {
        case .location, .weather, .finalizing:
            return "Updated conditions"
        case .stormRisk:
            return "Got storm risk"
        case .alerts:
            return "Checked local alerts"
        }
    }

    func isResolving(_ section: SummarySection) -> Bool {
        resolvingSections.contains(section)
    }

    mutating func begin(task: SummaryProviderTask, sections: some Sequence<SummarySection>) {
        if activeTasks.contains(task) == false {
            activeTasks.append(task)
        }

        var trackedSections = taskSections[task, default: []]
        for section in sections {
            resolvingSections.insert(section)
            trackedSections.insert(section)
        }
        taskSections[task] = trackedSections

        if task == .finalizing {
            lastCompletedTask = nil
            lastCompletedAt = nil
        }
    }

    mutating func finish(
        task: SummaryProviderTask,
        resolvedSections: some Sequence<SummarySection>,
        completedAt: Date = .now
    ) {
        var trackedSections = taskSections[task, default: []]
        for section in resolvedSections {
            resolvingSections.remove(section)
            trackedSections.remove(section)
        }

        if trackedSections.isEmpty {
            taskSections.removeValue(forKey: task)
            activeTasks.removeAll { $0 == task }
        } else {
            taskSections[task] = trackedSections
        }

        lastCompletedTask = task
        lastCompletedAt = completedAt
    }

    mutating func reset() {
        activeTasks.removeAll()
        resolvingSections.removeAll()
        lastCompletedTask = nil
        lastCompletedAt = nil
        taskSections.removeAll()
    }

    mutating func finishAll(
        completedTask: SummaryProviderTask = .finalizing,
        completedAt: Date = .now
    ) {
        activeTasks.removeAll()
        resolvingSections.removeAll()
        taskSections.removeAll()
        lastCompletedTask = completedTask
        lastCompletedAt = completedAt
    }
}

private extension SummaryProviderTask {
    var priority: Int {
        switch self {
        case .location:
            0
        case .weather:
            1
        case .stormRisk:
            2
        case .alerts:
            3
        case .finalizing:
            4
        }
    }
}

enum SummaryResolveForwardStyle {
    case subtle
    case blurLift

    var opacity: Double {
        switch self {
        case .subtle:
            SkyAwareMotion.resolvingSubtleOpacity
        case .blurLift:
            SkyAwareMotion.resolvingOpacity
        }
    }

    var blur: CGFloat {
        switch self {
        case .subtle:
            0
        case .blurLift:
            SkyAwareMotion.resolvingBlur
        }
    }
}

private struct SummaryResolvingModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isResolving: Bool
    let style: SummaryResolveForwardStyle

    func body(content: Content) -> some View {
        content
            .blur(radius: isResolving && reduceMotion == false ? style.blur : 0)
            .opacity(isResolving ? style.opacity : 1)
            .animation(SkyAwareMotion.resolve(reduceMotion), value: isResolving)
    }
}

extension View {
    func summaryResolving(
        _ isResolving: Bool,
        style: SummaryResolveForwardStyle = .blurLift
    ) -> some View {
        modifier(SummaryResolvingModifier(isResolving: isResolving, style: style))
    }
}

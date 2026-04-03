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

enum SummaryProviderTask: Hashable {
    case location
    case weather
    case stormRisk
    case alerts
    case finalizing

    var statusMessage: String {
        switch self {
        case .location:
            "Getting your location…"
        case .weather:
            "Updating your conditions…"
        case .stormRisk:
            "Getting storm risk…"
        case .alerts:
            "Bringing in local alerts…"
        case .finalizing:
            "Getting everything ready…"
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

        return lastCompletedTask.statusMessage
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
}

private struct SummaryResolvingModifier: ViewModifier {
    let isResolving: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: isResolving ? 2.5 : 0)
            .opacity(isResolving ? 0.86 : 1)
            .animation(.easeInOut(duration: 0.32), value: isResolving)
    }
}

extension View {
    func summaryResolving(_ isResolving: Bool) -> some View {
        modifier(SummaryResolvingModifier(isResolving: isResolving))
    }
}

//
//  BgHealthDiagnosticsView.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/22/25.
//

import SwiftUI
import SwiftData

// MARK: - Diagnostics

struct BgHealthDiagnosticsView: View {
    // Latest first, capped to 50
    @Query(
        sort: [SortDescriptor(\BgRunSnapshot.startedAt, order: .reverse)]
    ) private var runs: [BgRunSnapshot]
    
    var body: some View {
        List {
            if let latest = runs.first {
                Section {
                    StatusHeader(latest: latest)
                        .cardRowBackground()
                }
            }
            
            Section("Recent Runs") {
                if runs.isEmpty {
                    ContentUnavailableView {
                        Label("No background runs yet", systemImage: "waveform.path.ecg")
                    } description: {
                        Text("Once the app has run a background refresh, details will appear here.")
                    }
                } else {
                    ForEach(runs, id: \.runId) { snap in
                        RunRow(snap: snap)
                            .cardRowBackground()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(15)
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}

// MARK: - Components

private struct StatusHeader: View {
    let latest: BgRunSnapshot

    var body: some View {
        let now = Date()
        let status = computeStatus(from: latest, now: now)
        
        HStack(spacing: 16) {
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Background Status: \(status.label)")
                    .font(.headline)
                HStack(spacing: 12) {
                    Label("Started \(relative(latest.startedAt, now: now))", systemImage: "clock")
                    if let desiredNextRunAt = latest.nextScheduledAt {
                        Label("Desired \(timeOrDash(desiredNextRunAt))", systemImage: "calendar.badge.clock")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
    
    private func computeStatus(from latest: BgRunSnapshot, now: Date) -> (label: String, color: Color) {
        let staleAfter: TimeInterval = 3 * 60 * 60
        let lastActivityAt = latest.endedAt ?? latest.startedAt
        if now.timeIntervalSince(lastActivityAt) > staleAfter {
            return latest.isComplete ? ("Last run stale", .orange) : ("Unfinished and stale", .red)
        }
        if latest.isComplete == false {
            return ("Unfinished", .orange)
        }
        switch latest.outcome {
        case .success: return ("Completed", .green)
        case .skipped: return ("Skipped", .orange)
        case .cancelled: return ("Cancelled", .orange)
        case .expired: return ("Expired", .red)
        case .failed: return ("Failed", .red)
        case nil: return ("Unfinished", .orange)
        }
    }
}

private struct RunRow: View {
    let snap: BgRunSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(runDate(snap))
                    .font(.headline)
                Spacer()
                Text(outcomeLabel(snap))
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(outcomeColor(snap).opacity(0.15))
                    .foregroundStyle(outcomeColor(snap))
                    .clipShape(Capsule())
            }
            
            if snap.isComplete {
                HStack(spacing: 12) {
                    Label("\(formatSecondsInt64(snap.activeSeconds))", systemImage: "timer")
                    Label("Budget \(snap.budgetSecUsed)s", systemImage: "gauge.with.dots.needle.50percent")
                    if snap.didNotify {
                        Label("Notified", systemImage: "bell.badge.fill")
                    } else {
                        Label("No notify", systemImage: "bell.slash")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let reason = snap.reasonNoNotify, !reason.isEmpty {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let desiredNextRunAt = snap.nextScheduledAt {
                    Text("Desired cadence date: \(timeOrDash(desiredNextRunAt))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("Desired cadence: \(snap.cadence)m")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Cadence Reason: \(snap.cadenceReason ?? "unknown")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            schedulerOutcomeLabel("Fallback scheduler", outcome: snap.fallbackSchedulingOutcome)
            schedulerOutcomeLabel("Authoritative scheduler", outcome: snap.authoritativeSchedulingOutcome)
            phaseLabel("Upload drain", duration: snap.uploadDrainDurationSeconds, outcome: snap.uploadDrainOutcome)
            phaseLabel("Unified ingestion", duration: snap.ingestionDurationSeconds, outcome: snap.ingestionOutcome)
        }
        
        .accessibilityElement(children: .combine)
    }
    
    private func runDate(_ snapshot: BgRunSnapshot) -> String {
        let date = snapshot.endedAt ?? snapshot.startedAt
        return "\(endDate(date)) - \(endTime(date))"
    }

    private func outcomeLabel(_ snapshot: BgRunSnapshot) -> String {
        guard let outcome = snapshot.outcome else { return "Unfinished" }
        switch outcome {
        case .success: return "Success"
        case .skipped: return "Skipped"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .expired: return "Expired"
        }
    }
    private func outcomeColor(_ snapshot: BgRunSnapshot) -> Color {
        switch snapshot.outcome {
        case .success: return .green
        case .skipped, .cancelled, nil: return .orange
        case .failed, .expired: return .red
        }
    }

    @ViewBuilder
    private func schedulerOutcomeLabel(_ title: String, outcome: BgSchedulingOutcome?) -> some View {
        if let outcome {
            Label(
                "\(title): \(schedulerOutcomeText(outcome))",
                systemImage: outcome.preservesSuccessor ? "checkmark.circle" : "exclamationmark.triangle"
            )
            .font(.footnote)
            .foregroundStyle(outcome.preservesSuccessor ? Color.secondary : Color.red)
        }
    }

    @ViewBuilder
    private func phaseLabel(_ title: String, duration: Int64?, outcome: BgPhaseOutcome?) -> some View {
        if let outcome {
            Text("\(title): \(outcome.rawValue)\(duration.map { " (\(formatSecondsInt64($0)))" } ?? "")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func schedulerOutcomeText(_ outcome: BgSchedulingOutcome) -> String {
        switch outcome {
        case .submitted: "submitted"
        case .preservedExisting: "preserved existing request"
        case .preservedImmediate: "preserved immediate request"
        case .submissionFailed: "submission failed"
        case .restoredPrevious: "restored previous request"
        case .restorationFailed: "restoration failed"
        }
    }
}

// MARK: - Formatting Helpers

private func relative(_ date: Date, now: Date = .now) -> String {
    date.relativeDate(to: now, with: .abbreviated) // e.g., "12m ago"
}

private enum BgHealthFormatters {
    static let endTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.timeZone = .current
        return f
    }()
    static let endDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        f.timeZone = .current
        return f
    }()
    static let timeOrDash: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.timeZone = .current
        return f
    }()
}

private func endTime(_ date: Date) -> String {
    BgHealthFormatters.endTime.string(from: date) // e.g., “4:12 PM”
}

private func endDate(_ date: Date) -> String {
    BgHealthFormatters.endDate.string(from: date) // e.g., “11/1/25”
}

private func timeOrDash(_ date: Date) -> String {
    BgHealthFormatters.timeOrDash.string(from: date)
}

private func formatSecondsInt64(_ secs: Int64) -> String {
    // If you still want the "X.Ys" format for very short durations
    if secs < 60 {
        // Note: This will result in "X.0s" if secs is Int64
        return String(format: "%.1fs", Double(secs))
    }
    
    let m = secs / 60 // Integer division gives minutes
    let s = secs % 60 // Modulo gives remaining seconds
    
    // Cast m and s back to Int for string interpolation, although not strictly necessary as Int64 works too
    return "\(Int(m))m \(Int(s))s"
}

// MARK: - Preview
#Preview("Diagnostics") {
    let preview = Preview(BgRunSnapshot.self)
    preview.addExamples(BgRunSnapshot.sampleRuns)
    
    return NavigationStack {
        BgHealthDiagnosticsView()
            .modelContainer(preview.container)
            .navigationTitle("Background Health")
            .navigationBarTitleDisplayMode(.inline)
        //            .toolbarBackground(.visible, for: .navigationBar)      // <- non-translucent
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}

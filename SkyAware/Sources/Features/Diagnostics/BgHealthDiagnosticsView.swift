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
        sort: [SortDescriptor(\BgRunSnapshot.endedAt, order: .reverse)]
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
    @Environment(\.colorScheme) private var scheme
    
    
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
                    Label("Last \(relative(latest.endedAt, now: now))", systemImage: "clock")
                    Label("Next \(timeOrDash(latest.nextScheduledAt))", systemImage: "calendar.badge.clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
    
    private func computeStatus(from latest: BgRunSnapshot, now: Date) -> (label: String, color: Color) {
        // Tunable thresholds
        let behindGrace: TimeInterval = 45 * 60 // 45m after nextScheduled → "Behind"
        let stalledAfter: TimeInterval = 3 * 60 * 60 // 3h since last run → "Stalled"
        
        // Stalled if we haven't finished a run in a long while
        if now.timeIntervalSince(latest.endedAt) > stalledAfter {
            return ("Stalled", .orange)
        }
        
        // Behind if we're past our next scheduled time by > 45m
        if now.timeIntervalSince(latest.nextScheduledAt) > behindGrace {
            return ("Behind", .yellow)
        }
        
        // Error outcome escalates severity
        if latest.outcomeCode >= 2 {
            return ("Error", .red)
        }
        
        return ("OK", .green)
    }
}

private struct RunRow: View {
    let snap: BgRunSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(endDate(snap.endedAt)) - \(endTime(snap.endedAt))")
                    .font(.headline)
                Spacer()
                Text(outcomeLabel(snap.outcomeCode))
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(outcomeColor(snap.outcomeCode).opacity(0.15))
                    .foregroundStyle(outcomeColor(snap.outcomeCode))
                    .clipShape(Capsule())
            }
            
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
            
            Text("Next: \(timeOrDash(snap.nextScheduledAt))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Cadence: \(snap.cadence)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Cadence Reason: \(snap.cadenceReason ?? "unknown")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        
        .accessibilityElement(children: .combine)
    }
    
    private func outcomeLabel(_ code: Int) -> String {
        switch code {
        case 0: return "OK"
        case 1: return "Partial"
        default: return "Error"
        }
    }
    private func outcomeColor(_ code: Int) -> Color {
        switch code {
        case 0: return .green
        case 1: return .orange
        default: return .red
        }
    }
}

// MARK: - Formatting Helpers

private func relative(_ date: Date, now: Date = .now) -> String {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    
    return f.localizedString(for: date, relativeTo: now) // e.g., “12m ago”
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

private func formatSeconds(_ secs: Double) -> String {
    if secs < 60 { return String(format: "%.1fs", secs) }
    let m = Int(secs) / 60
    let s = Int(secs) % 60
    return "\(m)m \(s)s"
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

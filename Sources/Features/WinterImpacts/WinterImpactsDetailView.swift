import SwiftUI

/// Push from a Today entry with its selected source day and the owner's live accepted inputs.
struct WinterImpactsDetailView: View {
    let accepted: WSSIAcceptedAssessment?
    let currentLocation: WSSIAcceptedAssessment.Location?
    let enabled: Bool
    @Environment(RuntimeConnectivityState.self) private var connectivity: RuntimeConnectivityState?
    @State private var selectedDay: Int

    init(
        initialDay: Int,
        accepted: WSSIAcceptedAssessment?,
        currentLocation: WSSIAcceptedAssessment.Location?,
        enabled: Bool
    ) {
        _selectedDay = State(initialValue: (1...3).contains(initialDay) ? initialDay : 1)
        self.accepted = accepted
        self.currentLocation = currentLocation
        self.enabled = enabled
    }

    var body: some View {
        let now = Date.now
        let boundaries = accepted?.periods.compactMap { $0.assessment.revision }
            .flatMap { [$0.validFrom, $0.validTo] } ?? []
        TimelineView(.explicit([now] + Set(boundaries.filter { $0 > now }).sorted())) { context in
            let projection = WinterImpactsPresentation(
                accepted: accepted, currentLocation: currentLocation, enabled: enabled, at: max(context.date, .now)
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Forecast day", selection: $selectedDay) {
                        ForEach(projection.days, id: \.number) { day in
                            Text("Day \(day.number)").tag(day.number)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("winter-forecast-day")

                    if let day = projection.days.first(where: { $0.number == selectedDay }) {
                        WinterImpactsDetailContent(
                            day: day, refreshStatus: projection.refreshStatus,
                            isOffline: connectivity?.generalPathAvailability == .unavailable
                        )
                    }
                }
                .padding(20)
            }
        }
        .background(.skyAwareBackground)
        .navigationTitle("Winter Impacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
    }
}

private struct WinterImpactsDetailContent: View {
    let day: WinterImpactsPresentation.Day
    let refreshStatus: WSSIAcceptedAssessment.RefreshStatus?
    let isOffline: Bool

    private var savedForecastNotice: LocalizedStringKey? {
        let applicableProducts = ([day.overall] + day.components).filter {
            $0.validity == .valid || $0.validity == .notYetValid
        }
        guard !applicableProducts.isEmpty else { return nil }
        if isOffline { return "Offline. Showing saved forecast information." }

        let updateUnavailable = applicableProducts.contains { product in
            switch refreshStatus {
            case .manifestFailed:
                return true
            case .reconciled(let results):
                if results.contains(where: { result in
                    guard result.day == day.number, result.product == product.product else { return false }
                    switch result.outcome {
                    case .failed(_, let retained), .unavailable(let retained):
                        return retained == product.revision?.revision
                    case .current, .accepted:
                        return false
                    }
                }) { return true }
            default:
                break
            }
            return product.sourceStatus == .unavailable || product.pollHealth == .failed
        }
        return updateUnavailable ? "A forecast update is unavailable. Showing saved information." : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WinterImpactDetailRow(product: day.overall)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground(cornerRadius: SkyAwareRadius.card)

            if let savedForecastNotice {
                Text(savedForecastNotice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Components").font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(day.components, id: \.product) { component in
                    Divider()
                    WinterImpactDetailRow(product: component)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground(cornerRadius: SkyAwareRadius.card)

            Text("Source: [NOAA Weather Prediction Center](https://www.wpc.ncep.noaa.gov/wwd/wssi/wssi.php)")
                .font(.footnote)
        }
    }
}

private struct WinterImpactDetailRow: View {
    let product: WinterImpactsPresentation.Product
    private var isOverall: Bool { product.product == .overallImpact }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.detailTitle)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(product.detailClassification)
                .font(isOverall ? .title2.weight(.semibold) : product.severity == nil ? .body : .body.weight(.semibold))
                .foregroundStyle(product.impact == .confirmedNoImpact ? .secondary : .primary)
                .accessibilityIdentifier("winter-classification-\(product.product.rawValue)")
            if let explanation = product.detailDefinition {
                Text(explanation).font(.subheadline).foregroundStyle(.secondary)
            }
            if product.impact == .noMatchUnknownCoverage {
                Text("Coverage is unverified.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if let revision = product.revision {
                let date = Date.FormatStyle(date: .abbreviated, time: .shortened)
                Text("From \(revision.validFrom, format: date)\nUntil \(revision.validTo, format: date)")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Issued \(revision.issuedAt, format: date)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

extension WinterImpactsPresentation.Product {
    var detailTitle: LocalizedStringKey {
        switch product {
        case .overallImpact: "Overall Impact"
        case .snowAmount: "Snow Amount"
        case .snowLoad: "Snow Load"
        case .iceAccumulation: "Ice Accumulation"
        case .blowingSnow: "Blowing Snow"
        }
    }

    var detailDefinition: LocalizedStringKey? {
        switch product {
        case .overallImpact:
            switch severity {
            case .winterWeatherArea: "Winter weather is expected with little disruption."
            case .minor: "A few inconveniences to daily life are possible."
            case .moderate: "Daily routines may be disrupted, and travel may be hazardous."
            case .major: "Significant disruptions and widespread closures are possible."
            case .extreme: "Severe, widespread disruptions may make travel impossible."
            case nil: nil
            }
        case .snowAmount: "Potential impacts from accumulated snowfall."
        case .snowLoad: "Potential impacts from the weight of snow on trees and structures."
        case .iceAccumulation: "Potential impacts from ice buildup and wind."
        case .blowingSnow: "Reduced visibility or drifting snow when winds pick up."
        }
    }

    var detailClassification: LocalizedStringKey {
        switch impact {
        case .disabled: "Winter Impacts is off"
        case .offLocation: "Unavailable for this location"
        case .unavailable: "Impact unknown"
        case .expired: "Forecast period ended"
        case .noMatchUnknownCoverage: "Impact unknown"
        case .confirmedNoImpact: "No local impact"
        case .match(.winterWeatherArea): "Winter Weather Area"
        case .match(.minor): "Minor"
        case .match(.moderate): "Moderate"
        case .match(.major): "Major"
        case .match(.extreme): "Extreme"
        }
    }
}

#if DEBUG
struct WinterImpactsDetailFixture: View {
    @State private var connectivity: RuntimeConnectivityState
    private let offline: Bool
    private let location = WSSIAcceptedAssessment.Location(
        point: .init(latitude: 39, longitude: -105), h3Cell: 1, observedAt: .distantPast
    )

    init() {
        let offline = ProcessInfo.processInfo.environment["UI_TESTS_WINTER_IMPACTS_OFFLINE"] == "1"
        let connectivity = RuntimeConnectivityState()
        connectivity.updateGeneralPathAvailability(isSatisfied: !offline)
        _connectivity = State(initialValue: connectivity)
        self.offline = offline
    }

    var body: some View {
        NavigationStack {
            NavigationLink("Open Day 2") {
                WinterImpactsDetailView(
                    initialDay: 2,
                    accepted: .init(location: location, periods: [
                        period(1, .overallImpact, .match(.moderate)),
                        period(1, .snowLoad, .match(.winterWeatherArea)),
                        period(2, .overallImpact, .noMatchUnknownCoverage),
                        period(2, .snowAmount, .match(.major)),
                        period(2, .snowLoad, .confirmedNoImpact),
                        period(3, .overallImpact, .match(.major), expired: true),
                        period(3, .blowingSnow, .match(.major), expired: true)
                    ], refreshStatus: offline ? .notAttempted : .manifestFailed(.httpStatus(503, retryAfterSeconds: nil))),
                    currentLocation: location,
                    enabled: true
                )
            }
        }
        .environment(connectivity)
    }

    private func period(
        _ day: Int, _ product: WSSIProduct, _ impact: WSSIPointAssessment.Impact, expired: Bool = false
    ) -> WSSIAcceptedAssessment.Period {
        let start = expired ? Date.now - 172_800 : Date.now + Double(day - 1) * 86_400 - 3_600
        return .init(assessment: .init(
            product: product, day: day, point: location.point,
            revision: .init(revision: UUID(), issuedAt: .now, validFrom: start, validTo: start + 86_400,
                            gisFileDate: nil, gisIngestDate: nil, retrievedAt: .now, geometryPath: "/geometry"),
            validity: expired ? .expired : day == 1 ? .valid : .notYetValid,
            sourceStatus: .available, pollHealth: .successful, impact: impact
        ), coverage: .unknown)
    }
}
#endif

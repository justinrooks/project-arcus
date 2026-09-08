#if canImport(Testing)
import Foundation
import Testing
import SwiftUI
@testable import SkyAware

@Suite("Summary Awareness Panel")
struct SummaryAwarenessPanelTests {
    @Test("Intensity preserves distinct hazard-specific meanings and excludes unsupported levels")
    func intensityMeanings() {
        for layer in [MapLayer.tornado, .wind, .hail] {
            let levels = SevereIntensityPresentation.levels(for: layer)
            #expect(levels.count == (layer == .hail ? 2 : 3))
            #expect(Set(levels.map(\.title)).count == levels.count)
            #expect(Set(levels.map(\.detail)).count == levels.count)
            #expect(levels.allSatisfy { $0.detail.hasPrefix("If ") && !$0.title.contains("CIG") })
        }
        #expect(SevereIntensityPresentation(hazard: .tornado, level: 1)?.title == "Strong tornadoes possible")
        #expect(SevereIntensityPresentation(hazard: .tornado, level: 2)?.title == "More intense tornadoes possible")
        #expect(SevereIntensityPresentation(hazard: .tornado, level: 3)?.title == "Highest tornado intensity potential")
        #expect(SevereIntensityPresentation(hazard: .hail, level: 3) == nil)
        #expect(SevereIntensityPresentation(hazard: .unknown, level: 1) == nil)
        #expect(SevereIntensityPresentation(hazard: .wind, level: 4) == nil)
    }

    @Test("Only a matching resolved severe row owns intensity, including under an alert hero")
    func intensityOwnership() throws {
        let intensity = try #require(SevereIntensityPresentation(hazard: .tornado, level: 2))
        for contentState in [TodayContentState.current, .cachedRefreshing, .staleRefreshing, .degraded] {
            #expect(intensity.displayed(for: .tornado(probability: 0.10), contentState: contentState) == intensity)
        }
        for contentState in [TodayContentState.noCacheResolving, .unavailable] {
            #expect(intensity.displayed(for: .tornado(probability: 0.10), contentState: contentState) == nil)
        }
        for threat in [nil, SevereWeatherThreat.allClear, .wind(probability: 0.10), .hail(probability: 0.10)] {
            #expect(intensity.displayed(for: threat, contentState: .current) == nil)
        }
        let primary = SummaryAwarenessPrimaryState.resolve(
            stormRisk: .high, severeRisk: .tornado(probability: 0.10), fireRisk: .critical,
            alerts: [makeAlert(title: "Tornado Warning", headline: "Take shelter")],
            todayContentState: .current, isStormRiskResolving: false, isSevereRiskResolving: false,
            isFireRiskResolving: false, isOffline: false
        )
        #expect(primary == .alert(title: "Tornado Warning", detail: "Take shelter"))
        #expect(intensity.displayed(for: .tornado(probability: 0.10), contentState: .current) == intensity)
    }

    @Test("Intensity request rejects missing provenance and a different displayed location or threat")
    func intensityRequestProvenance() {
        let projection = makeIntensityProjection()
        let location = projection.locationSnapshot
        let request = SummaryIntensityRequest(projection: projection, location: location,
                                              threat: projection.severeRisk, contentState: .current)
        #expect(request?.sourceToken == "forecast:test")
        #expect(SummaryIntensityRequest(projection: makeIntensityProjection(token: nil), location: location,
                                       threat: projection.severeRisk, contentState: .current) == nil)
        #expect(SummaryIntensityRequest(projection: makeIntensityProjection(token: "all-clear:test"), location: location,
                                       threat: projection.severeRisk, contentState: .current) == nil)
        #expect(SummaryIntensityRequest(projection: projection, location: makeIntensityProjection(latitude: 40).locationSnapshot,
                                       threat: projection.severeRisk, contentState: .current) == nil)
        #expect(SummaryIntensityRequest(projection: projection, location: location,
                                       threat: .wind(probability: 0.10), contentState: .current) == nil)
        #expect(SummaryIntensityRequest(projection: projection, location: location,
                                       threat: projection.severeRisk, contentState: .unavailable) == nil)
    }

    @Test("Intensity panels render in light dark and accessibility sizes")
    @MainActor
    func intensityRenderEvidence() throws {
        for (name, hazard, level, scheme, size) in [
            ("tornado-1-light", ThreatType.tornado, 1, ColorScheme.light, DynamicTypeSize.large),
            ("tornado-2-dark", .tornado, 2, .dark, .large),
            ("tornado-3-accessibility", .tornado, 3, .dark, .accessibility3),
            ("wind-1-light", .wind, 1, .light, .large),
            ("wind-2-dark", .wind, 2, .dark, .large),
            ("wind-3-accessibility", .wind, 3, .light, .accessibility3),
            ("hail-1-light", .hail, 1, .light, .large),
            ("hail-2-dark", .hail, 2, .dark, .accessibility3)
        ] {
            let threat: SevereWeatherThreat = switch hazard {
            case .tornado: .tornado(probability: 0.10)
            case .wind: .wind(probability: 0.30)
            default: .hail(probability: 0.30)
            }
            let panel = PrimaryAwarenessPanel(
                stormRisk: .enhanced, severeRisk: threat, fireRisk: .clear,
                alerts: name == "tornado-2-dark" ? [makeAlert(title: "Tornado Warning", headline: "Take shelter now")] : [],
                todayContentState: .current, resolutionState: SummaryResolutionState(), showsOfflineToken: false,
                onOpenMapLayer: { _ in }, onOpenAlerts: {}
            )
            .environment(\.severeIntensity, SevereIntensityPresentation(hazard: hazard, level: level))
            .environment(\.dynamicTypeSize, size)
            .padding(16)
            .frame(width: 390)
            .background(Color.skyAwareBackground)
            .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: panel)
            let data = try #require(renderer.uiImage?.pngData())
            try data.write(to: URL(fileURLWithPath: "/private/tmp/486-\(name).png"))
            let layer: MapLayer = switch hazard {
            case .tornado: .tornado
            case .wind: .wind
            default: .hail
            }
            let legend = HatchingExplanationView(layer: layer).explanationContent
                .background(Color.skyAwareBackground)
                .environment(\.colorScheme, scheme)
                .environment(\.dynamicTypeSize, size)
            let legendRenderer = ImageRenderer(content: legend)
            let legendData = try #require(legendRenderer.uiImage?.pngData())
            try legendData.write(to: URL(fileURLWithPath: "/private/tmp/486-legend-\(name).png"))
        }
    }

    @Test("Late intensity results cannot leak across locations or survive expiry")
    @MainActor
    func intensityResultIdentity() throws {
        let projection = makeIntensityProjection()
        let request = SummaryIntensityRequest(projection: projection, location: projection.locationSnapshot,
                                              threat: projection.severeRisk, contentState: .current)
        let other = makeIntensityProjection(latitude: 40)
        let otherRequest = SummaryIntensityRequest(projection: other, location: other.locationSnapshot,
                                                   threat: other.severeRisk, contentState: .current)
        let value = LocalSevereIntensity(presentation: try #require(.init(hazard: .tornado, level: 2)),
                                         expires: Date(timeIntervalSince1970: 200))
        #expect(SummaryIntensityModifier.visibleIntensity(request: request, loadedRequest: request,
                                                          intensity: value, now: .init(timeIntervalSince1970: 199)) != nil)
        #expect(SummaryIntensityModifier.visibleIntensity(request: otherRequest, loadedRequest: request,
                                                          intensity: value, now: .init(timeIntervalSince1970: 199)) == nil)
        #expect(SummaryIntensityModifier.visibleIntensity(request: request, loadedRequest: request,
                                                          intensity: value, now: value.expires) == nil)
    }

    private func makeIntensityProjection(token: String? = "forecast:test", latitude: Double = 35) -> HomeProjectionRecord {
        HomeProjectionRecord(
            id: UUID(), projectionKey: "intensity-test", latitude: latitude, longitude: -97, h3Cell: 1,
            countyCode: "test", forecastZone: nil, fireZone: "test", placemarkSummary: nil, timeZoneId: nil,
            locationTimestamp: .distantPast, createdAt: .distantPast, updatedAt: .distantPast, lastViewedAt: nil,
            weather: nil, stormRisk: .enhanced, severeRisk: .tornado(probability: 0.10), fireRisk: .clear,
            activeAlerts: [], activeMesos: [], lastHotAlertsLoadAt: nil, lastSlowProductsLoadAt: nil,
            lastWeatherLoadAt: nil, convectiveSourceToken: token
        )
    }

    @Test("warning outranks every other awareness signal")
    func warning_outranksOtherSignals() {
        let selected = SummaryAwarenessPrimaryState.resolve(
            stormRisk: .moderate,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            alerts: [
                makeAlert(
                    title: "Tornado Warning",
                    headline: "A tornado warning is active for your area."
                )
            ],
            todayContentState: .current,
            isStormRiskResolving: false,
            isSevereRiskResolving: false,
            isFireRiskResolving: false,
            isOffline: false
        )

        #expect(
            selected == .alert(
                title: "Tornado Warning",
                detail: "A tornado warning is active for your area."
            )
        )
    }

    @Test("watch outranks storm severe and fire when no warning is active")
    func watch_outranksOtherSignals() {
        let alert = makeAlert(
            title: "Severe Thunderstorm Watch",
            headline: "Severe Thunderstorm Watch issued June 11 at 2:02PM CDT until June 11 at 9:00PM CDT by NWS Chicago IL"
        )

        let selected = SummaryAwarenessPrimaryState.resolve(
            stormRisk: .high,
            severeRisk: .hail(probability: 0.20),
            fireRisk: .extreme,
            alerts: [alert],
            todayContentState: .current,
            isStormRiskResolving: false,
            isSevereRiskResolving: false,
            isFireRiskResolving: false,
            isOffline: false
        )

        let expectedDetail = SummaryAwarenessPrimaryState.watchHeroDetail(expires: alert.expires)

        #expect(
            selected == .alert(
                title: "Severe Thunderstorm Watch",
                detail: expectedDetail
            )
        )
    }

    @Test("watch subtitle uses a concise same-day expiration time")
    func watchSubtitle_usesConciseSameDayExpirationTime() {
        let chicago = TimeZone(identifier: "America/Chicago")!
        let now = makeDate(year: 2026, month: 6, day: 11, hour: 14, minute: 30, timeZone: chicago)
        let expires = makeDate(year: 2026, month: 6, day: 11, hour: 21, minute: 0, timeZone: chicago)

        let subtitle = SummaryAwarenessPrimaryState.watchHeroDetail(
            expires: expires,
            now: now,
            timeZone: chicago
        )

        #expect(subtitle == "In effect until 9:00 PM CDT")
    }

    @Test("watch subtitle keeps concise wording for severe thunderstorm watches")
    func watchSubtitle_keepsConciseWordingForSevereThunderstormWatches() {
        let chicago = TimeZone(identifier: "America/Chicago")!
        let now = makeDate(year: 2026, month: 8, day: 12, hour: 16, minute: 15, timeZone: chicago)
        let expires = makeDate(year: 2026, month: 8, day: 12, hour: 18, minute: 0, timeZone: chicago)

        let subtitle = SummaryAwarenessPrimaryState.watchHeroDetail(
            expires: expires,
            now: now,
            timeZone: chicago
        )

        #expect(subtitle == "In effect until 6:00 PM CDT")
    }

    @Test("watch subtitle includes a short date when the expiration is on a later day")
    func watchSubtitle_includesShortDateWhenExpirationIsOnALaterDay() {
        let chicago = TimeZone(identifier: "America/Chicago")!
        let now = makeDate(year: 2026, month: 6, day: 11, hour: 20, minute: 0, timeZone: chicago)
        let expires = makeDate(year: 2026, month: 6, day: 12, hour: 1, minute: 0, timeZone: chicago)

        let subtitle = SummaryAwarenessPrimaryState.watchHeroDetail(
            expires: expires,
            now: now,
            timeZone: chicago
        )

        #expect(subtitle == "In effect until Jun 12, 1:00 AM CDT")
    }

    @Test("watch subtitle falls back when expiration is missing")
    func watchSubtitle_fallsBackWhenExpirationIsMissing() {
        let chicago = TimeZone(identifier: "America/Chicago")!

        let subtitle = SummaryAwarenessPrimaryState.watchHeroDetail(
            expires: nil,
            now: makeDate(year: 2026, month: 6, day: 11, hour: 14, minute: 0, timeZone: chicago),
            timeZone: chicago
        )

        #expect(subtitle == "Watch currently in effect")
    }

    @Test("watch subtitle excludes issue metadata from the hero copy")
    func watchSubtitle_excludesIssueMetadataFromTheHeroCopy() {
        let chicago = TimeZone(identifier: "America/Chicago")!
        let now = makeDate(year: 2026, month: 6, day: 11, hour: 14, minute: 30, timeZone: chicago)
        let expires = makeDate(year: 2026, month: 6, day: 11, hour: 21, minute: 0, timeZone: chicago)

        let subtitle = SummaryAwarenessPrimaryState.watchHeroDetail(
            expires: expires,
            now: now,
            timeZone: chicago
        )

        #expect(subtitle == "In effect until 9:00 PM CDT")
        #expect(subtitle.contains("issued") == false)
        #expect(subtitle.contains("NWS Chicago IL") == false)
    }

    @Test("cached refreshing without a resolved risk keeps the primary hero calm")
    func cachedRefreshingWithoutResolvedRisk_keepsPrimaryHeroCalm() {
        let selected = SummaryAwarenessPrimaryState.resolve(
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            alerts: [],
            todayContentState: .cachedRefreshing,
            isStormRiskResolving: true,
            isSevereRiskResolving: false,
            isFireRiskResolving: false,
            isOffline: false
        )

        #expect(selected == .quiet)
    }

    @Test("no-cache resolving still shows the primary loading hero")
    func noCacheResolving_showsPrimaryLoading() {
        let selected = SummaryAwarenessPrimaryState.resolve(
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            alerts: [],
            todayContentState: .noCacheResolving,
            isStormRiskResolving: true,
            isSevereRiskResolving: false,
            isFireRiskResolving: false,
            isOffline: false
        )

        #expect(
            selected == .loading(
                title: "Storm Risk",
                detail: "Getting storm risk…",
                symbolName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
            )
        )
    }

    @Test("tornado outranks hail and wind within severe risk")
    func tornado_outranksHailAndWind() {
        let selected = SummaryAwarenessPrimaryState.resolve(
            stormRisk: .allClear,
            severeRisk: .tornado(probability: 0.05),
            fireRisk: .clear,
            alerts: [],
            todayContentState: .current,
            isStormRiskResolving: false,
            isSevereRiskResolving: false,
            isFireRiskResolving: false,
            isOffline: false
        )

        #expect(selected == .severe(.tornado(probability: 0.05)))
    }

    @Test("storm risk outranks fire risk when storm is elevated")
    func storm_outranksFire() {
        let selected = SummaryAwarenessPrimaryState.resolve(
            stormRisk: .high,
            severeRisk: .allClear,
            fireRisk: .critical,
            alerts: [],
            todayContentState: .current,
            isStormRiskResolving: false,
            isSevereRiskResolving: false,
            isFireRiskResolving: false,
            isOffline: false
        )

        #expect(selected == .storm(.high))
    }

    @Test("fire risk becomes primary when storm and severe are quiet")
    func fire_becomesPrimaryWhenStormAndSevereAreQuiet() {
        let selected = SummaryAwarenessPrimaryState.resolve(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .critical,
            alerts: [],
            todayContentState: .current,
            isStormRiskResolving: false,
            isSevereRiskResolving: false,
            isFireRiskResolving: false,
            isOffline: false
        )

        #expect(selected == .fire(.critical))
    }

    @Test("quiet weather is selected when every signal is calm")
    func quiet_selectedWhenEverySignalIsCalm() {
        let selected = SummaryAwarenessPrimaryState.resolve(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            alerts: [],
            todayContentState: .current,
            isStormRiskResolving: false,
            isSevereRiskResolving: false,
            isFireRiskResolving: false,
            isOffline: false
        )

        #expect(selected == .quiet)
    }

    @Test("matching severe source transforms severe row into supplemental presentation")
    func matchingSevereSourceTransformsSevereRowIntoSupplementalPresentation() {
        let presentation = SupportingRiskRowDisplayModel.severe(
            threat: .tornado(probability: 0.05),
            primarySource: .severeRisk
        )

        #expect(presentation.presentationMode == .supplemental)
        #expect(presentation.title == "Severe Risk")
        #expect(presentation.detail == "Tornado is the main severe signal")
    }

    @Test("matching storm source transforms storm row into supplemental presentation")
    func matchingStormSourceTransformsStormRowIntoSupplementalPresentation() {
        let presentation = SupportingRiskRowDisplayModel.storm(
            level: .moderate,
            primarySource: .stormRisk
        )

        #expect(presentation.presentationMode == .supplemental)
        #expect(presentation.title == "Storm Risk")
        #expect(presentation.detail == "Primary outlook signal")
    }

    @Test("matching fire source transforms fire row into supplemental presentation")
    func matchingFireSourceTransformsFireRowIntoSupplementalPresentation() {
        let presentation = SupportingRiskRowDisplayModel.fire(
            level: .critical,
            primarySource: .fireRisk
        )

        #expect(presentation.presentationMode == .supplemental)
        #expect(presentation.title == "Fire Risk")
        #expect(presentation.detail == "Rapid spread potential remains elevated")
    }

    @Test("clear fire risk uses subdued presentation with shortened detail")
    func clearFireRiskUsesSubduedPresentationWithShortenedDetail() {
        let presentation = SupportingRiskRowDisplayModel.fire(
            level: .clear,
            primarySource: .synthesizedQuietState
        )

        #expect(presentation.presentationMode == .subdued)
        #expect(presentation.title == "No Elevated Fire Risk")
        #expect(presentation.detail == "No elevated fire weather risk is forecast.")
    }

    @Test("elevated fire risk keeps the normal presentation")
    func elevatedFireRiskKeepsTheNormalPresentation() {
        let presentation = SupportingRiskRowDisplayModel.fire(
            level: .elevated,
            primarySource: .synthesizedQuietState
        )

        #expect(presentation.presentationMode == .normal)
        #expect(presentation.title == "Elevated Fire Risk")
        #expect(presentation.detail == "Dry fuels, low humidity, and wind could help any fire that starts spread more quickly.")
    }

    @Test("quiet primary leaves supporting rows normal")
    func quietPrimaryLeavesSupportingRowsNormal() {
        let stormPresentation = SupportingRiskRowDisplayModel.storm(
            level: .slight,
            primarySource: .synthesizedQuietState
        )
        let severePresentation = SupportingRiskRowDisplayModel.severe(
            threat: .wind(probability: 0.15),
            primarySource: .synthesizedQuietState
        )
        let firePresentation = SupportingRiskRowDisplayModel.fire(
            level: .elevated,
            primarySource: .synthesizedQuietState
        )

        #expect(stormPresentation.presentationMode == .normal)
        #expect(severePresentation.presentationMode == .normal)
        #expect(firePresentation.presentationMode == .normal)
    }

    @Test("non-primary supporting rows remain normal")
    func nonPrimarySupportingRowsRemainNormal() {
        let stormPresentation = SupportingRiskRowDisplayModel.storm(
            level: .enhanced,
            primarySource: .severeRisk
        )
        let severePresentation = SupportingRiskRowDisplayModel.severe(
            threat: .hail(probability: 0.20),
            primarySource: .stormRisk
        )
        let firePresentation = SupportingRiskRowDisplayModel.fire(
            level: .extreme,
            primarySource: .stormRisk
        )

        #expect(stormPresentation.presentationMode == .normal)
        #expect(severePresentation.presentationMode == .normal)
        #expect(firePresentation.presentationMode == .normal)
    }

    @Test("storm hero accessibility contract separates category value and hint")
    func stormHeroAccessibilityContract_separatesCategoryValueAndHint() {
        let contract = SummaryAwarenessPrimaryState.storm(.moderate).accessibilityContract

        #expect(contract.label == "Storm Risk")
        #expect(contract.value.contains("Moderate Risk"))
        #expect(contract.value.contains("Widespread severe storms expected"))
        #expect(contract.hint == "Opens the severe risk map.")
    }

    @Test("severe hero accessibility contract keeps the hazard name and probability clear")
    func severeHeroAccessibilityContract_keepsHazardNameAndProbabilityClear() {
        let contract = SummaryAwarenessPrimaryState.severe(.tornado(probability: 0.10)).accessibilityContract

        #expect(contract.label == "Severe Risk")
        #expect(contract.value == "Tornado. 10% chance of tornadoes")
        #expect(contract.hint == "Opens the tornado map.")
    }

    @Test("fire hero accessibility contract keeps the fire value readable")
    func fireHeroAccessibilityContract_keepsTheFireValueReadable() {
        let contract = SummaryAwarenessPrimaryState.fire(.critical).accessibilityContract

        #expect(contract.label == "Fire Risk")
        #expect(contract.value.contains("Critical Fire Risk"))
        #expect(contract.value.contains("Dry fuels, strong winds, and very low humidity could allow any fire that starts to spread rapidly."))
        #expect(contract.hint == "Opens the fire risk map.")
    }

    @Test("alert hero accessibility contract keeps weather text intact")
    func alertHeroAccessibilityContract_keepsWeatherTextIntact() {
        let contract = SummaryAwarenessPrimaryState.alert(
            title: "Severe Thunderstorm Watch",
            detail: "In effect until 9:00 PM CDT"
        ).accessibilityContract

        #expect(contract.label == "Severe Thunderstorm Watch")
        #expect(contract.value == "In effect until 9:00 PM CDT")
        #expect(contract.hint == "Opens the alert center.")
    }

    @Test("loading and quiet hero accessibility contracts remain concise")
    func loadingAndQuietHeroAccessibilityContracts_remainConcise() {
        let loading = SummaryAwarenessPrimaryState.loading(
            title: "Storm Risk",
            detail: "Getting storm risk…",
            symbolName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        ).accessibilityContract

        let quiet = SummaryAwarenessPrimaryState.quiet.accessibilityContract

        #expect(loading.label == "Storm Risk")
        #expect(loading.value == "Getting storm risk…")
        #expect(loading.hint == nil)

        #expect(quiet.label == "Quiet Weather")
        #expect(quiet.value == "No active severe threats nearby")
        #expect(quiet.hint == nil)
    }

    private func makeAlert(title: String, headline: String) -> AlertDTO {
        AlertDTO(
            id: UUID().uuidString,
            messageId: nil,
            currentRevisionSent: nil,
            title: title,
            headline: headline,
            issued: .now,
            expires: .now.addingTimeInterval(3_600),
            ends: .now.addingTimeInterval(3_600),
            messageType: "alert",
            sender: nil,
            severity: "Severe",
            urgency: "Immediate",
            certainty: "Likely",
            description: headline,
            instruction: nil,
            response: nil,
            areaSummary: "Test Area",
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

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )

        return components.date!
    }
}

#endif

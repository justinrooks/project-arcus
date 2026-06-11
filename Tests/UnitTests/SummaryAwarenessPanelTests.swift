#if canImport(Testing)
import Foundation
import Testing
@testable import SkyAware

@Suite("Summary Awareness Panel")
struct SummaryAwarenessPanelTests {
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
        let selected = SummaryAwarenessPrimaryState.resolve(
            stormRisk: .high,
            severeRisk: .hail(probability: 0.20),
            fireRisk: .extreme,
            alerts: [
                makeAlert(
                    title: "Severe Thunderstorm Watch",
                    headline: "Conditions are favorable for severe thunderstorms."
                )
            ],
            isStormRiskResolving: false,
            isSevereRiskResolving: false,
            isFireRiskResolving: false,
            isOffline: false
        )

        #expect(
            selected == .alert(
                title: "Severe Thunderstorm Watch",
                detail: "Conditions are favorable for severe thunderstorms."
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
            areaSummary: "Test Area",
            instruction: nil,
            response: nil,
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
}

#endif

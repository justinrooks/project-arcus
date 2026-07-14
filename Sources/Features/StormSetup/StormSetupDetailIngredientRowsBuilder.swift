import ArcusCore

enum StormSetupDetailIngredientRowsBuilder {
    static func makeIngredientRows(from assessment: StormSetupAssessment.ReadableAssessment) -> [StormSetupDetailPresentation.Row] {
        [
            StormSetupDetailPresentationFormatter.row(title: "Instability", value: StormSetupSummaryPresentation.readableSignal(assessment.instability)),
            StormSetupDetailPresentationFormatter.row(title: "Moisture", value: StormSetupSummaryPresentation.readableSignal(assessment.moisture)),
            StormSetupDetailPresentationFormatter.row(
                title: "Low-level rotation",
                value: StormSetupSummaryPresentation.readableSignal(assessment.lowLevelRotation)
            ),
            StormSetupDetailPresentationFormatter.row(title: "Deep shear", value: StormSetupSummaryPresentation.readableSignal(assessment.deepShear)),
            StormSetupDetailPresentationFormatter.row(title: "Cloud bases", value: StormSetupSummaryPresentation.readableCloudBase(assessment.cloudBase)),
            StormSetupDetailPresentationFormatter.row(title: "Cap / inhibition", value: StormSetupSummaryPresentation.readableSignal(assessment.capInhibition))
        ]
    }

    static func makeIngredientRows(from details: TornadoViabilityDetails) -> [StormSetupDetailPresentation.Row] {
        [
            StormSetupDetailPresentationFormatter.row(title: "Instability", value: StormSetupSummaryPresentation.readableSignal(details.instability)),
            StormSetupDetailPresentationFormatter.row(title: "Moisture", value: StormSetupSummaryPresentation.readableSignal(details.moisture)),
            StormSetupDetailPresentationFormatter.row(
                title: "Low-level rotation",
                value: StormSetupSummaryPresentation.readableSignal(details.lowLevelRotation)
            ),
            StormSetupDetailPresentationFormatter.row(title: "Deep shear", value: StormSetupSummaryPresentation.readableSignal(details.deepShear)),
            StormSetupDetailPresentationFormatter.row(title: "Cloud bases", value: StormSetupSummaryPresentation.readableCloudBase(details.cloudBase)),
            StormSetupDetailPresentationFormatter.row(title: "Cap / inhibition", value: StormSetupSummaryPresentation.readableSignal(details.inhibition))
        ]
    }

    static func makeDetailIngredientGroups(
        fuelAndInstability: [StormSetupDetailPresentation.Row],
        cloudBaseAndEffectiveLayer: [StormSetupDetailPresentation.Row],
        shearAndRotation: [StormSetupDetailPresentation.Row],
        compositeParameters: [StormSetupDetailPresentation.Row],
        showsDetailedIngredientSections: Bool,
        profileQuality: [StormSetupDetailPresentation.Row],
        profileQualityNoteText: String?
    ) -> [StormSetupDetailPresentation.DetailIngredientGroup] {
        var groups: [StormSetupDetailPresentation.DetailIngredientGroup] = []

        if showsDetailedIngredientSections {
            appendDetailIngredientGroup(title: "Fuel & Instability", rows: fuelAndInstability, noteText: nil, to: &groups)
            appendDetailIngredientGroup(title: "Cloud Base & Effective Layer", rows: cloudBaseAndEffectiveLayer, noteText: nil, to: &groups)
            appendDetailIngredientGroup(title: "Shear & Rotation", rows: shearAndRotation, noteText: nil, to: &groups)
            appendDetailIngredientGroup(title: "Composite Parameters", rows: compositeParameters, noteText: nil, to: &groups)
        }
        appendDetailIngredientGroup(title: "Profile Quality", rows: profileQuality, noteText: profileQualityNoteText, to: &groups)

        return groups
    }

    static func makeFuelAndInstabilityRows(from parameters: TornadoRawParameters) -> [StormSetupDetailPresentation.Row] {
        var rows: [StormSetupDetailPresentation.Row] = []
        rows.appendNumericRow(title: "MLCAPE — J/kg", value: parameters.mlcapeJkg, format: .whole, accessibilityTitle: "Mixed-layer CAPE")
        rows.appendNumericRow(title: "MUCAPE — J/kg", value: parameters.mucapeJkg, format: .whole, accessibilityTitle: "Most-unstable CAPE")
        rows.appendNumericRow(title: "SBCAPE — J/kg", value: parameters.sbcapeJkg, format: .whole, accessibilityTitle: "Surface-based CAPE")
        rows.appendNumericRow(title: "MLCIN — J/kg", value: parameters.mlcinJkg, format: .whole, accessibilityTitle: "Mixed-layer CIN")
        rows.appendNumericRow(title: "0–3 km CAPE / 3CAPE — J/kg", value: parameters.threeCapeJkg, format: .whole, accessibilityTitle: "Zero to three kilometer CAPE")
        rows.appendNumericRow(
            title: "Temperature/dew-point spread — °F",
            value: parameters.tempDewPtDeltaF,
            format: .decimalIfNeeded,
            accessibilityTitle: "Temperature and dew-point spread"
        )
        return rows
    }

    static func makeFuelAndInstabilityRows(from parameters: StormSetupDTO.Raw) -> [StormSetupDetailPresentation.Row] {
        var rows: [StormSetupDetailPresentation.Row] = []
        rows.appendNumericRow(title: "MLCAPE — J/kg", value: parameters.mlcapeJkg, format: .whole, accessibilityTitle: "Mixed-layer CAPE")
        rows.appendNumericRow(title: "MUCAPE — J/kg", value: parameters.mucapeJkg, format: .whole, accessibilityTitle: "Most-unstable CAPE")
        rows.appendNumericRow(title: "SBCAPE — J/kg", value: parameters.sbcapeJkg, format: .whole, accessibilityTitle: "Surface-based CAPE")
        rows.appendNumericRow(title: "MLCIN — J/kg", value: parameters.mlcinJkg, format: .whole, accessibilityTitle: "Mixed-layer CIN")
        rows.appendNumericRow(title: "0–3 km CAPE / 3CAPE — J/kg", value: parameters.threeCapeJkg, format: .whole, accessibilityTitle: "Zero to three kilometer CAPE")
        rows.appendNumericRow(
            title: "Temperature/dew-point spread — °F",
            value: parameters.tempDewPtDeltaF,
            format: .decimalIfNeeded,
            accessibilityTitle: "Temperature and dew-point spread"
        )
        return rows
    }

    static func makeCloudBaseAndEffectiveLayerRows(
        mllclM: Double?,
        effectiveLayer: AnvilEffectiveLayerDTO?,
        effectiveLayerAvailability: String?,
        hasEffectiveLayer: Bool? = nil
    ) -> [StormSetupDetailPresentation.Row] {
        var rows: [StormSetupDetailPresentation.Row] = []
        rows.appendNumericRow(title: "MLLCL — m", value: mllclM, format: .whole, accessibilityTitle: "Mixed-layer lifted condensation level")
        rows.append(contentsOf: makeEffectiveLayerBoundaryRows(from: effectiveLayer))

        if let availabilityRow = makeEffectiveLayerAvailabilityRow(
            effectiveLayer: effectiveLayer,
            effectiveLayerAvailability: effectiveLayerAvailability,
            hasEffectiveLayer: hasEffectiveLayer
        ) {
            rows.append(availabilityRow)
        }
        return rows
    }

    static func makeShearAndRotationRows(
        srh01kmM2s2: Double?,
        srh03kmM2s2: Double?,
        shear06kmKt: Double?,
        effectiveSrhM2s2: Double?,
        effectiveBulkShearMs: Double?,
        stormMotion: AnvilStormMotionDTO?,
        stormMotionAvailability: String?,
        hasStormMotion: Bool? = nil
    ) -> [StormSetupDetailPresentation.Row] {
        var rows: [StormSetupDetailPresentation.Row] = []
        rows.appendNumericRow(title: "0–1 km SRH — m²/s²", value: srh01kmM2s2, format: .whole, accessibilityTitle: "Zero to one kilometer storm-relative helicity")
        rows.appendNumericRow(title: "0–3 km SRH — m²/s²", value: srh03kmM2s2, format: .whole, accessibilityTitle: "Zero to three kilometer storm-relative helicity")
        rows.appendNumericRow(title: "0–6 km shear — kt", value: shear06kmKt, format: .whole, accessibilityTitle: "Zero to six kilometer shear")
        rows.appendNumericRow(title: "Effective SRH — m²/s²", value: effectiveSrhM2s2, format: .whole, accessibilityTitle: "Storm-relative helicity meters squared per second squared")
        rows.appendNumericRow(title: "Effective bulk shear — m/s", value: effectiveBulkShearMs, format: .decimalIfNeeded, accessibilityTitle: "Effective bulk shear meters per second")
        rows.append(contentsOf: StormSetupDetailAdvancedRowsBuilder.makeStormMotionRows(from: stormMotion))

        if let availabilityRow = makeStormMotionAvailabilityRow(
            stormMotion: stormMotion,
            stormMotionAvailability: stormMotionAvailability,
            hasStormMotion: hasStormMotion
        ) {
            rows.append(availabilityRow)
        }
        return rows
    }

    static func makeProfileQualityRows(profileLevelCount: Int?) -> [StormSetupDetailPresentation.Row] {
        var rows: [StormSetupDetailPresentation.Row] = []

        if let profileLevelCount {
            rows.append(.init(
                title: "Profile level count",
                value: profileLevelCount.formatted(),
                accessibilityLabel: "Profile level count. \(profileLevelCount)."
            ))
        }

        return rows
    }

    private static func appendDetailIngredientGroup(
        title: String,
        rows: [StormSetupDetailPresentation.Row],
        noteText: String?,
        to groups: inout [StormSetupDetailPresentation.DetailIngredientGroup]
    ) {
        guard rows.isEmpty == false || noteText?.trimmedNonEmpty != nil else {
            return
        }

        groups.append(.init(title: title, rows: rows, noteText: noteText?.trimmedNonEmpty))
    }

    private static func makeEffectiveLayerAvailabilityRow(
        effectiveLayer: AnvilEffectiveLayerDTO?,
        effectiveLayerAvailability: String?,
        hasEffectiveLayer: Bool?
    ) -> StormSetupDetailPresentation.Row? {
        if let effectiveLayer {
            switch effectiveLayer.status.trimmedNonEmpty?.lowercased() {
            case "found", "available":
                return StormSetupDetailPresentationFormatter.row(title: "Effective layer availability", value: "Yes")
            case "notfound", "missing":
                return StormSetupDetailPresentationFormatter.row(title: "Effective layer availability", value: "No")
            default:
                break
            }
        }

        if let hasEffectiveLayer {
            return StormSetupDetailPresentationFormatter.row(title: "Effective layer availability", value: hasEffectiveLayer ? "Yes" : "No")
        }

        guard let effectiveLayerAvailability = effectiveLayerAvailability?.trimmedNonEmpty else {
            return nil
        }

        switch effectiveLayerAvailability.lowercased() {
        case "found", "available":
            return StormSetupDetailPresentationFormatter.row(title: "Effective layer availability", value: "Yes")
        case "notfound", "missing":
            return StormSetupDetailPresentationFormatter.row(title: "Effective layer availability", value: "No")
        default:
            return nil
        }
    }

    private static func makeEffectiveLayerBoundaryRows(from layer: AnvilEffectiveLayerDTO?) -> [StormSetupDetailPresentation.Row] {
        guard let layer else { return [] }

        let status = layer.status.trimmedNonEmpty?.lowercased()
        if status == "found" || status == "available" {
            var rows: [StormSetupDetailPresentation.Row] = []
            rows.append(contentsOf: StormSetupDetailAdvancedRowsBuilder.makeBoundRows(
                baseTitle: "Effective layer height",
                boundsTitle: "Effective layer height bounds",
                baseValue: layer.baseMetersAgl,
                topValue: layer.topMetersAgl,
                unit: "m AGL",
                accessibilityUnit: "meters above ground level"
            ))
            rows.append(contentsOf: StormSetupDetailAdvancedRowsBuilder.makeBoundRows(
                baseTitle: "Effective layer pressure",
                boundsTitle: "Effective layer pressure bounds",
                baseValue: layer.basePressureMb,
                topValue: layer.topPressureMb,
                unit: "mb",
                accessibilityUnit: "millibars"
            ))
            return rows
        }

        return []
    }

    private static func makeStormMotionAvailabilityRow(
        stormMotion: AnvilStormMotionDTO?,
        stormMotionAvailability: String?,
        hasStormMotion: Bool?
    ) -> StormSetupDetailPresentation.Row? {
        if let stormMotion, stormMotion.bunkersRight != nil {
            return StormSetupDetailPresentationFormatter.row(title: "Storm motion availability", value: "Yes")
        }

        if let hasStormMotion {
            return StormSetupDetailPresentationFormatter.row(title: "Storm motion availability", value: hasStormMotion ? "Yes" : "No")
        }

        guard let stormMotionAvailability = stormMotionAvailability?.trimmedNonEmpty else {
            return nil
        }

        switch stormMotionAvailability.lowercased() {
        case "found", "available":
            return StormSetupDetailPresentationFormatter.row(title: "Storm motion availability", value: "Yes")
        case "notfound", "missing":
            return StormSetupDetailPresentationFormatter.row(title: "Storm motion availability", value: "No")
        default:
            return nil
        }
    }
}

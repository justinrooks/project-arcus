import ArcusCore

enum StormSetupDetailAdvancedRowsBuilder {
    static func makeAdvancedRows(
        dto: StormSetupDTO,
        assessmentAnvil: StormSetupAssessment.AnvilEvidence?,
        preferences: StormSetupPreferences
    ) -> (rows: [StormSetupDetailPresentation.Row], diagnosticsNoteText: String?) {
        guard preferences.effectiveDetailedIngredientsEnabled else {
            return ([], nil)
        }

        var rows: [StormSetupDetailPresentation.Row] = []
        rows.appendNumericRow(title: "MLCAPE — J/kg", value: dto.raw.mlcapeJkg, format: .whole, accessibilityTitle: "Mixed-layer CAPE")
        rows.appendNumericRow(title: "MUCAPE — J/kg", value: dto.raw.mucapeJkg, format: .whole, accessibilityTitle: "Most-unstable CAPE")
        rows.appendNumericRow(title: "SBCAPE — J/kg", value: dto.raw.sbcapeJkg, format: .whole, accessibilityTitle: "Surface-based CAPE")
        rows.appendNumericRow(title: "MLCIN — J/kg", value: dto.raw.mlcinJkg, format: .whole, accessibilityTitle: "Mixed-layer CIN")
        rows.appendNumericRow(title: "0–1 km SRH — m²/s²", value: dto.raw.srh01kmM2s2, format: .whole, accessibilityTitle: "Zero to one kilometer storm-relative helicity")
        rows.appendNumericRow(title: "0–3 km SRH — m²/s²", value: dto.raw.srh03kmM2s2, format: .whole, accessibilityTitle: "Zero to three kilometer storm-relative helicity")
        rows.appendNumericRow(title: "0–6 km shear — kt", value: dto.raw.shear06kmKt, format: .whole, accessibilityTitle: "Zero to six kilometer shear")
        rows.appendNumericRow(title: "MLLCL — m", value: dto.raw.mllclM, format: .whole, accessibilityTitle: "Mixed-layer lifted condensation level")
        rows.appendNumericRow(
            title: "Temperature/dew-point spread — °F",
            value: dto.raw.tempDewPtDeltaF,
            format: .decimalIfNeeded,
            accessibilityTitle: "Temperature and dew-point spread"
        )
        rows.appendNumericRow(
            title: "0–3 km CAPE / 3CAPE — J/kg",
            value: dto.raw.threeCapeJkg,
            format: .whole,
            accessibilityTitle: "Zero to three kilometer CAPE"
        )

        if let anvil = assessmentAnvil {
            rows.appendSignalRow(title: "SCP signal", value: anvil.scp.support, accessibilityTitle: "S C P signal")
            rows.appendSignalRow(title: "STP signal", value: anvil.stp.support, accessibilityTitle: "S T P signal")
            rows.appendSignalRow(title: "SHIP signal", value: anvil.ship.support, accessibilityTitle: "S H I P signal")

            if anvil.diagnostics.hasEffectiveLayer == true {
                rows.append(.init(
                    title: "Effective layer available",
                    value: "Yes",
                    accessibilityLabel: "Effective layer available. Yes."
                ))
            }

            if anvil.diagnostics.hasStormMotion == true {
                rows.append(.init(
                    title: "Storm motion available",
                    value: "Yes",
                    accessibilityLabel: "Storm motion available. Yes."
                ))
            }

            if let profileLevelCount = anvil.diagnostics.qualityProfileLevelCount {
                rows.append(.init(
                    title: "Profile level count",
                    value: profileLevelCount.formatted(),
                    accessibilityLabel: "Profile level count. \(profileLevelCount)."
                ))
            }
        }

        let noteText = assessmentAnvil?.diagnostics.warnings.isEmpty == false
            ? "Some advanced diagnostics are limited."
            : nil

        return (rows, noteText)
    }

    static func makeAdvancedRows(
        from parameters: TornadoRawParameters,
        diagnostics: TornadoRawParameters
    ) -> (rows: [StormSetupDetailPresentation.Row], diagnosticsNoteText: String?) {
        var rows: [StormSetupDetailPresentation.Row] = []
        rows.appendNumericRow(title: "MLCAPE — J/kg", value: parameters.mlcapeJkg, format: .whole, accessibilityTitle: "Mixed-layer CAPE")
        rows.appendNumericRow(title: "MUCAPE — J/kg", value: parameters.mucapeJkg, format: .whole, accessibilityTitle: "Most-unstable CAPE")
        rows.appendNumericRow(title: "SBCAPE — J/kg", value: parameters.sbcapeJkg, format: .whole, accessibilityTitle: "Surface-based CAPE")
        rows.appendNumericRow(title: "MLCIN — J/kg", value: parameters.mlcinJkg, format: .whole, accessibilityTitle: "Mixed-layer CIN")
        rows.appendNumericRow(title: "0–1 km SRH — m²/s²", value: parameters.srh01kmM2s2, format: .whole, accessibilityTitle: "Zero to one kilometer storm-relative helicity")
        rows.appendNumericRow(title: "0–3 km SRH — m²/s²", value: parameters.srh03kmM2s2, format: .whole, accessibilityTitle: "Zero to three kilometer storm-relative helicity")
        rows.appendNumericRow(title: "0–6 km shear — kt", value: parameters.shear06kmKt, format: .whole, accessibilityTitle: "Zero to six kilometer shear")
        rows.appendNumericRow(title: "MLLCL — m", value: parameters.mllclM, format: .whole, accessibilityTitle: "Mixed-layer lifted condensation level")
        rows.appendNumericRow(
            title: "Temperature/dew-point spread — °F",
            value: parameters.tempDewPtDeltaF,
            format: .decimalIfNeeded,
            accessibilityTitle: "Temperature and dew-point spread"
        )
        rows.appendNumericRow(
            title: "0–3 km CAPE / 3CAPE — J/kg",
            value: parameters.threeCapeJkg,
            format: .whole,
            accessibilityTitle: "Zero to three kilometer CAPE"
        )

        let noteText = diagnostics.nonNilFieldCount > 0 && diagnostics.nonNilFieldCount < parameters.nonNilFieldCount
            ? "Some advanced diagnostics are limited."
            : nil

        return (rows, noteText)
    }

    static func makeProfileAnalysis(
        from response: AnvilAnalyzeProfileResponse?
    ) -> (rows: [StormSetupDetailPresentation.Row], noteText: String?) {
        guard let response else {
            return ([], nil)
        }

        var rows: [StormSetupDetailPresentation.Row] = []
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeCompositeRow(
                title: "SCP",
                accessibilityTitle: "Supercell composite parameter",
                value: response.scp
            ),
            to: &rows
        )
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeCompositeRow(
                title: "STP — fixed",
                accessibilityTitle: "Significant tornado parameter fixed",
                value: response.stpFixed
            ),
            to: &rows
        )
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeCompositeRow(
                title: "STP — CIN-adjusted",
                accessibilityTitle: "Significant tornado parameter C I N adjusted",
                value: response.stpCin
            ),
            to: &rows
        )
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeCompositeRow(
                title: "SHIP",
                accessibilityTitle: "Significant hail parameter",
                value: response.ship
            ),
            to: &rows
        )
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeWholeRow(
                title: "Effective SRH — m²/s²",
                accessibilityTitle: "Storm-relative helicity meters squared per second squared",
                value: response.effectiveSrh
            ),
            to: &rows
        )
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeOneDecimalRow(
                title: "Effective bulk shear — m/s",
                accessibilityTitle: "Effective bulk shear meters per second",
                value: response.effectiveBulkShearMs
            ),
            to: &rows
        )
        rows.append(contentsOf: makeEffectiveLayerRows(from: response.effectiveLayer))
        rows.append(contentsOf: makeStormMotionRows(from: response.stormMotion))

        guard rows.isEmpty == false else {
            return ([], nil)
        }

        let noteText = response.quality.warnings.contains(where: { $0.trimmedNonEmpty != nil })
            ? "Some profile details are limited."
            : nil

        return (rows, noteText)
    }

    static func makeCompositeParameterRows(
        scp: Double?,
        stpFixed: Double?,
        stpCin: Double?,
        ship: Double?,
        signalEvidence: StormSetupAssessment.AnvilEvidence? = nil
    ) -> [StormSetupDetailPresentation.Row] {
        var rows: [StormSetupDetailPresentation.Row] = []
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeCompositeRow(
                title: "SCP",
                accessibilityTitle: "Supercell composite parameter",
                value: scp
            ),
            to: &rows
        )
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeCompositeRow(
                title: "STP — fixed",
                accessibilityTitle: "Significant tornado parameter fixed",
                value: stpFixed
            ),
            to: &rows
        )
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeCompositeRow(
                title: "STP — CIN-adjusted",
                accessibilityTitle: "Significant tornado parameter C I N adjusted",
                value: stpCin
            ),
            to: &rows
        )
        StormSetupDetailPresentationFormatter.appendIfPresent(
            StormSetupDetailPresentationFormatter.makeCompositeRow(
                title: "SHIP",
                accessibilityTitle: "Significant hail parameter",
                value: ship
            ),
            to: &rows
        )

        if let signalEvidence {
            rows.appendSignalRow(title: "SCP signal", value: signalEvidence.scp.support, accessibilityTitle: "S C P signal")
            rows.appendSignalRow(title: "STP signal", value: signalEvidence.stp.support, accessibilityTitle: "S T P signal")
            rows.appendSignalRow(title: "SHIP signal", value: signalEvidence.ship.support, accessibilityTitle: "S H I P signal")
        }

        return rows
    }

    static func makeBoundRows(
        baseTitle: String,
        boundsTitle: String,
        baseValue: Double?,
        topValue: Double?,
        unit: String,
        accessibilityUnit: String
    ) -> [StormSetupDetailPresentation.Row] {
        let base = StormSetupDetailPresentationFormatter.formattedWholeValue(baseValue)
        let top = StormSetupDetailPresentationFormatter.formattedWholeValue(topValue)

        switch (base, top) {
        case let (base?, top?):
            return [.init(
                title: boundsTitle,
                value: "\(base)–\(top) \(unit)",
                accessibilityLabel: "\(boundsTitle). \(base) to \(top) \(accessibilityUnit)."
            )]
        case let (base?, nil):
            return [.init(
                title: "\(baseTitle) base",
                value: "\(base) \(unit)",
                accessibilityLabel: "\(baseTitle) base. \(base) \(accessibilityUnit)."
            )]
        case let (nil, top?):
            return [.init(
                title: "\(baseTitle) top",
                value: "\(top) \(unit)",
                accessibilityLabel: "\(baseTitle) top. \(top) \(accessibilityUnit)."
            )]
        case (nil, nil):
            return []
        }
    }

    static func makeStormMotionRows(from stormMotion: AnvilStormMotionDTO?) -> [StormSetupDetailPresentation.Row] {
        guard let stormMotion, let bunkersRight = stormMotion.bunkersRight else {
            return []
        }

        let speed = StormSetupDetailPresentationFormatter.formattedWholeValue(bunkersRight.speedKt)
        let direction = StormSetupDetailPresentationFormatter.formattedWholeValue(bunkersRight.directionTowardDeg)

        switch (speed, direction) {
        case let (speed?, direction?):
            return [.init(
                title: "Bunkers-right storm motion",
                value: "\(speed) kt toward \(direction)°",
                accessibilityLabel: "Bunkers-right storm motion. \(speed) knots toward \(direction) degrees."
            )]
        case let (speed?, nil):
            return [.init(
                title: "Bunkers-right storm motion speed",
                value: "\(speed) kt",
                accessibilityLabel: "Bunkers-right storm motion speed. \(speed) knots."
            )]
        case let (nil, direction?):
            return [.init(
                title: "Bunkers-right storm motion direction",
                value: "toward \(direction)°",
                accessibilityLabel: "Bunkers-right storm motion direction. Toward \(direction) degrees."
            )]
        case (nil, nil):
            return []
        }
    }

    private static func makeEffectiveLayerRows(from layer: AnvilEffectiveLayerDTO?) -> [StormSetupDetailPresentation.Row] {
        guard let layer else { return [] }

        let status = layer.status.trimmedNonEmpty?.lowercased()
        if status == "found" {
            var rows: [StormSetupDetailPresentation.Row] = []
            rows.append(contentsOf: makeBoundRows(
                baseTitle: "Effective layer height",
                boundsTitle: "Effective layer height bounds",
                baseValue: layer.baseMetersAgl,
                topValue: layer.topMetersAgl,
                unit: "m AGL",
                accessibilityUnit: "meters above ground level"
            ))
            rows.append(contentsOf: makeBoundRows(
                baseTitle: "Effective layer pressure",
                boundsTitle: "Effective layer pressure bounds",
                baseValue: layer.basePressureMb,
                topValue: layer.topPressureMb,
                unit: "mb",
                accessibilityUnit: "millibars"
            ))
            return rows
        }

        if status == "notfound" {
            return [.init(
                title: "Effective layer",
                value: "Not identified",
                accessibilityLabel: "Effective layer. Not identified."
            )]
        }

        return []
    }
}

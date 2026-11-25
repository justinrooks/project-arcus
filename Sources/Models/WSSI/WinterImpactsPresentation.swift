import Foundation

/// The common Experience input for Today, Detail and the morning summary.
struct WinterImpactsPresentation: Sendable {
    enum Impact: Equatable, Sendable {
        case disabled, offLocation, unavailable, expired
        case match(WSSISeverity), noMatchUnknownCoverage, confirmedNoImpact
    }

    struct Product: Sendable {
        let product: WSSIProduct
        let impact: Impact
        let revision: WSSIAcceptedRevision?
        let validity: WSSIValidity
        let sourceStatus: WSSISourceStatus
        let pollHealth: WSSIPollHealth
        let coverage: WSSICoverage

        var severity: WSSISeverity? {
            if case .match(let severity) = impact { return severity }
            return nil
        }

        /// Format these source endpoints in the user's time zone at the presentation surface.
        var sourceInterval: DateInterval? {
            revision.map { DateInterval(start: $0.validFrom, end: $0.validTo) }
        }
    }

    struct Day: Sendable {
        let number: Int
        let overall: Product
        let components: [Product]

        /// The rail describes Overall when it applies, otherwise the earliest affected component.
        var railProduct: Product? {
            if overall.severity != nil { return overall }
            return components.compactMap { product -> (product: Product, start: Date)? in
                guard product.severity != nil, let start = product.revision?.validFrom else { return nil }
                return (product, start)
            }.min { $0.start < $1.start }?.product
        }

        fileprivate var heroSeverity: WSSISeverity? {
            switch (number, overall.severity) {
            case (1, .moderate), (1...2, .major), (1...2, .extreme): overall.severity
            default: nil
            }
        }

        fileprivate var morningSeverity: WSSISeverity? {
            switch overall.severity {
            case .minor, .moderate, .major, .extreme: overall.severity
            default: nil
            }
        }
    }

    let days: [Day]
    let location: WSSIAcceptedAssessment.Location?
    let refreshStatus: WSSIAcceptedAssessment.RefreshStatus?

    var heroDay: Day? { strongest(by: \.heroSeverity) }
    var morningDay: Day? { strongest(by: \.morningSeverity) }

    /// The caller resolves hero precedence against alerts and other forecasts.
    func railDay(winterOwnsHero: Bool) -> Day? {
        if winterOwnsHero, let heroDay { return heroDay }
        return earliest { $0.railProduct?.revision?.validFrom }
    }

    init(
        accepted: WSSIAcceptedAssessment?,
        currentLocation: WSSIAcceptedAssessment.Location?,
        enabled: Bool,
        at time: Date
    ) {
        let applicable: WSSIAcceptedAssessment?
        let missing: Impact
        if !enabled {
            applicable = nil
            missing = .disabled
        } else if currentLocation == nil || (accepted != nil && accepted?.location != currentLocation) {
            applicable = nil
            missing = .offLocation
        } else {
            applicable = accepted
            missing = .unavailable
        }

        location = applicable?.location
        refreshStatus = applicable?.refreshStatus
        let assessments = applicable?.periods ?? []
        days = (1...3).map { day in
            func project(_ product: WSSIProduct) -> Product {
                let period = assessments.first {
                    $0.assessment.day == day && $0.assessment.product == product
                }
                return Product(product: product, period: period, missing: missing, at: time)
            }

            return Day(
                number: day,
                overall: project(.overallImpact),
                components: WSSIProduct.allCases.filter { $0 != .overallImpact }.map(project)
            )
        }
    }

    private func strongest(by severity: KeyPath<Day, WSSISeverity?>) -> Day? {
        for level in WSSISeverity.allCases.reversed() {
            if let day = earliest(by: { $0[keyPath: severity] == level ? $0.overall.revision?.validFrom : nil }) {
                return day
            }
        }
        return nil
    }

    private func earliest(by start: (Day) -> Date?) -> Day? {
        // Independently retained slots can cross issuance boundaries. Compare source windows first.
        days.compactMap { day -> (day: Day, start: Date)? in
            guard let start = start(day) else { return nil }
            return (day, start)
        }.min { ($0.start, $0.day.number) < ($1.start, $1.day.number) }?.day
    }
}

private extension WinterImpactsPresentation.Product {
    init(
        product: WSSIProduct, period: WSSIAcceptedAssessment.Period?,
        missing: WinterImpactsPresentation.Impact, at time: Date
    ) {
        self.product = product
        let assessment = period?.assessment
        revision = assessment?.revision
        sourceStatus = assessment?.sourceStatus ?? .unknown
        pollHealth = assessment?.pollHealth ?? .unknown
        coverage = period?.coverage ?? .unknown
        if let revision {
            // A retained assessment still observes the accepted source's exclusive end.
            if time < revision.validFrom {
                validity = .notYetValid
            } else {
                validity = time < revision.validTo ? .valid : .expired
            }
        } else {
            validity = .neverAccepted
        }

        switch assessment?.impact {
        case nil: impact = missing
        case .disabled: impact = .disabled
        case .invalidPoint: impact = .offLocation
        case _ where validity == .expired: impact = .expired
        case _ where validity == .neverAccepted: impact = .unavailable
        case .unavailable: impact = .unavailable
        case .match(let severity): impact = .match(severity)
        case .noMatchUnknownCoverage: impact = .noMatchUnknownCoverage
        case .confirmedNoImpact: impact = .confirmedNoImpact
        }
    }
}

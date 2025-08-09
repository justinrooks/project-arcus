//
//  ext+SpcProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/26/25.
//

import Foundation
import MapKit

extension SpcProvider {
    static var previewData: SpcProvider {
        let mock = SpcProvider()
        mock.meso = [
            MesoscaleDiscussion(
                id: UUID(),
                number: 1893,
                title: "test",
                link: URL(string:"https://www.spc.noaa.gov/products/md/md1893.html")!,
                issued: Date(),
                validStart: Calendar.current.date(byAdding: .minute, value: 60, to: Date())!,
                validEnd: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                areasAffected: "Western SD, northeast WY, far southeast MT",
                summary: "test",
                concerning: "Severe potential… Watch unlikely",
                watchProbability: .percent(5),
                threats: MDThreats(peakWindMPH: 65, hailRangeInches: 1.5...2.5, tornadoStrength: "Not expected"),
                coordinates: MesoGeometry.coordinates(from: """
                       ATTN...WFO...BYZ...GGW...TFX...

                       LAT...LON   46441136 46761221 47041239 47441240 47691208 47991054
                                   48011017 48080908 47980781 47500689 46800636 46110655
                                   45890673 45420788 45690939 45951005 46201081 46441136 

                       MOST PROBABLE PEAK WIND GUST...55-70 MPH
                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
""") ?? [],

                alertType: .mesoscale
            ),
            MesoscaleDiscussion(
                id: UUID(),
                number: 1894,
                title: "test",
                link: URL(string:"https://www.spc.noaa.gov/products/md/md1894.html")!,
                issued: Date(),
                validStart: Calendar.current.date(byAdding: .minute, value: 90, to: Date())!,
                validEnd: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!,
                areasAffected: "Western ID, northwest WY, far southwest MT",
                summary: "test",
                concerning: "Severe potential… Watch likely",
                watchProbability: .percent(5),
                threats: MDThreats(peakWindMPH: 60, hailRangeInches: 1.5...5.5, tornadoStrength: "95 MPH"),
                coordinates: MesoGeometry.coordinates(from: """
                        ATTN...WFO...UNR...BYZ...

                        LAT...LON   44640241 44240268 44030332 44140411 44370500 44480533
                                    44700555 44990556 45370523 45570470 45590413 45440325
                                    45220265 44970240 44640241 

                        MOST PROBABLE PEAK WIND GUST...UP TO 60 MPH
                        MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
""") ?? [],
                alertType: .mesoscale
            ),
            MesoscaleDiscussion(
                id: UUID(),
                number: 1895,
                title: "test",
                link: URL(string:"https://www.spc.noaa.gov/products/md/md1895.html")!,
                issued: Date(),
                validStart: Calendar.current.date(byAdding: .minute, value: 120, to: Date())!,
                validEnd: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!,
                areasAffected: "Western SD, northeast WY, far southeast MT",
                summary: "test",
                concerning: "Severe potential… Watch unlikely",
                watchProbability: .percent(15),
                threats: MDThreats(peakWindMPH: 63, hailRangeInches: 1.0...4.5, tornadoStrength: "Not expected"),
                coordinates: MesoGeometry.coordinates(from: """
                   ATTN...WFO...FSD...ABR...LBF...UNR...

                   LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
                               42500075 43370091 

                   MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
                   MOST PROBABLE PEAK WIND GUST...65-80 MPH
                   MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
                                      
""") ?? [],
                alertType: .mesoscale
            )
//            MesoscaleDiscussion(
//                id: UUID(),
//                title: "MD 1824",
//                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
//                issued: Date(),
//                summary: """
//                Mesoscale Discussion 1824
//                   NWS Storm Prediction Center Norman OK
//                   0247 PM CDT Mon Jul 28 2025
//
//                   Areas affected...parts of south central and southeastern South
//                   Dakota...adjacent north central Nebraska
//
//                   Concerning...Severe potential...Watch possible 
//
//                   Valid 281947Z - 282145Z
//
//                   Probability of Watch Issuance...60 percent
//
//                   SUMMARY...Scattered, intensifying thunderstorm development, posing a
//                   risk for a few strong downbursts and perhaps some hail, appears
//                   possible by 4-6 PM CDT.  Timing of a potential severe weather watch
//                   issuance remains unclear, but trends are being monitored for this
//                   possibility.
//
//                   DISCUSSION...A surface cold front, now advancing south of Pierre,
//                   Philip and Rapid City is becoming better defined, with strengthening
//                   differential heating along and ahead of it, centered near the
//                   western South Dakota/Nebraska state border northeastward across the
//                   Winner toward Huron vicinities.  While temperatures are approaching
//                   100 F within the corridor of stronger boundary-layer heating,
//                   surface dew points have been slower to mix below 70F, and through
//                   the 60s F, than suggested by model forecast soundings at Winner and
//                   Valentine.  Even so, latest objective analysis suggests that the
//                   pre- and post-cold frontal boundary layer remains strongly capped
//                   beneath the warm and elevated mixed-layer air as far north as the
//                   North/South Dakota state border vicinity.
//
//                   Mid/upper support for sustained boundary-layer based convection
//                   anytime soon remains unclear, although it appears possible that a
//                   subtle perturbation progressing across and east-northeast of the
//                   Black Hills is contributing to ongoing attempts at convective
//                   development.  It appears more probable that with further insolation,
//                   continued heating and deeper mixing within the pre-frontal
//                   boundary-layer may eventually support intensifying, high-based
//                   thunderstorm development late this afternoon.  In the presence of
//                   strong deep-layer shear, this activity could pose a risk for severe
//                   hail and increasing potential for strong downbursts into early
//                   evening.
//
//                   ..Kerr/Thompson.. 07/28/2025
//
//                   ...Please see www.spc.noaa.gov for graphic product...
//
//                   ATTN...WFO...FSD...ABR...LBF...UNR...
//
//                   LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
//                               42500075 43370091 
//
//                   MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
//                   MOST PROBABLE PEAK WIND GUST...65-80 MPH
//                   MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
//                """,
//                alertType: .mesoscale
//            ),
//            MesoscaleDiscussion(
//                id: UUID(),
//                title: "MD 1823",
//                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk2.html")!,
//                issued: Date().addingTimeInterval(-3600),
//                summary: """
//                     Mesoscale Discussion 1823
//                       NWS Storm Prediction Center Norman OK
//                       0107 PM CDT Mon Jul 28 2025
//
//                       Areas affected...central Montana
//
//                       Concerning...Severe potential...Watch likely 
//
//                       Valid 281807Z - 282000Z
//
//                       Probability of Watch Issuance...80 percent
//
//                       SUMMARY...Thunderstorm development is expected across portions of
//                       central Montana this afternoon by 19-20z, with increasing threat for
//                       large hail and damaging wind.
//
//                       DISCUSSION...Deepening cumulus is observed in visible satellite
//                       across the high terrain in central Montana. MLCIN remains in place
//                       across much of central/western Montana but insolation under mostly
//                       sunny skies should erode this over the next couple of hours. MLCAPE
//                       around 1000 J/kg and deep layer shear around 30-40 kts will support
//                       supercell modes initially. Linear hodographs will support potential
//                       for splitting cells capable of large to very large hail and damaging
//                       wind. Some clustering and building along outflow is likely by the
//                       late afternoon, with potential for increase in the damaging wind
//                       threat. A watch will likely be needed to cover this severe potential
//                       in the next couple of hours.
//
//                       ..Thornton/Thompson.. 07/28/2025
//
//                       ...Please see www.spc.noaa.gov for graphic product...
//
//                       ATTN...WFO...BYZ...GGW...TFX...
//
//                       LAT...LON   46441136 46761221 47041239 47441240 47691208 47991054
//                                   48011017 48080908 47980781 47500689 46800636 46110655
//                                   45890673 45420788 45690939 45951005 46201081 46441136 
//
//                       MOST PROBABLE PEAK WIND GUST...55-70 MPH
//                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
//                    """,
//                alertType: .mesoscale
//            ),
//            MesoscaleDiscussion(
//                id: UUID(),
//                title: "MD 1895",
//                link: URL(string: "https://www.spc.noaa.gov/products/md/md1895.html")!,
//                issued: Date().addingTimeInterval(-3600),
//                summary: """
//                     Mesoscale Discussion 1895
//                        NWS Storm Prediction Center Norman OK
//                        0525 PM CDT Wed Aug 06 2025
//
//                        Areas affected...Western SD...northeast WY...and far southeast MT
//
//                        Concerning...Severe potential...Watch unlikely 
//
//                        Valid 062225Z - 070000Z
//
//                        Probability of Watch Issuance...5 percent
//
//                        SUMMARY...An isolated risk of large hail and locally severe gusts
//                        may persist for the next several hours.
//
//                        DISCUSSION...Isolated/cellular thunderstorms are evolving in the
//                        vicinity of the Black Hills, where an axis of middle/upper 50s
//                        dewpoints and diurnal heating have yielded weak surface-based
//                        buoyancy (per modified 18Z UNR and RAP soundings). While buoyancy is
//                        somewhat marginal, an elongated/straight hodograph (around 50 kt of
//                        effective shear) should promote transient convective
//                        organization/supercellular structure. Isolated large hail and
//                        locally severe gusts may accompany any longer-lived cells. However,
//                        minimal large-scale ascent (or even slight midlevel height rises)
//                        should keep the severe risk isolated/localized and brief.
//
//                        ..Weinman/Guyer.. 08/06/2025
//
//                        ...Please see www.spc.noaa.gov for graphic product...
//
//                        ATTN...WFO...UNR...BYZ...
//
//                        LAT...LON   44640241 44240268 44030332 44140411 44370500 44480533
//                                    44700555 44990556 45370523 45570470 45590413 45440325
//                                    45220265 44970240 44640241 
//
//                        MOST PROBABLE PEAK WIND GUST...UP TO 60 MPH
//                        MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
//                    """,
//                alertType: .mesoscale
//            )
        ]
        
        mock.watches = [
            Watch(
                id: UUID(),
                title: "Watch 551",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
                issued: Date(),
                summary: """
                SEL1
                
                URGENT - IMMEDIATE BROADCAST REQUESTED
                Severe Thunderstorm Watch Number 551
                NWS Storm Prediction Center Norman OK
                115 PM MDT Mon Jul 28 2025

                The NWS Storm Prediction Center has issued a

                * Severe Thunderstorm Watch for portions of
                  Central Montana

                * Effective this Monday afternoon and evening from 115 PM until
                  900 PM MDT.

                * Primary threats include...
                  Scattered large hail and isolated very large hail events to 2.5
                    inches in diameter possible
                  Scattered damaging wind gusts to 70 mph possible

                SUMMARY...Scattered thunderstorm development is expected through the
                afternoon, including the potential for a few supercells.  Large hail
                of 1-2.5 inches in diameter will be possible, while severe outflow
                gusts of 60-70 mph will be possible with upscale growth into a
                cluster or two this evening.

                The severe thunderstorm watch area is approximately along and 60
                statute miles north and south of a line from 35 miles northwest of
                Helena MT to 75 miles east of Lewistown MT. For a complete depiction
                of the watch see the associated watch outline update (WOUS64 KWNS
                WOU1).

                PRECAUTIONARY/PREPAREDNESS ACTIONS...

                REMEMBER...A Severe Thunderstorm Watch means conditions are
                favorable for severe thunderstorms in and close to the watch area.
                Persons in these areas should be on the lookout for threatening
                weather conditions and listen for later statements and possible
                warnings. Severe thunderstorms can and occasionally do produce
                tornadoes.

                &&

                OTHER WATCH INFORMATION...CONTINUE...WW 550...

                AVIATION...A few severe thunderstorms with hail surface and aloft to
                2.5 inches. Extreme turbulence and surface wind gusts to 60 knots. A
                few cumulonimbi with maximum tops to 450. Mean storm motion vector
                28020.

                ...Thompson
                """,
                alertType: .watch
            ),
            Watch(
                id: UUID(),
                title: "Watch 550",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk2.html")!,
                issued: Date().addingTimeInterval(-3600),
                summary: """
                     SEL0

                       URGENT - IMMEDIATE BROADCAST REQUESTED
                       Severe Thunderstorm Watch Number 550
                       NWS Storm Prediction Center Norman OK
                       825 AM CDT Mon Jul 28 2025

                       The NWS Storm Prediction Center has issued a

                       * Severe Thunderstorm Watch for portions of 
                         Southwest and south central North Dakota

                       * Effective this Monday morning and afternoon from 825 AM until
                         400 PM CDT.

                       * Primary threats include...
                         Scattered damaging winds and isolated significant gusts to 75
                           mph likely
                         Scattered large hail events to 1.5 inches in diameter possible

                       SUMMARY...A storm cluster in southwest North Dakota will likely
                       persist and spread eastward through the morning and into the
                       afternoon.  Damaging outflow gusts of 60-75 mph will be the main
                       threat, along with large hail up to 1.5 inches in diameter with the
                       strongest embedded storms.

                       The severe thunderstorm watch area is approximately along and 45
                       statute miles north and south of a line from 10 miles south of
                       Dickinson ND to 25 miles south of Jamestown ND. For a complete
                       depiction of the watch see the associated watch outline update
                       (WOUS64 KWNS WOU0).

                       PRECAUTIONARY/PREPAREDNESS ACTIONS...

                       REMEMBER...A Severe Thunderstorm Watch means conditions are
                       favorable for severe thunderstorms in and close to the watch area.
                       Persons in these areas should be on the lookout for threatening
                       weather conditions and listen for later statements and possible
                       warnings. Severe thunderstorms can and occasionally do produce
                       tornadoes.

                       &&

                       AVIATION...A few severe thunderstorms with hail surface and aloft to
                       1.5 inches. Extreme turbulence and surface wind gusts to 65 knots. A
                       few cumulonimbi with maximum tops to 550. Mean storm motion vector
                       28035.

                       ...Thompson
                    """,
                alertType: .watch
            )
        ]
        
        mock.outlooks = [
            ConvectiveOutlook(
                id: UUID(),
                title: "Day 1 Convective Outlook",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
                published: Date(),
                summary: "A SLGT risk of severe thunderstorms exists across the Plains.",
                day: 1,
                riskLevel: "SLGT"
            ),
            ConvectiveOutlook(
                id: UUID(),
                title: "Day 1 Convective Outlook - Update",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk2.html")!,
                published: Date().addingTimeInterval(-3600),
                summary: "An ENH risk of severe storms exists across the Midwest.",
                day: 1,
                riskLevel: "ENH"
            )
        ]

        return mock
    }
}

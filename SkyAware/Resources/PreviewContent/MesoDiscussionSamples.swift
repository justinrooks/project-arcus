//
//  MesoDiscussionSamples.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/14/25.
//

import Foundation

extension MD {
    private static func buildCoords(for location: String) -> [Coordinate2D] {
        let coordinates = MesoGeometry.coordinates(from: location) ?? []
        return coordinates.compactMap(Coordinate2D.init)
    }
    
    static var sampleDiscussions: [MD] {
        [
            MD(
                number: 1893,
                title: "SPC MD 1893",
                link: URL(string:"https://www.spc.noaa.gov/products/md/md1893.html")!,
                issued: Date(),
                validStart: Calendar.current.date(byAdding: .minute, value: 60, to: Date())!,
                validEnd: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                areasAffected: "Western SD, northeast WY, far southeast MT",
                summary: "test",
                concerning: "Concerning...Severe Thunderstorm Watch 580...",
                watchProbability: "5",
                threats: MDThreats(peakWindMPH: 65, hailRangeInches: 2.5, tornadoStrength: "Not expected"),
                coordinates: buildCoords(for: """
                       ATTN...WFO...BYZ...GGW...TFX...
        
                       LAT...LON   46441136 46761221 47041239 47441240 47691208 47991054
                                   48011017 48080908 47980781 47500689 46800636 46110655
                                   45890673 45420788 45690939 45951005 46201081 46441136
        
                       MOST PROBABLE PEAK WIND GUST...55-70 MPH
                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
        """),
                alertType: .mesoscale
            ),
            MD(
                number: 1913,
                title: "SPC MD 1913",
                link: URL(string:"https://www.spc.noaa.gov/products/md/md1913.html")!,
                issued: Date(),
                validStart: Calendar.current.date(byAdding: .minute, value: 60, to: Date())!,
                validEnd: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                areasAffected: "Western SD, northeast WY, far southeast MT",
                summary: """
                    Mesoscale Discussion 1824
                       NWS Storm Prediction Center Norman OK
                       0247 PM CDT Mon Jul 28 2025
                            Areas affected...parts of south central and southeastern South
                       Dakota...adjacent north central Nebraska
                            Concerning...Severe Thunderstorm Watch 580...
                            Valid 281947Z - 282145Z
                            Probability of Watch Issuance...60 percent
                            SUMMARY...Scattered, intensifying thunderstorm development, posing a
                       risk for a few strong downbursts and perhaps some hail, appears
                       possible by 4-6 PM CDT.  Timing of a potential severe weather watch
                       issuance remains unclear, but trends are being monitored for this
                       possibility.
                            DISCUSSION...A surface cold front, now advancing south of Pierre,
                       Philip and Rapid City is becoming better defined, with strengthening
                       differential heating along and ahead of it, centered near the
                       western South Dakota/Nebraska state border northeastward across the
                       Winner toward Huron vicinities.  While temperatures are approaching
                       100 F within the corridor of stronger boundary-layer heating,
                       surface dew points have been slower to mix below 70F, and through
                       the 60s F, than suggested by model forecast soundings at Winner and
                       Valentine.  Even so, latest objective analysis suggests that the
                       pre- and post-cold frontal boundary layer remains strongly capped
                       beneath the warm and elevated mixed-layer air as far north as the
                       North/South Dakota state border vicinity.
                            Mid/upper support for sustained boundary-layer based convection
                       anytime soon remains unclear, although it appears possible that a
                       subtle perturbation progressing across and east-northeast of the
                       Black Hills is contributing to ongoing attempts at convective
                       development.  It appears more probable that with further insolation,
                       continued heating and deeper mixing within the pre-frontal
                       boundary-layer may eventually support intensifying, high-based
                       thunderstorm development late this afternoon.  In the presence of
                       strong deep-layer shear, this activity could pose a risk for severe
                       hail and increasing potential for strong downbursts into early
                       evening.
                            ..Kerr/Thompson.. 07/28/2025
                            ...Please see www.spc.noaa.gov for graphic product...
                            ATTN...WFO...FSD...ABR...LBF...UNR...
                            LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
                                   42500075 43370091
                            MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
                       MOST PROBABLE PEAK WIND GUST...65-80 MPH
                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
                    """,
                concerning: "Concerning...Severe Thunderstorm Watch 580...",
                watchProbability: "20",
                threats: MDThreats(peakWindMPH: 70, hailRangeInches: 3.5, tornadoStrength: "Up to 95mph"),
                coordinates: buildCoords(for: """
                       ATTN...WFO...LBF...DDC...GLD...PUB...BOU...CYS...
        
                          LAT...LON   38960506 39710477 40880364 41480236 41210180 40690124
                                      40250073 39950055 38790042 37700066 37210280 37620395
                                      38260476 38960506 
        
                          MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
                          MOST PROBABLE PEAK WIND GUST...55-70 MPH
                          MOST PROBABLE PEAK HAIL SIZE...2.00-3.50 IN
        """),
                alertType: .mesoscale
            )
            
            
            //            MD(
            //                number: 1894,
            //                title: "test",
            //                link: URL(string:"https://www.spc.noaa.gov/products/md/md1894.html")!,
            //                issued: Date(),
            //                validStart: Calendar.current.date(byAdding: .minute, value: 90, to: Date())!,
            //                validEnd: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!,
            //                areasAffected: "Western ID, northwest WY, far southwest MT",
            //                summary: "test",
            //                concerning: "Severe potential… Watch likely",
            //                watchProbability: "5%",
            //                threats: MDThreats(peakWindMPH: 60, hailRangeInches: 1.5...5.5, tornadoStrength: "95 MPH"),
            //                coordinates: MesoGeometry.coordinates(from: """
            //                            ATTN...WFO...UNR...BYZ...
            //
            //                            LAT...LON   44640241 44240268 44030332 44140411 44370500 44480533
            //                                        44700555 44990556 45370523 45570470 45590413 45440325
            //                                        45220265 44970240 44640241
            //
            //                            MOST PROBABLE PEAK WIND GUST...UP TO 60 MPH
            //                            MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
            //            """) ?? [],
            //                alertType: .mesoscale
            //            ),
            //            MD(
            //                number: 1895,
            //                title: "test",
            //                link: URL(string:"https://www.spc.noaa.gov/products/md/md1895.html")!,
            //                issued: Date(),
            //                validStart: Calendar.current.date(byAdding: .minute, value: 120, to: Date())!,
            //                validEnd: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!,
            //                areasAffected: "Western SD, northeast WY, far southeast MT",
            //                summary: "test",
            //                concerning: "Severe potential… Watch unlikely",
            //                watchProbability: "15%",
            //                threats: MDThreats(peakWindMPH: 63, hailRangeInches: 1.0...4.5, tornadoStrength: "Not expected"),
            //                coordinates: MesoGeometry.coordinates(from: """
            //                       ATTN...WFO...FSD...ABR...LBF...UNR...
            //
            //                       LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
            //                                   42500075 43370091
            //
            //                       MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
            //                       MOST PROBABLE PEAK WIND GUST...65-80 MPH
            //                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
            //
            //            """) ?? [],
            //                alertType: .mesoscale
            //            )
            //            ,
            //            MD(
            //                title: "MD 1824",
            //                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
            //                issued: Date(),
            //                summary: """
            //                            Mesoscale Discussion 1824
            //                               NWS Storm Prediction Center Norman OK
            //                               0247 PM CDT Mon Jul 28 2025
            //
            //                               Areas affected...parts of south central and southeastern South
            //                               Dakota...adjacent north central Nebraska
            //
            //                               Concerning...Severe Thunderstorm Watch 580...
            //
            //                               Valid 281947Z - 282145Z
            //
            //                               Probability of Watch Issuance...60 percent
            //
            //                               SUMMARY...Scattered, intensifying thunderstorm development, posing a
            //                               risk for a few strong downbursts and perhaps some hail, appears
            //                               possible by 4-6 PM CDT.  Timing of a potential severe weather watch
            //                               issuance remains unclear, but trends are being monitored for this
            //                               possibility.
            //
            //                               DISCUSSION...A surface cold front, now advancing south of Pierre,
            //                               Philip and Rapid City is becoming better defined, with strengthening
            //                               differential heating along and ahead of it, centered near the
            //                               western South Dakota/Nebraska state border northeastward across the
            //                               Winner toward Huron vicinities.  While temperatures are approaching
            //                               100 F within the corridor of stronger boundary-layer heating,
            //                               surface dew points have been slower to mix below 70F, and through
            //                               the 60s F, than suggested by model forecast soundings at Winner and
            //                               Valentine.  Even so, latest objective analysis suggests that the
            //                               pre- and post-cold frontal boundary layer remains strongly capped
            //                               beneath the warm and elevated mixed-layer air as far north as the
            //                               North/South Dakota state border vicinity.
            //
            //                               Mid/upper support for sustained boundary-layer based convection
            //                               anytime soon remains unclear, although it appears possible that a
            //                               subtle perturbation progressing across and east-northeast of the
            //                               Black Hills is contributing to ongoing attempts at convective
            //                               development.  It appears more probable that with further insolation,
            //                               continued heating and deeper mixing within the pre-frontal
            //                               boundary-layer may eventually support intensifying, high-based
            //                               thunderstorm development late this afternoon.  In the presence of
            //                               strong deep-layer shear, this activity could pose a risk for severe
            //                               hail and increasing potential for strong downbursts into early
            //                               evening.
            //
            //                               ..Kerr/Thompson.. 07/28/2025
            //
            //                               ...Please see www.spc.noaa.gov for graphic product...
            //
            //                               ATTN...WFO...FSD...ABR...LBF...UNR...
            //
            //                               LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
            //                                           42500075 43370091
            //
            //                               MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
            //                               MOST PROBABLE PEAK WIND GUST...65-80 MPH
            //                               MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
            //                            """,
            //                alertType: .mesoscale
            //            )
        ]
    }
    
    static var sampleDiscussionDTOs: [MdDTO] {
        [
            MdDTO(
                number: 1893,
                title: "SPC MD 1893",
                link: URL(string:"https://www.spc.noaa.gov/products/md/md1893.html")!,
                issued: Date(),
                validStart: Calendar.current.date(byAdding: .minute, value: 60, to: Date())!,
                validEnd: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                areasAffected: "Western SD, northeast WY, far southeast MT",
                summary: "test",
                concerning: "Concerning...Severe Thunderstorm Watch 580...",
                watchProbability: "5",
                threats: MDThreats(peakWindMPH: 65, hailRangeInches: 2.5, tornadoStrength: nil),
                coordinates: buildCoords(for: """
                       ATTN...WFO...BYZ...GGW...TFX...
        
                       LAT...LON   46441136 46761221 47041239 47441240 47691208 47991054
                                   48011017 48080908 47980781 47500689 46800636 46110655
                                   45890673 45420788 45690939 45951005 46201081 46441136
        
                       MOST PROBABLE PEAK WIND GUST...55-70 MPH
                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
        """)
            ),
            MdDTO(
                number: 1913,
                title: "SPC MD 1913",
                link: URL(string:"https://www.spc.noaa.gov/products/md/md1913.html")!,
                issued: Date(),
                validStart: Calendar.current.date(byAdding: .minute, value: 60, to: Date())!,
                validEnd: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                areasAffected: "Western SD, northeast WY, far southeast MT",
                summary: """
                    Mesoscale Discussion 1824
                       NWS Storm Prediction Center Norman OK
                       0247 PM CDT Mon Jul 28 2025
                            Areas affected...parts of south central and southeastern South
                       Dakota...adjacent north central Nebraska
                            Concerning...Severe Thunderstorm Watch 580...
                            Valid 281947Z - 282145Z
                            Probability of Watch Issuance...60 percent
                            SUMMARY...Scattered, intensifying thunderstorm development, posing a
                       risk for a few strong downbursts and perhaps some hail, appears
                       possible by 4-6 PM CDT.  Timing of a potential severe weather watch
                       issuance remains unclear, but trends are being monitored for this
                       possibility.
                            DISCUSSION...A surface cold front, now advancing south of Pierre,
                       Philip and Rapid City is becoming better defined, with strengthening
                       differential heating along and ahead of it, centered near the
                       western South Dakota/Nebraska state border northeastward across the
                       Winner toward Huron vicinities.  While temperatures are approaching
                       100 F within the corridor of stronger boundary-layer heating,
                       surface dew points have been slower to mix below 70F, and through
                       the 60s F, than suggested by model forecast soundings at Winner and
                       Valentine.  Even so, latest objective analysis suggests that the
                       pre- and post-cold frontal boundary layer remains strongly capped
                       beneath the warm and elevated mixed-layer air as far north as the
                       North/South Dakota state border vicinity.
                            Mid/upper support for sustained boundary-layer based convection
                       anytime soon remains unclear, although it appears possible that a
                       subtle perturbation progressing across and east-northeast of the
                       Black Hills is contributing to ongoing attempts at convective
                       development.  It appears more probable that with further insolation,
                       continued heating and deeper mixing within the pre-frontal
                       boundary-layer may eventually support intensifying, high-based
                       thunderstorm development late this afternoon.  In the presence of
                       strong deep-layer shear, this activity could pose a risk for severe
                       hail and increasing potential for strong downbursts into early
                       evening.
                            ..Kerr/Thompson.. 07/28/2025
                            ...Please see www.spc.noaa.gov for graphic product...
                            ATTN...WFO...FSD...ABR...LBF...UNR...
                            LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
                                   42500075 43370091
                            MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
                       MOST PROBABLE PEAK WIND GUST...65-80 MPH
                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
                    """,
                concerning: "Concerning...Severe Thunderstorm Watch 580...",
                watchProbability: "20",
                threats: MDThreats(peakWindMPH: 70, hailRangeInches: 3.5, tornadoStrength: "Up to 95mph"),
                coordinates: buildCoords(for: """
                       ATTN...WFO...LBF...DDC...GLD...PUB...BOU...CYS...
        
                          LAT...LON   38960506 39710477 40880364 41480236 41210180 40690124
                                      40250073 39950055 38790042 37700066 37210280 37620395
                                      38260476 38960506 
        
                          MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
                          MOST PROBABLE PEAK WIND GUST...55-70 MPH
                          MOST PROBABLE PEAK HAIL SIZE...2.00-3.50 IN
        """)
            )
        ]
    }
}
//
//mock.meso = [
////            MesoscaleDiscussion(
////                id: UUID(),
////                title: "MD 1824",
////                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
////                issued: Date(),
////                summary: """
////                Mesoscale Discussion 1824
////                   NWS Storm Prediction Center Norman OK
////                   0247 PM CDT Mon Jul 28 2025
////
////                   Areas affected...parts of south central and southeastern South
////                   Dakota...adjacent north central Nebraska
////
////                   Concerning...Severe Thunderstorm Watch 580...
////
////                   Valid 281947Z - 282145Z
////
////                   Probability of Watch Issuance...60 percent
////
////                   SUMMARY...Scattered, intensifying thunderstorm development, posing a
////                   risk for a few strong downbursts and perhaps some hail, appears
////                   possible by 4-6 PM CDT.  Timing of a potential severe weather watch
////                   issuance remains unclear, but trends are being monitored for this
////                   possibility.
////
////                   DISCUSSION...A surface cold front, now advancing south of Pierre,
////                   Philip and Rapid City is becoming better defined, with strengthening
////                   differential heating along and ahead of it, centered near the
////                   western South Dakota/Nebraska state border northeastward across the
////                   Winner toward Huron vicinities.  While temperatures are approaching
////                   100 F within the corridor of stronger boundary-layer heating,
////                   surface dew points have been slower to mix below 70F, and through
////                   the 60s F, than suggested by model forecast soundings at Winner and
////                   Valentine.  Even so, latest objective analysis suggests that the
////                   pre- and post-cold frontal boundary layer remains strongly capped
////                   beneath the warm and elevated mixed-layer air as far north as the
////                   North/South Dakota state border vicinity.
////
////                   Mid/upper support for sustained boundary-layer based convection
////                   anytime soon remains unclear, although it appears possible that a
////                   subtle perturbation progressing across and east-northeast of the
////                   Black Hills is contributing to ongoing attempts at convective
////                   development.  It appears more probable that with further insolation,
////                   continued heating and deeper mixing within the pre-frontal
////                   boundary-layer may eventually support intensifying, high-based
////                   thunderstorm development late this afternoon.  In the presence of
////                   strong deep-layer shear, this activity could pose a risk for severe
////                   hail and increasing potential for strong downbursts into early
////                   evening.
////
////                   ..Kerr/Thompson.. 07/28/2025
////
////                   ...Please see www.spc.noaa.gov for graphic product...
////
////                   ATTN...WFO...FSD...ABR...LBF...UNR...
////
////                   LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
////                               42500075 43370091
////
////                   MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
////                   MOST PROBABLE PEAK WIND GUST...65-80 MPH
////                   MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
////                """,
////                alertType: .mesoscale
////            ),
////            MesoscaleDiscussion(
////                id: UUID(),
////                title: "MD 1823",
////                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk2.html")!,
////                issued: Date().addingTimeInterval(-3600),
////                summary: """
////                     Mesoscale Discussion 1823
////                       NWS Storm Prediction Center Norman OK
////                       0107 PM CDT Mon Jul 28 2025
////
////                       Areas affected...central Montana
////
////                       Concerning...Severe potential...Watch likely
////
////                       Valid 281807Z - 282000Z
////
////                       Probability of Watch Issuance...80 percent
////
////                       SUMMARY...Thunderstorm development is expected across portions of
////                       central Montana this afternoon by 19-20z, with increasing threat for
////                       large hail and damaging wind.
////
////                       DISCUSSION...Deepening cumulus is observed in visible satellite
////                       across the high terrain in central Montana. MLCIN remains in place
////                       across much of central/western Montana but insolation under mostly
////                       sunny skies should erode this over the next couple of hours. MLCAPE
////                       around 1000 J/kg and deep layer shear around 30-40 kts will support
////                       supercell modes initially. Linear hodographs will support potential
////                       for splitting cells capable of large to very large hail and damaging
////                       wind. Some clustering and building along outflow is likely by the
////                       late afternoon, with potential for increase in the damaging wind
////                       threat. A watch will likely be needed to cover this severe potential
////                       in the next couple of hours.
////
////                       ..Thornton/Thompson.. 07/28/2025
////
////                       ...Please see www.spc.noaa.gov for graphic product...
////
////                       ATTN...WFO...BYZ...GGW...TFX...
////
////                       LAT...LON   46441136 46761221 47041239 47441240 47691208 47991054
////                                   48011017 48080908 47980781 47500689 46800636 46110655
////                                   45890673 45420788 45690939 45951005 46201081 46441136
////
////                       MOST PROBABLE PEAK WIND GUST...55-70 MPH
////                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
////                    """,
////                alertType: .mesoscale
////            ),
////            MesoscaleDiscussion(
////                id: UUID(),
////                title: "MD 1895",
////                link: URL(string: "https://www.spc.noaa.gov/products/md/md1895.html")!,
////                issued: Date().addingTimeInterval(-3600),
////                summary: """
////                     Mesoscale Discussion 1895
////                        NWS Storm Prediction Center Norman OK
////                        0525 PM CDT Wed Aug 06 2025
////
////                        Areas affected...Western SD...northeast WY...and far southeast MT
////
////                        Concerning...Severe potential...Watch unlikely
////
////                        Valid 062225Z - 070000Z
////
////                        Probability of Watch Issuance...5 percent
////
////                        SUMMARY...An isolated risk of large hail and locally severe gusts
////                        may persist for the next several hours.
////
////                        DISCUSSION...Isolated/cellular thunderstorms are evolving in the
////                        vicinity of the Black Hills, where an axis of middle/upper 50s
////                        dewpoints and diurnal heating have yielded weak surface-based
////                        buoyancy (per modified 18Z UNR and RAP soundings). While buoyancy is
////                        somewhat marginal, an elongated/straight hodograph (around 50 kt of
////                        effective shear) should promote transient convective
////                        organization/supercellular structure. Isolated large hail and
////                        locally severe gusts may accompany any longer-lived cells. However,
////                        minimal large-scale ascent (or even slight midlevel height rises)
////                        should keep the severe risk isolated/localized and brief.
////
////                        ..Weinman/Guyer.. 08/06/2025
////
////                        ...Please see www.spc.noaa.gov for graphic product...
////
////                        ATTN...WFO...UNR...BYZ...
////
////                        LAT...LON   44640241 44240268 44030332 44140411 44370500 44480533
////                                    44700555 44990556 45370523 45570470 45590413 45440325
////                                    45220265 44970240 44640241
////
////                        MOST PROBABLE PEAK WIND GUST...UP TO 60 MPH
////                        MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
////                    """,
////                alertType: .mesoscale
////            )
//]


//[
//    MesoscaleDiscussion(
//        id: UUID(),
//        number: 1893,
//        title: "test",
//        link: URL(string:"https://www.spc.noaa.gov/products/md/md1893.html")!,
//        issued: Date(),
//        validStart: Calendar.current.date(byAdding: .minute, value: 60, to: Date())!,
//        validEnd: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
//        areasAffected: "Western SD, northeast WY, far southeast MT",
//        summary: "test",
//        concerning: "Concerning...Severe Thunderstorm Watch 580...",
//        watchProbability: .percent(5),
//        threats: MDThreats(peakWindMPH: 65, hailRangeInches: 1.5...2.5, tornadoStrength: "Not expected"),
//        coordinates: MesoGeometry.coordinates(from: """
//                           ATTN...WFO...BYZ...GGW...TFX...
//
//                           LAT...LON   46441136 46761221 47041239 47441240 47691208 47991054
//                                       48011017 48080908 47980781 47500689 46800636 46110655
//                                       45890673 45420788 45690939 45951005 46201081 46441136
//
//                           MOST PROBABLE PEAK WIND GUST...55-70 MPH
//                           MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
//    """) ?? [],
//        alertType: .mesoscale
//    ),
//    MesoscaleDiscussion(
//        id: UUID(),
//        number: 1894,
//        title: "test",
//        link: URL(string:"https://www.spc.noaa.gov/products/md/md1894.html")!,
//        issued: Date(),
//        validStart: Calendar.current.date(byAdding: .minute, value: 90, to: Date())!,
//        validEnd: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!,
//        areasAffected: "Western ID, northwest WY, far southwest MT",
//        summary: "test",
//        concerning: "Severe potential… Watch likely",
//        watchProbability: .percent(5),
//        threats: MDThreats(peakWindMPH: 60, hailRangeInches: 1.5...5.5, tornadoStrength: "95 MPH"),
//        coordinates: MesoGeometry.coordinates(from: """
//                            ATTN...WFO...UNR...BYZ...
//
//                            LAT...LON   44640241 44240268 44030332 44140411 44370500 44480533
//                                        44700555 44990556 45370523 45570470 45590413 45440325
//                                        45220265 44970240 44640241
//
//                            MOST PROBABLE PEAK WIND GUST...UP TO 60 MPH
//                            MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
//    """) ?? [],
//        alertType: .mesoscale
//    ),
//    MesoscaleDiscussion(
//        id: UUID(),
//        number: 1895,
//        title: "test",
//        link: URL(string:"https://www.spc.noaa.gov/products/md/md1895.html")!,
//        issued: Date(),
//        validStart: Calendar.current.date(byAdding: .minute, value: 120, to: Date())!,
//        validEnd: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!,
//        areasAffected: "Western SD, northeast WY, far southeast MT",
//        summary: "test",
//        concerning: "Severe potential… Watch unlikely",
//        watchProbability: .percent(15),
//        threats: MDThreats(peakWindMPH: nil, hailRangeInches: 1.0...4.5, tornadoStrength: nil),
//        coordinates: MesoGeometry.coordinates(from: """
//                       ATTN...WFO...FSD...ABR...LBF...UNR...
//
//                       LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
//                                   42500075 43370091
//
//                       MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
//                       MOST PROBABLE PEAK WIND GUST...65-80 MPH
//                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
//    """) ?? [],
//        alertType: .mesoscale
//    ),
//    MesoscaleDiscussion(
//        id: UUID(),
//        number: 1896,
//        title: "test",
//        link: URL(string:"https://www.spc.noaa.gov/products/md/md1896.html")!,
//        issued: Date(),
//        validStart: Calendar.current.date(byAdding: .minute, value: 120, to: Date())!,
//        validEnd: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!,
//        areasAffected: "Western SD, northeast WY, far southeast MT",
//        summary: "test",
//        concerning: "Severe potential… Watch unlikely",
//        watchProbability: .percent(45),
//        threats: MDThreats(peakWindMPH: 63, hailRangeInches: nil, tornadoStrength: "Not expected"),
//        coordinates: MesoGeometry.coordinates(from: """
//                       ATTN...WFO...FSD...ABR...LBF...UNR...
//
//                       LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
//                                   42500075 43370091
//
//                       MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
//                       MOST PROBABLE PEAK WIND GUST...65-80 MPH
//                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
//    """) ?? [],
//        alertType: .mesoscale
//    )
//]

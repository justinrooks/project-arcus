//
//  ConvectiveOutlookSamples.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/13/25.
//

import Foundation

extension ConvectiveOutlook {
    static var sampleOutlooks: [ConvectiveOutlook] {
        [
            ConvectiveOutlook(
                title: "SPC Sep 13, 2025 1630 UTC Day 1 Convective Outlook",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
                published: Date(),
                summary: """
                    SPC 1630Z Day 1 Outlook
                          Day 1 Convective Outlook  
                    NWS Storm Prediction Center Norman OK
                    1136 AM CDT Sat Sep 13 2025

                    Valid 131630Z - 141200Z

                    ...THERE IS A SLIGHT RISK OF SEVERE THUNDERSTORMS ACROSS PORTIONS OF
                    NEW MEXICO...

                    ...SUMMARY...
                    Isolated severe wind and hail will be possible from the
                    Southwest/southern Rockies, particularly over parts of New Mexico,
                    into the northern Great Plains and a portion of the Midwest, mainly
                    this afternoon and early evening.

                    ...New Mexico and southern Rockies/High Plains...
                    A prominent upper trough will continue to shift east-northeastward
                    today and tonight over the Four Corners area and south-central
                    Rockies. DPVA/cooling aloft and plentiful moisture preceding the
                    trough will contribute to a relatively high coverage, and
                    potentially multiple rounds, of thunderstorms regionally. The 12z
                    observed sounding from El Paso featured Precipitable Water values in
                    the upper 5-10 percent of daily climatological values. Ongoing
                    thunderstorms/cloud cover will tend to mute diurnal destabilization
                    in areas, but portions of southern/eastern New Mexico may see
                    somewhat more aggressive destabilization pending cloud breaks. Will
                    defer to the ample moisture/coverage of storms and rather favorable
                    deep-layer flow field (40+ kt effective shear) and introduce a
                    categorical Slight Risk for portions of New Mexico, where hail/wind
                    risks, including some supercells, are most probable this afternoon
                    through early evening.

                    ...Northern Plains including NE/SD/ND...
                    It still seems that residual cloud cover/outflow from last night's
                    multiple rounds of thunderstorms will tend to temper destabilization
                    later today within a modestly-sheared environment. Nevertheless,
                    some isolated severe wind/hail potential will exist as storms
                    redevelop across the High Plains later today.

                    ...Midwest including portions of Illinois/Indiana...
                    Overall severe potential should remain relatively limited (or at
                    least highly uncertain), however some redevelopment and/or
                    reintensification could occur across downstate portion of
                    Illinois/Indiana, and/or farther north along the instability
                    gradient across northeast Illinois/Chicagoland vicinity into
                    northwest Indiana, where some air mass recovery is plausible. Will
                    maintain low hail/wind probabilities regionally given some lingering
                    severe potential, on a more conditional/uncertain basis with
                    north-northwestward extent under the increasing influence of the
                    upper ridge.

                    ..Guyer/Supinie.. 09/13/2025
                    """,
                day: 1,
                riskLevel: "SLGT"
            ),
            ConvectiveOutlook(
                title: "SPC Sep 13, 2025 1730 UTC Day 2 Convective Outlook",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day2otlk.html")!,
                published: Date().addingTimeInterval(-3600),
                summary: """
                    SPC 1730Z Day 2 Outlook
                          Day 2 Convective Outlook  
                    NWS Storm Prediction Center Norman OK
                    1229 PM CDT Sat Sep 13 2025

                    Valid 141200Z - 151200Z

                    ...THERE IS A MARGINAL RISK OF SEVERE THUNDERSTORMS FOR PORTIONS OF
                    THE NORTHERN PLAINS EXTENDING INTO THE SOUTHERN HIGH PLAINS...

                    ...SUMMARY...
                    Isolated severe storms are possible across parts of the northern
                    Plains into the southern High Plains tomorrow (Sunday).

                    ...Synopsis...
                    A broad negative tilt trough will eject into the central Plains on
                    Sunday, resulting in a deepening a surface low across the Dakotas.
                    As the surface low deepens, the southerly low-level jet will
                    increase with warm and moist advection from the southern Plains into
                    the northern Plains. 

                    ...Great Plains States...
                    The broad area of warm and moist advection will result in widespread
                    shower/thunderstorm activity ongoing at the start of the period
                    Sunday morning. In the wake of this morning convection, extensive
                    cloud cover is expected to cover much of the region from the central
                    Plains into the northern Plains. Some breaks in the cloud cover may
                    allow for pockets of heating and recovery, but it remains uncertain
                    how much air mass recovery will be achieved. Forecast soundings
                    indicate tall skinny CAPE profiles and modest lapse rates (6-7 C/km)
                    which may produce narrow updrafts that struggle to maintain
                    intensity.

                    Nonetheless, sufficient deep layer shear around 30-40 knots will
                    support potential for a few organized storms to develop where
                    recovery occurs, with development of multi-cell clusters and perhaps
                    a few supercells. A narrow Marginal Risk was maintained across the
                    Plains where redevelopment is most likely to start in the northern
                    Plains and spread southward through the afternoon/evening. Closer to
                    surface low across the Dakotas and on the nose of the low-level jet
                    axis, a conditional risk for a tornado is possible if a supercell
                    can be maintained. Overall, the main risks will be for sporadic
                    strong to severe wind and hail.

                    ..Thornton.. 09/13/2025
                    """,
                day: 2,
                riskLevel: "SLGT"
            ),
        ]
    }
}

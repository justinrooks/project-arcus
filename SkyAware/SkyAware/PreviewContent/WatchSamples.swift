//
//  WatchSamples.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/15/25.
//

import Foundation

extension WatchModel {
    static var sampleWatches: [WatchModel] {
        [
            WatchModel(
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
            WatchModel(
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
    }
}


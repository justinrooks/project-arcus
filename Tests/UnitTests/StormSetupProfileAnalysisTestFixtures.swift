import Foundation

enum StormSetupProfileAnalysisTestFixtures {
    static let richJSON = #"""
    {
      "request": {
        "runTime": "2026-06-01T18:00:00Z",
        "validTime": "2026-06-01T21:00:00Z",
        "forecastHour": 3,
        "profile": [
          {
            "pressureMb": 925,
            "temperatureC": 24.5
          }
        ],
        "location": {
          "latitude": 39.5,
          "longitude": -100.0
        },
        "debug": {
          "pressureLevels": [
            1000,
            925
          ],
          "downloadDiagnostics": {
            "source": "ignored"
          }
        }
      },
      "response": {
        "mlcape": 1.85e3,
        "mucape": 2200.5,
        "mlcin": -42,
        "mllclMetersAgl": -0.0,
        "scp": 0.7,
        "stpFixed": 1.2,
        "stpCin": 0.9,
        "ship": 2.1,
        "effectiveSrh": 1.35e2,
        "effectiveBulkShearMs": 24.5,
        "effectiveLayer": {
          "status": "available",
          "basePressureMb": 915,
          "topPressureMb": 750,
          "baseMetersAgl": 850,
          "topMetersAgl": 1800
        },
        "stormMotion": {
          "status": "available",
          "bunkersRight": {
            "uMs": 8.4,
            "vMs": -4.2,
            "speedMs": 9.4,
            "uKt": 16.3,
            "vKt": -8.2,
            "speedKt": 18.3,
            "directionTowardDeg": 215
          },
          "uMs": 6.2,
          "vMs": -2.4,
          "speedMs": 6.6,
          "uKt": 12.1,
          "vKt": -4.7,
          "speedKt": 12.8,
          "directionTowardDeg": 201
        },
        "quality": {
          "profileLevelCount": 36,
          "warnings": [
            "profile trimmed",
            "debug ignored"
          ]
        }
      }
    }
    """#

    static let sparseJSON = #"""
    {
      "request": {
        "profile": [
          {
            "pressureMb": 1000,
            "temperatureC": 28.0
          }
        ],
        "location": {
          "latitude": 39.5,
          "longitude": -100.0
        },
        "debug": {
          "pressureLevels": [
            1000
          ],
          "downloadDiagnostics": {
            "source": "ignored"
          }
        }
      },
      "response": {
        "effectiveLayer": {
          "status": "notFound"
        }
      }
    }
    """#
}

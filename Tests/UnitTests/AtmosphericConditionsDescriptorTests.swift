#if canImport(Testing)
import Testing
@testable import SkyAware

@Suite("Atmospheric conditions dew point descriptor")
struct AtmosphericConditionsDescriptorTests {
    @Test("dew points below 50 are dry air")
    func belowFiftyIsDryAir() {
        #expect(DewPointDescriptor.text(for: 49.9) == "Dry air in place")
    }

    @Test("dew points from 50 to 59 are comfortable moisture")
    func fiftyToFiftyNineIsComfortableMoisture() {
        #expect(DewPointDescriptor.text(for: 50.0) == "Comfortable moisture")
        #expect(DewPointDescriptor.text(for: 59.9) == "Comfortable moisture")
    }

    @Test("dew points from 60 to 64 are moisture increasing")
    func sixtyToSixtyFourIsMoistureIncreasing() {
        #expect(DewPointDescriptor.text(for: 60.0) == "Moisture increasing")
        #expect(DewPointDescriptor.text(for: 64.9) == "Moisture increasing")
    }

    @Test("dew points from 65 to 69 are moist air may support storms")
    func sixtyFiveToSixtyNineSupportsStorms() {
        #expect(DewPointDescriptor.text(for: 65.0) == "Moist air may support storms")
        #expect(DewPointDescriptor.text(for: 69.9) == "Moist air may support storms")
    }

    @Test("dew points 70 and above are very moist")
    func seventyAndAboveIsVeryMoist() {
        #expect(DewPointDescriptor.text(for: 70.0) == "Very moist air in place")
        #expect(DewPointDescriptor.text(for: 74.2) == "Very moist air in place")
    }

    @Test("missing dew point returns unavailable text")
    func missingValueReturnsUnavailableText() {
        #expect(DewPointDescriptor.text(for: nil) == "Dew point unavailable")
    }
}
#endif

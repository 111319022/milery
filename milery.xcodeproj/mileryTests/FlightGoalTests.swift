import Testing
import Foundation
@testable import milery

@Suite("FlightGoal Tests")
struct FlightGoalTests {
    
    // MARK: - progress
    
    @Test("Progress is 0 when requiredMiles is 0")
    func progressZeroRequired() {
        let goal = FlightGoal(
            origin: "TPE", destination: "HKG",
            originName: "台北", destinationName: "香港",
            cabinClass: .economy, requiredMiles: 0
        )
        #expect(goal.progress(currentMiles: 1000) == 0)
    }
    
    @Test("Progress is 50% when halfway")
    func progressHalfway() {
        let goal = FlightGoal(
            origin: "TPE", destination: "NRT",
            originName: "台北", destinationName: "東京",
            cabinClass: .economy, requiredMiles: 10000
        )
        #expect(goal.progress(currentMiles: 5000) == 0.5)
    }
    
    @Test("Progress caps at 1.0 (100%)")
    func progressCapsAtOne() {
        let goal = FlightGoal(
            origin: "TPE", destination: "NRT",
            originName: "台北", destinationName: "東京",
            cabinClass: .economy, requiredMiles: 10000
        )
        #expect(goal.progress(currentMiles: 20000) == 1.0)
    }
    
    @Test("Progress is 100% when exactly enough miles")
    func progressExact() {
        let goal = FlightGoal(
            origin: "TPE", destination: "NRT",
            originName: "台北", destinationName: "東京",
            cabinClass: .economy, requiredMiles: 13000
        )
        #expect(goal.progress(currentMiles: 13000) == 1.0)
    }
    
    // MARK: - milesNeeded
    
    @Test("Miles needed when partially funded")
    func milesNeededPartial() {
        let goal = FlightGoal(
            origin: "TPE", destination: "NRT",
            originName: "台北", destinationName: "東京",
            cabinClass: .economy, requiredMiles: 13000
        )
        #expect(goal.milesNeeded(currentMiles: 5000) == 8000)
    }
    
    @Test("Miles needed is 0 when over-funded")
    func milesNeededOverFunded() {
        let goal = FlightGoal(
            origin: "TPE", destination: "HKG",
            originName: "台北", destinationName: "香港",
            cabinClass: .economy, requiredMiles: 7500
        )
        #expect(goal.milesNeeded(currentMiles: 10000) == 0)
    }
    
    @Test("Miles needed is 0 when exactly funded")
    func milesNeededExact() {
        let goal = FlightGoal(
            origin: "TPE", destination: "HKG",
            originName: "台北", destinationName: "香港",
            cabinClass: .economy, requiredMiles: 7500
        )
        #expect(goal.milesNeeded(currentMiles: 7500) == 0)
    }
    
    @Test("Miles needed equals requiredMiles when zero current")
    func milesNeededZeroCurrent() {
        let goal = FlightGoal(
            origin: "TPE", destination: "LHR",
            originName: "台北", destinationName: "倫敦",
            cabinClass: .business, requiredMiles: 88000
        )
        #expect(goal.milesNeeded(currentMiles: 0) == 88000)
    }
    
    // MARK: - Convenience init with IATA codes
    
    @Test("Convenience init calculates correct miles for TPE-HKG economy")
    func convenienceInitTPEHKG() {
        let goal = FlightGoal(
            fromIATA: "TPE", toIATA: "HKG",
            cabinClass: .economy
        )
        #expect(goal.requiredMiles == 7500)
        #expect(goal.origin == "TPE")
        #expect(goal.destination == "HKG")
    }
    
    @Test("Convenience init round trip doubles miles")
    func convenienceInitRoundTrip() {
        let oneWay = FlightGoal(
            fromIATA: "TPE", toIATA: "HKG",
            cabinClass: .economy, isRoundTrip: false
        )
        let roundTrip = FlightGoal(
            fromIATA: "TPE", toIATA: "HKG",
            cabinClass: .economy, isRoundTrip: true
        )
        #expect(roundTrip.requiredMiles == oneWay.requiredMiles * 2)
    }
    
    @Test("Convenience init with unknown airport gives 0 miles")
    func convenienceInitUnknownAirport() {
        let goal = FlightGoal(
            fromIATA: "TPE", toIATA: "XXX",
            cabinClass: .economy
        )
        #expect(goal.requiredMiles == 0)
    }
    
    // MARK: - distanceCategory / isShortHaul2Destination
    
    @Test("NRT destination is short haul 2")
    func nrtIsShortHaul2Destination() {
        let goal = FlightGoal(
            fromIATA: "TPE", toIATA: "NRT", cabinClass: .economy
        )
        #expect(goal.isShortHaul2Destination == true)
    }
    
    @Test("SIN destination is NOT short haul 2")
    func sinIsNotShortHaul2Destination() {
        let goal = FlightGoal(
            fromIATA: "TPE", toIATA: "SIN", cabinClass: .economy
        )
        #expect(goal.isShortHaul2Destination == false)
    }
}

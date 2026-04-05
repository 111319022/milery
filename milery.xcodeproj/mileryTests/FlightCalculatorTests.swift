import Testing
import Foundation
@testable import milery

@Suite("FlightCalculator Tests")
struct FlightCalculatorTests {
    
    // MARK: - determineZone
    
    @Test("Ultra short haul: distance 1-750")
    func ultraShortHaul() {
        let zone = FlightCalculator.determineZone(distance: 500, destinationCode: "HKG")
        #expect(zone == .ultraShortHaul)
    }
    
    @Test("Ultra short haul: boundary at 750")
    func ultraShortHaulUpperBound() {
        let zone = FlightCalculator.determineZone(distance: 750, destinationCode: "HKG")
        #expect(zone == .ultraShortHaul)
    }
    
    @Test("Short haul 1: general Asian city in 751-2750 range")
    func shortHaul1GeneralCity() {
        // ICN (Seoul) is NOT in the shortHaul2Cities list
        let zone = FlightCalculator.determineZone(distance: 1500, destinationCode: "ICN")
        #expect(zone == .shortHaul1)
    }
    
    @Test("Short haul 2: Japanese city in 751-2750 range")
    func shortHaul2JapaneseCity() {
        // NRT (Tokyo Narita) IS in the shortHaul2Cities list
        let zone = FlightCalculator.determineZone(distance: 1300, destinationCode: "NRT")
        #expect(zone == .shortHaul2)
    }
    
    @Test("Short haul 2: case insensitive destination code")
    func shortHaul2CaseInsensitive() {
        let zone = FlightCalculator.determineZone(distance: 1300, destinationCode: "nrt")
        #expect(zone == .shortHaul2)
    }
    
    @Test("Short haul boundary: 751 is short haul, not ultra short")
    func shortHaulLowerBound() {
        let zone = FlightCalculator.determineZone(distance: 751, destinationCode: "BKK")
        #expect(zone == .shortHaul1)
    }
    
    @Test("Short haul boundary: 2750 is still short haul")
    func shortHaulUpperBound() {
        let zone = FlightCalculator.determineZone(distance: 2750, destinationCode: "SIN")
        #expect(zone == .shortHaul1)
    }
    
    @Test("Medium haul: 2751-5000")
    func mediumHaul() {
        let zone = FlightCalculator.determineZone(distance: 3500, destinationCode: "SYD")
        #expect(zone == .mediumHaul)
    }
    
    @Test("Medium haul boundary: 2751")
    func mediumHaulLowerBound() {
        let zone = FlightCalculator.determineZone(distance: 2751, destinationCode: "DEL")
        #expect(zone == .mediumHaul)
    }
    
    @Test("Long haul: 5001-7500")
    func longHaul() {
        let zone = FlightCalculator.determineZone(distance: 6000, destinationCode: "LHR")
        #expect(zone == .longHaul)
    }
    
    @Test("Ultra long haul: 7501+")
    func ultraLongHaul() {
        let zone = FlightCalculator.determineZone(distance: 8000, destinationCode: "JFK")
        #expect(zone == .ultraLongHaul)
    }
    
    @Test("Ultra long haul: very large distance")
    func ultraLongHaulLargeDistance() {
        let zone = FlightCalculator.determineZone(distance: 12000, destinationCode: "LAX")
        #expect(zone == .ultraLongHaul)
    }
    
    // MARK: - requiredMiles
    
    @Test("Ultra short haul economy: 7500 miles")
    func ultraShortHaulEconomyMiles() {
        let miles = FlightCalculator.requiredMiles(zone: .ultraShortHaul, cabinClass: .economy)
        #expect(miles == 7500)
    }
    
    @Test("Ultra short haul first class: nil (not available)")
    func ultraShortHaulFirstNil() {
        let miles = FlightCalculator.requiredMiles(zone: .ultraShortHaul, cabinClass: .first)
        #expect(miles == nil)
    }
    
    @Test("Short haul 1 economy: 9000 miles")
    func shortHaul1EconomyMiles() {
        let miles = FlightCalculator.requiredMiles(zone: .shortHaul1, cabinClass: .economy)
        #expect(miles == 9000)
    }
    
    @Test("Short haul 2 economy: 13000 miles (more expensive than short haul 1)")
    func shortHaul2EconomyMiles() {
        let miles = FlightCalculator.requiredMiles(zone: .shortHaul2, cabinClass: .economy)
        #expect(miles == 13000)
    }
    
    @Test("Short haul 2 is always more expensive than short haul 1 for same cabin")
    func shortHaul2MoreExpensiveThanShortHaul1() {
        for cabin in CabinClass.allCases {
            let sh1 = FlightCalculator.requiredMiles(zone: .shortHaul1, cabinClass: cabin)
            let sh2 = FlightCalculator.requiredMiles(zone: .shortHaul2, cabinClass: cabin)
            guard let m1 = sh1, let m2 = sh2 else { continue }
            #expect(m2 > m1, "Short haul 2 should cost more than short haul 1 for \(cabin)")
        }
    }
    
    @Test("Long haul business: 88000 miles")
    func longHaulBusinessMiles() {
        let miles = FlightCalculator.requiredMiles(zone: .longHaul, cabinClass: .business)
        #expect(miles == 88000)
    }
    
    @Test("Ultra long haul first: 160000 miles")
    func ultraLongHaulFirstMiles() {
        let miles = FlightCalculator.requiredMiles(zone: .ultraLongHaul, cabinClass: .first)
        #expect(miles == 160000)
    }
    
    // MARK: - isShortHaul2City
    
    @Test("NRT is a short haul 2 city")
    func nrtIsShortHaul2() {
        #expect(FlightCalculator.isShortHaul2City("NRT") == true)
    }
    
    @Test("HKG is NOT a short haul 2 city")
    func hkgIsNotShortHaul2() {
        #expect(FlightCalculator.isShortHaul2City("HKG") == false)
    }
    
    @Test("PUS (Busan) is a short haul 2 city")
    func pusIsShortHaul2() {
        #expect(FlightCalculator.isShortHaul2City("PUS") == true)
    }
    
    @Test("Case insensitive short haul 2 check")
    func caseInsensitiveShortHaul2() {
        #expect(FlightCalculator.isShortHaul2City("kix") == true)
    }
    
    // MARK: - isCathayRouteFromTPE
    
    @Test("HKG is a Cathay route from TPE")
    func hkgIsCathayRoute() {
        #expect(FlightCalculator.isCathayRouteFromTPE(destination: "HKG") == true)
    }
    
    @Test("NRT is a Cathay route from TPE")
    func nrtIsCathayRoute() {
        #expect(FlightCalculator.isCathayRouteFromTPE(destination: "NRT") == true)
    }
    
    @Test("JFK is NOT a Cathay route from TPE")
    func jfkIsNotCathayRoute() {
        #expect(FlightCalculator.isCathayRouteFromTPE(destination: "JFK") == false)
    }
    
    // MARK: - calculateRequiredMiles (integration)
    
    @Test("TPE to HKG economy uses airport database distance")
    func tpeToHkgEconomy() {
        let miles = FlightCalculator.calculateRequiredMiles(
            from: "TPE", to: "HKG", cabinClass: .economy
        )
        // TPE-HKG is ~500 miles = ultra short haul = 7500 economy
        #expect(miles == 7500)
    }
    
    @Test("TPE to NRT economy should be short haul 2")
    func tpeToNrtEconomy() {
        let miles = FlightCalculator.calculateRequiredMiles(
            from: "TPE", to: "NRT", cabinClass: .economy
        )
        // NRT is a short haul 2 city, TPE-NRT ~1300 miles
        #expect(miles == 13000)
    }
    
    @Test("Unknown airport returns nil")
    func unknownAirportReturnsNil() {
        let miles = FlightCalculator.calculateRequiredMiles(
            from: "TPE", to: "XXX", cabinClass: .economy
        )
        #expect(miles == nil)
    }
}

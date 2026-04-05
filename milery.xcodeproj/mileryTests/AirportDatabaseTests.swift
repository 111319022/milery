import Testing
import Foundation
@testable import milery

@Suite("AirportDatabase Tests")
struct AirportDatabaseTests {
    
    let db = AirportDatabase.shared
    
    // MARK: - getAirport
    
    @Test("Can look up TPE by IATA code")
    func lookupTPE() {
        let airport = db.getAirport(iataCode: "TPE")
        #expect(airport != nil)
        #expect(airport?.cityName == "台北")
        #expect(airport?.iataCode == "TPE")
    }
    
    @Test("Lookup is case insensitive")
    func lookupCaseInsensitive() {
        let airport = db.getAirport(iataCode: "tpe")
        #expect(airport != nil)
        #expect(airport?.iataCode == "TPE")
    }
    
    @Test("Unknown IATA code returns nil")
    func lookupUnknown() {
        let airport = db.getAirport(iataCode: "XXX")
        #expect(airport == nil)
    }
    
    // MARK: - calculateDistance
    
    @Test("TPE to HKG is approximately 500 miles (ultra short haul)")
    func distanceTPEHKG() {
        let distance = db.calculateDistance(from: "TPE", to: "HKG")
        #expect(distance != nil)
        // Should be around 500 miles; check within a reasonable range
        if let d = distance {
            #expect(d >= 400 && d <= 600, "TPE-HKG distance \(d) should be ~500 miles")
        }
    }
    
    @Test("TPE to NRT is approximately 1300 miles (short haul)")
    func distanceTPENRT() {
        let distance = db.calculateDistance(from: "TPE", to: "NRT")
        #expect(distance != nil)
        if let d = distance {
            #expect(d >= 1200 && d <= 1500, "TPE-NRT distance \(d) should be ~1300 miles")
        }
    }
    
    @Test("TPE to LHR is approximately 6000 miles (long haul)")
    func distanceTPELHR() {
        let distance = db.calculateDistance(from: "TPE", to: "LHR")
        #expect(distance != nil)
        if let d = distance {
            #expect(d >= 5500 && d <= 6500, "TPE-LHR distance \(d) should be ~6000 miles")
        }
    }
    
    @Test("Distance with unknown airport returns nil")
    func distanceUnknownAirport() {
        let distance = db.calculateDistance(from: "TPE", to: "XXX")
        #expect(distance == nil)
    }
    
    @Test("Distance is symmetric (A→B == B→A)")
    func distanceSymmetric() {
        let ab = db.calculateDistance(from: "TPE", to: "NRT")
        let ba = db.calculateDistance(from: "NRT", to: "TPE")
        #expect(ab == ba)
    }
    
    @Test("Distance to self is 0")
    func distanceToSelf() {
        let distance = db.calculateDistance(from: "TPE", to: "TPE")
        #expect(distance == 0)
    }
    
    // MARK: - searchAirports
    
    @Test("Search by IATA code finds airport")
    func searchByIATA() {
        let results = db.searchAirports(query: "NRT")
        #expect(results.contains { $0.iataCode == "NRT" })
    }
    
    @Test("Search by city name finds airport")
    func searchByCityName() {
        let results = db.searchAirports(query: "東京")
        #expect(results.contains { $0.iataCode == "NRT" })
        #expect(results.contains { $0.iataCode == "HND" })
    }
    
    @Test("Search by English city name finds airport")
    func searchByEnglishCityName() {
        let results = db.searchAirports(query: "Tokyo")
        #expect(results.contains { $0.iataCode == "NRT" })
    }
    
    @Test("Empty search returns all airports")
    func emptySearchReturnsAll() {
        let all = db.getAllAirports()
        let searchAll = db.searchAirports(query: "")
        #expect(searchAll.count == all.count)
    }
    
    // MARK: - getPopularAirports
    
    @Test("Popular airports list is not empty")
    func popularAirportsNotEmpty() {
        let popular = db.getPopularAirports()
        #expect(!popular.isEmpty)
    }
    
    @Test("Popular airports preserves order of popularIATACodes")
    func popularAirportsOrder() {
        let popular = db.getPopularAirports()
        let codes = popular.map { $0.iataCode }
        // First should be TPE
        #expect(codes.first == "TPE")
    }
}

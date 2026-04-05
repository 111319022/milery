import Foundation
import SwiftData

@Model
final class RedeemedTicket {
    var id: UUID = UUID()
    var originIATA: String = ""
    var destinationIATA: String = ""
    var originName: String = ""
    var destinationName: String = ""
    var isRoundTrip: Bool = false
    @Attribute(originalName: "cabinClass") var cabinClassRaw: String = CabinClass.economy.rawValue
    var spentMiles: Int = 0
    @Attribute(originalName: "taxPaid") var taxPaidValue: Double = 0
    var flightDate: Date = Date()
    var pnr: String = ""
    var airline: String = ""
    var flightNumber: String = ""
    var redeemedDate: Date = Date()
    var linkedTransactionID: UUID?
    var programID: UUID?

    var cabinClass: CabinClass {
        get { CabinClass(rawValue: cabinClassRaw) ?? .economy }
        set { cabinClassRaw = newValue.rawValue }
    }

    var taxPaid: Decimal {
        get { NSDecimalNumber(value: taxPaidValue).decimalValue }
        set { taxPaidValue = NSDecimalNumber(decimal: newValue).doubleValue }
    }

    init(
        id: UUID = UUID(),
        originIATA: String,
        destinationIATA: String,
        originName: String,
        destinationName: String,
        isRoundTrip: Bool = false,
        cabinClass: CabinClass,
        spentMiles: Int,
        taxPaid: Decimal,
        flightDate: Date,
        pnr: String,
        airline: String = "",
        flightNumber: String = "",
        redeemedDate: Date = Date(),
        linkedTransactionID: UUID? = nil
    ) {
        self.id = id
        self.originIATA = originIATA
        self.destinationIATA = destinationIATA
        self.originName = originName
        self.destinationName = destinationName
        self.isRoundTrip = isRoundTrip
        self.cabinClassRaw = cabinClass.rawValue
        self.spentMiles = spentMiles
        self.taxPaidValue = NSDecimalNumber(decimal: taxPaid).doubleValue
        self.flightDate = flightDate
        self.pnr = pnr
        self.airline = airline
        self.flightNumber = flightNumber
        self.redeemedDate = redeemedDate
        self.linkedTransactionID = linkedTransactionID
    }
}

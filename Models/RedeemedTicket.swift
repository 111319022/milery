//
//  RedeemedTicket.swift
//  73app-mid
//
//  Created by GitHub Copilot on 2026/3/20.
//

import Foundation
import SwiftData

@Model
final class RedeemedTicket {
    var id: UUID
    var originIATA: String
    var destinationIATA: String
    var originName: String
    var destinationName: String
    var isRoundTrip: Bool
    var cabinClass: CabinClass
    var spentMiles: Int
    var taxPaid: Decimal
    var flightDate: Date
    var pnr: String
    var airline: String
    var flightNumber: String
    var redeemedDate: Date
    var linkedTransactionID: UUID?

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
        self.cabinClass = cabinClass
        self.spentMiles = spentMiles
        self.taxPaid = taxPaid
        self.flightDate = flightDate
        self.pnr = pnr
        self.airline = airline
        self.flightNumber = flightNumber
        self.redeemedDate = redeemedDate
        self.linkedTransactionID = linkedTransactionID
    }
}

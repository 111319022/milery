//
//  MileageAccount.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import Foundation
import SwiftData

@Model
final class MileageAccount {
    var totalMiles: Int
    var lastActivityDate: Date
    var expiryDate: Date
    
    @Relationship(deleteRule: .cascade) var transactions: [Transaction] = []
    @Relationship(deleteRule: .cascade) var flightGoals: [FlightGoal] = []
    
    init(totalMiles: Int = 0, lastActivityDate: Date = Date()) {
        self.totalMiles = totalMiles
        self.lastActivityDate = lastActivityDate
        self.expiryDate = Calendar.current.date(byAdding: .month, value: 18, to: lastActivityDate) ?? Date()
    }
    
    // 更新哩程並自動延期
    func updateMiles(amount: Int, date: Date = Date()) {
        totalMiles += amount
        lastActivityDate = date
        expiryDate = Calendar.current.date(byAdding: .month, value: 18, to: date) ?? Date()
    }
    
    // 計算距離過期的天數
    func daysUntilExpiry() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiryDate)
        return components.day ?? 0
    }
}

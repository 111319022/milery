//
//  Transaction.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var date: Date
    var amount: Decimal // 消費金額或成本
    var earnedMiles: Int
    var source: MileageSource
    var acceleratorCategory: AcceleratorCategory? // 加速器類別（如果適用）
    var notes: String
    var costPerMile: Double // 每哩成本（自動計算）
    
    init(date: Date = Date(), 
         amount: Decimal, 
         earnedMiles: Int, 
         source: MileageSource,
         acceleratorCategory: AcceleratorCategory? = nil,
         notes: String = "") {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.earnedMiles = earnedMiles
        self.source = source
        self.acceleratorCategory = acceleratorCategory
        self.notes = notes
        
        // 計算每哩成本
        if earnedMiles > 0 {
            self.costPerMile = Double(truncating: amount as NSDecimalNumber) / Double(earnedMiles)
        } else {
            self.costPerMile = 0
        }
    }
}

// 里程來源
enum MileageSource: String, Codable, CaseIterable {
    case cardGeneral = "聯名卡一般消費"
    case cardAccelerator = "聯名卡哩程加速器"
    case specialMerchant = "特店消費累積"
    case promotion = "活動贈送"
    case pointsConversion = "銀行點數兌換"
    case pointsTransfer = "他點轉入"
    case flight = "飛行累積"
    
    var icon: String {
        switch self {
        case .cardGeneral: return "creditcard"
        case .cardAccelerator: return "bolt.fill"
        case .specialMerchant: return "storefront"
        case .promotion: return "gift.fill"
        case .pointsConversion: return "arrow.triangle.2.circlepath"
        case .pointsTransfer: return "arrow.down.circle.fill"
        case .flight: return "airplane"
        }
    }
    
    var color: String {
        switch self {
        case .cardGeneral: return "blue"
        case .cardAccelerator: return "orange"
        case .specialMerchant: return "purple"
        case .promotion: return "pink"
        case .pointsConversion: return "green"
        case .pointsTransfer: return "indigo"
        case .flight: return "cyan"
        }
    }
}

// 加速器類別（國泰世華亞萬卡的四大加速器）
enum AcceleratorCategory: String, Codable, CaseIterable {
    case overseas = "海外"
    case travel = "旅遊交通"
    case daily = "日常消費"
    case leisure = "休閒娛樂"
    
    var icon: String {
        switch self {
        case .overseas: return "globe.asia.australia.fill"
        case .travel: return "airplane.departure"
        case .daily: return "cart.fill"
        case .leisure: return "theatermasks.fill"
        }
    }
}

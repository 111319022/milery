//
//  _3app_midApp.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI
import SwiftData

@main
struct _3app_midApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [
            MileageAccount.self,
            Transaction.self,
            FlightGoal.self,
            CreditCardRule.self
        ])
    }
}

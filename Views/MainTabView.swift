//
//  MainTabView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userColorScheme") private var userColorScheme: String = "system"
    @State private var viewModel = MileageViewModel()
    @State private var selectedTab: Int = 0
    
    var preferredColorScheme: ColorScheme? {
        switch userColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                viewModel: viewModel,
                switchToProgress: { selectedTab = 1 },
                switchToLedger: { selectedTab = 2 }
            )
                .tag(0)
                .tabItem {
                    Label("儀表板", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
            
            ProgressView(viewModel: viewModel)
                .tag(1)
                .tabItem {
                    Label("進度", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            LedgerView(viewModel: viewModel)
                .tag(2)
                .tabItem {
                    Label("記帳", systemImage: "book.pages.fill")
                }

            MilestonesView(viewModel: viewModel)
                .tag(3)
                .tabItem {
                    Label("里程碑", systemImage: "ticket.fill")
                }
            
            SettingsView(viewModel: viewModel)
                .tag(4)
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .tint(AviationTheme.Colors.cathayJade)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            viewModel.initialize(context: modelContext)
        }
        .alert("儲存失敗", isPresented: $viewModel.showSaveError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(viewModel.saveError ?? "未知錯誤")
        }
    }
}

#Preview {
    MainTabView()
    .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])
}

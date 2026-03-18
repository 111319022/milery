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
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("userColorScheme") private var userColorScheme: String = "system"
    @State private var viewModel = MileageViewModel()
    
    var preferredColorScheme: ColorScheme? {
        switch userColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("儀表板", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
            
            ProgressView(viewModel: viewModel)
                .tabItem {
                    Label("進度", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            LedgerView(viewModel: viewModel)
                .tabItem {
                    Label("記帳", systemImage: "book.pages.fill")
                }
            
            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .tint(AviationTheme.Colors.cathayJade)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            viewModel.initialize(context: modelContext)
            updateTabBarAppearance()
        }
        .onChange(of: colorScheme) { _, _ in
            updateTabBarAppearance()
        }
        .onChange(of: userColorScheme) { _, _ in
            updateTabBarAppearance()
        }
    }
    
    private func updateTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AviationTheme.Colors.cardBackground(colorScheme))
        
        // 設定未選中的圖標顏色
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AviationTheme.Colors.silver)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AviationTheme.Colors.silver)
        ]
        
        // 設定選中的圖標顏色
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AviationTheme.Colors.cathayJade)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AviationTheme.Colors.cathayJade)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}

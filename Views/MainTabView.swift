import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userColorScheme") private var userColorScheme: String = "system"
    @AppStorage("tabVisible_dashboard") private var dashboardVisible = true
    @AppStorage("tabVisible_progress") private var progressVisible = true
    @AppStorage("tabVisible_ledger") private var ledgerVisible = true
    @AppStorage("tabVisible_milestones") private var milestonesVisible = true
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
            if dashboardVisible {
                DashboardView(
                    viewModel: viewModel,
                    switchToProgress: { withAnimation(.smooth(duration: 0.3)) { selectedTab = 1 } },
                    switchToLedger: { withAnimation(.smooth(duration: 0.3)) { selectedTab = 2 } }
                )
                    .tag(0)
                    .tabItem {
                        Label("儀表板", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    }
            }
            
            if progressVisible {
                ProgressView(viewModel: viewModel)
                    .tag(1)
                    .tabItem {
                        Label("進度", systemImage: "chart.line.uptrend.xyaxis")
                    }
            }
            
            if ledgerVisible {
                LedgerView(viewModel: viewModel)
                    .tag(2)
                    .tabItem {
                        Label("記帳", systemImage: "book.pages.fill")
                    }
            }

            if milestonesVisible {
                MilestonesView(viewModel: viewModel)
                    .tag(3)
                    .tabItem {
                        Label("里程碑", systemImage: "ticket.fill")
                    }
            }
            
            SettingsView(viewModel: viewModel)
                .tag(4)
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .tint(AviationTheme.Colors.cathayJade)
        .preferredColorScheme(preferredColorScheme)
        .animation(.smooth(duration: 0.3), value: selectedTab)
        .onAppear {
            viewModel.initialize(context: modelContext)
        }
        .onChange(of: dashboardVisible) { ensureValidTab() }
        .onChange(of: progressVisible) { ensureValidTab() }
        .onChange(of: ledgerVisible) { ensureValidTab() }
        .onChange(of: milestonesVisible) { ensureValidTab() }
        .alert("儲存失敗", isPresented: $viewModel.showSaveError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(viewModel.saveError ?? "未知錯誤")
        }
    }
    
    /// 當分頁被隱藏時，若目前選中的分頁已不可見，自動切換到第一個可見分頁
    private func ensureValidTab() {
        let visibilityMap: [Int: Bool] = [
            0: dashboardVisible,
            1: progressVisible,
            2: ledgerVisible,
            3: milestonesVisible,
            4: true // 設定頁面永遠可見
        ]
        
        if visibilityMap[selectedTab] == true { return }
        
        // 切換到第一個可見的分頁
        if let firstVisible = visibilityMap.sorted(by: { $0.key < $1.key }).first(where: { $0.value }) {
            selectedTab = firstVisible.key
        }
    }
}

#Preview {
    MainTabView()
    .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])
}

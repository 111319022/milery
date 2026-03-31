import SwiftUI
import SwiftData

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("cloudKitSyncEnabled") private var cloudKitSyncEnabled: Bool = true

    @Query(sort: [SortDescriptor(\MileageAccount.totalMiles, order: .reverse)]) private var accounts: [MileageAccount]
    @Query(sort: [SortDescriptor(\Transaction.date, order: .reverse)]) private var transactions: [Transaction]
    @Query(sort: [SortDescriptor(\FlightGoal.createdDate, order: .reverse)]) private var flightGoals: [FlightGoal]
    @Query(sort: [SortDescriptor(\RedeemedTicket.redeemedDate, order: .reverse)]) private var redeemedTickets: [RedeemedTicket]
    @Query(sort: [SortDescriptor(\CreditCardRule.cardName)]) private var legacyCreditCards: [CreditCardRule]

    @State private var backupService = CloudBackupService()

    @State private var showingCleanupConfirm = false
    @State private var showingCleanupResult = false
    @State private var cleanupResultText = ""
    @State private var isCleaning = false
    @State private var customImages: [String] = []

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        List {
            Section("資料總覽") {
                statRow(title: "MileageAccount", value: "\(accounts.count)")
                statRow(title: "Transaction", value: "\(transactions.count)")
                statRow(title: "FlightGoal", value: "\(flightGoals.count)")
                statRow(title: "RedeemedTicket", value: "\(redeemedTickets.count)")
                statRow(title: "CreditCardRule (舊版殘留)", value: "\(legacyCreditCards.count)")
            }

            Section("自訂桌布圖片 (檔案系統)") {
                HStack {
                    Text("圖片總數")
                    Spacer()
                    Text("\(customImages.count)")
                        .foregroundStyle(.secondary)
                }

                if !customImages.isEmpty {
                    NavigationLink("檢視所有圖片檔案") {
                        List {
                            ForEach(customImages, id: \.self) { filename in
                                HStack {
                                    Text(filename)
                                        .font(.caption)
                                    Spacer()
                                    if let url = BackgroundImageManager.shared.customImageURL(filename: filename),
                                       let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                                       let size = attrs[.size] as? Int64 {
                                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("刪除", role: .destructive) {
                                        // 針對除錯用途，直接全刪 (含原圖與裁切)
                                        let baseFilename = filename.replacingOccurrences(of: "original_", with: "")
                                        BackgroundImageManager.shared.deleteCustomImage(filename: baseFilename)
                                        refreshCustomImages()
                                    }
                                }
                            }
                        }
                        .navigationTitle("圖片檔案列表")
                    }
                }
            }

            Section("CloudKit 參考資訊") {
                HStack {
                    Label("同步開關", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Text(cloudKitSyncEnabled ? "啟用" : "關閉")
                        .foregroundStyle(cloudKitSyncEnabled ? .green : .secondary)
                }

                HStack {
                    Label("iCloud 帳號", systemImage: "icloud")
                    Spacer()
                    Text(iCloudStatusText)
                        .foregroundStyle(iCloudStatusColor)
                }

                HStack {
                    Label("雲端備份筆數", systemImage: "externaldrive.badge.icloud")
                    Spacer()
                    Text("\(backupService.backupRecords.count)")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await refreshCloudInfo()
                    }
                } label: {
                    Label("重新整理 CloudKit 狀態", systemImage: "arrow.clockwise")
                }

                NavigationLink(destination: CloudKitAdvancedView()) {
                    Label("CloudKit record 詳細檢視（進階）", systemImage: "server.rack")
                }
            }

            Section("安全清理舊版異常資料") {
                Text("此操作會刪除重複帳戶、孤兒交易/目標、以及舊版 CreditCardRule 殘留資料。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    showingCleanupConfirm = true
                } label: {
                    if isCleaning {
                        Label("清理中...", systemImage: "hourglass")
                    } else {
                        Label("執行安全清理", systemImage: "trash")
                    }
                }
                .disabled(isCleaning)
            }

            Section("MileageAccount") {
                if accounts.isEmpty {
                    Text("無資料")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accounts, id: \.persistentModelID) { account in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Miles: \(account.totalMiles)")
                                .font(.headline)
                            Text("Last Activity: \(Self.dateTimeFormatter.string(from: account.lastActivityDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Tx: \((account.transactions ?? []).count) | Goals: \((account.flightGoals ?? []).count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button("刪除", role: .destructive) {
                                deleteAccount(account)
                            }
                        }
                    }
                }
            }

            Section("Transaction") {
                if transactions.isEmpty {
                    Text("無資料")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(transactions, id: \.persistentModelID) { tx in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(tx.source.rawValue) | \(tx.earnedMiles) miles")
                                .font(.headline)
                            Text("Date: \(Self.dateTimeFormatter.string(from: tx.date))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Amount: \(tx.amountValue, specifier: "%.2f") | account: \(tx.account == nil ? "nil" : "ok")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !tx.notes.isEmpty {
                                Text("Notes: \(tx.notes)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button("刪除", role: .destructive) {
                                deleteTransaction(tx)
                            }
                        }
                    }
                }
            }

            Section("FlightGoal") {
                if flightGoals.isEmpty {
                    Text("無資料")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(flightGoals, id: \.persistentModelID) { goal in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(goal.origin) -> \(goal.destination) | \(goal.requiredMiles) miles")
                                .font(.headline)
                            Text("Cabin: \(goal.cabinClass.rawValue) | priority: \(goal.isPriority ? "Y" : "N") | account: \(goal.account == nil ? "nil" : "ok")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Created: \(Self.dateTimeFormatter.string(from: goal.createdDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button("刪除", role: .destructive) {
                                deleteFlightGoal(goal)
                            }
                        }
                    }
                }
            }

            Section("RedeemedTicket") {
                if redeemedTickets.isEmpty {
                    Text("無資料")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(redeemedTickets, id: \.persistentModelID) { ticket in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(ticket.originIATA) -> \(ticket.destinationIATA) | \(ticket.spentMiles) miles")
                                .font(.headline)
                            Text("Date: \(Self.dateTimeFormatter.string(from: ticket.flightDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("PNR: \(ticket.pnr.isEmpty ? "-" : ticket.pnr) | TxLink: \(ticket.linkedTransactionID == nil ? "nil" : "ok")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button("刪除", role: .destructive) {
                                deleteRedeemedTicket(ticket)
                            }
                        }
                    }
                }
            }

            Section("CreditCardRule（舊版殘留）") {
                if legacyCreditCards.isEmpty {
                    Text("無資料")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(legacyCreditCards, id: \.persistentModelID) { card in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.cardName)
                                .font(.headline)
                            Text("bank: \(card.bankName) | active: \(card.isActive ? "Y" : "N")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("brand: \(card.cardBrandRaw) | tier: \(card.cardTierRaw.isEmpty ? "-" : card.cardTierRaw)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button("刪除", role: .destructive) {
                                deleteLegacyCreditCard(card)
                            }
                        }
                    }
                }
            }

            Section("連結至") {
                NavigationLink(destination: ConsoleLogView(initialShowSyncRelated: true)) {
                    Label("Console日誌", systemImage: "text.justify.left")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("資料管理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshCloudInfo()
        }
        .onAppear {
            refreshCustomImages()
        }
        .alert("執行資料清理", isPresented: $showingCleanupConfirm) {
            Button("取消", role: .cancel) {}
            Button("執行", role: .destructive) {
                runLegacyCleanup()
            }
        } message: {
            Text("此操作會刪除舊版殘留資料，無法復原。建議先做 iCloud 備份。")
        }
        .alert("清理完成", isPresented: $showingCleanupResult) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(cleanupResultText)
        }
    }

    private var iCloudStatusText: String {
        switch backupService.iCloudAvailable {
        case true: return "可用"
        case false: return "不可用"
        case nil: return "檢查中"
        }
    }

    private var iCloudStatusColor: Color {
        switch backupService.iCloudAvailable {
        case true: return .green
        case false: return .red
        case nil: return .secondary
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func refreshCloudInfo() async {
        await backupService.checkiCloudStatus()
        await backupService.fetchBackupList()
    }

    private func refreshCustomImages() {
        customImages = BackgroundImageManager.shared.listAllCustomImages()
    }

    private func deleteAccount(_ account: MileageAccount) {
        do {
            modelContext.delete(account)
            try modelContext.save()
            appLog("[DataMgmt] 已刪除 MileageAccount")
        } catch {
            appLog("[DataMgmt] 刪除 MileageAccount 失敗：\(error.localizedDescription)")
        }
    }

    private func deleteTransaction(_ tx: Transaction) {
        do {
            modelContext.delete(tx)
            try modelContext.save()
            appLog("[DataMgmt] 已刪除 Transaction id=\(tx.id.uuidString)")
        } catch {
            appLog("[DataMgmt] 刪除 Transaction 失敗：\(error.localizedDescription)")
        }
    }

    private func deleteFlightGoal(_ goal: FlightGoal) {
        do {
            modelContext.delete(goal)
            try modelContext.save()
            appLog("[DataMgmt] 已刪除 FlightGoal id=\(goal.id.uuidString)")
        } catch {
            appLog("[DataMgmt] 刪除 FlightGoal 失敗：\(error.localizedDescription)")
        }
    }

    private func deleteRedeemedTicket(_ ticket: RedeemedTicket) {
        do {
            modelContext.delete(ticket)
            try modelContext.save()
            appLog("[DataMgmt] 已刪除 RedeemedTicket id=\(ticket.id.uuidString)")
        } catch {
            appLog("[DataMgmt] 刪除 RedeemedTicket 失敗：\(error.localizedDescription)")
        }
    }

    private func deleteLegacyCreditCard(_ card: CreditCardRule) {
        do {
            modelContext.delete(card)
            try modelContext.save()
            appLog("[DataMgmt] 已刪除 CreditCardRule id=\(card.id.uuidString)")
        } catch {
            appLog("[DataMgmt] 刪除 CreditCardRule 失敗：\(error.localizedDescription)")
        }
    }

    private func runLegacyCleanup() {
        guard !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }

        var removedDuplicateAccounts = 0
        var removedOrphanTransactions = 0
        var removedOrphanGoals = 0
        var removedLegacyCards = 0

        do {
            let allAccounts = try modelContext.fetch(FetchDescriptor<MileageAccount>())
            if allAccounts.count > 1 {
                let keepAccount = allAccounts.sorted { lhs, rhs in
                    if lhs.totalMiles != rhs.totalMiles {
                        return lhs.totalMiles > rhs.totalMiles
                    }
                    return lhs.lastActivityDate > rhs.lastActivityDate
                }.first

                for account in allAccounts where account.persistentModelID != keepAccount?.persistentModelID {
                    modelContext.delete(account)
                    removedDuplicateAccounts += 1
                }
            }

            let allTransactions = try modelContext.fetch(FetchDescriptor<Transaction>())
            for tx in allTransactions where tx.account == nil {
                modelContext.delete(tx)
                removedOrphanTransactions += 1
            }

            let allGoals = try modelContext.fetch(FetchDescriptor<FlightGoal>())
            for goal in allGoals where goal.account == nil {
                modelContext.delete(goal)
                removedOrphanGoals += 1
            }

            let allLegacyCards = try modelContext.fetch(FetchDescriptor<CreditCardRule>())
            for card in allLegacyCards {
                modelContext.delete(card)
                removedLegacyCards += 1
            }

            if modelContext.hasChanges {
                try modelContext.save()
            }

            cleanupResultText = """
            刪除重複帳戶: \(removedDuplicateAccounts)
            刪除孤兒交易: \(removedOrphanTransactions)
            刪除孤兒目標: \(removedOrphanGoals)
            刪除舊版信用卡: \(removedLegacyCards)
            """
            appLog("[DataMgmt] 完成安全清理：accounts=\(removedDuplicateAccounts), tx=\(removedOrphanTransactions), goals=\(removedOrphanGoals), cards=\(removedLegacyCards)")
        } catch {
            cleanupResultText = "清理失敗：\(error.localizedDescription)"
            appLog("[DataMgmt] 清理失敗：\(error.localizedDescription)")
        }

        showingCleanupResult = true
    }
}

#Preview {
    NavigationStack {
        DataManagementView()
    }
    .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])
}

import SwiftUI
import SwiftData
import CloudKit

struct CloudBackupView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: MileageViewModel
    
    @State private var backupService = CloudBackupService()
    @AppStorage("lastBackupDate") private var lastBackupDateTimestamp: Double = 0
    
    @State private var showingRestoreConfirmation = false
    @State private var selectedBackupID: CKRecord.ID?
    @State private var showingDeleteConfirmation = false
    @State private var backupToDelete: CKRecord.ID?
    @State private var showingBackupSuccess = false
    @State private var showingRestoreSuccess = false
    
    private var lastBackupDate: Date? {
        lastBackupDateTimestamp > 0 ? Date(timeIntervalSince1970: lastBackupDateTimestamp) : nil
    }
    
    var body: some View {
        ZStack {
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.xl) {
                    
                    // MARK: - 備份狀態
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "備份狀態", colorScheme: colorScheme)
                        
                        VStack(spacing: 0) {
                            // 上次備份時間
                            SettingRow(
                                icon: "clock.arrow.circlepath",
                                title: "上次備份",
                                subtitle: nil
                            ) {
                                Text(lastBackupDateText)
                                    .font(AviationTheme.Typography.subheadline)
                                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            }
                            
                            CustomDivider(colorScheme: colorScheme)
                            
                            // iCloud 狀態
                            SettingRow(
                                icon: "icloud.fill",
                                title: "iCloud 狀態",
                                subtitle: nil
                            ) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(iCloudStatusColor)
                                        .frame(width: 8, height: 8)
                                    Text(iCloudStatusText)
                                        .font(AviationTheme.Typography.subheadline)
                                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                }
                            }
                        }
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    
                    // MARK: - 建立備份
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "建立備份", colorScheme: colorScheme)
                        
                        VStack(spacing: 0) {
                            // 目前資料摘要
                            SettingRow(
                                icon: "doc.text.fill",
                                title: "目前資料",
                                subtitle: dataSummaryText
                            ) {
                                EmptyView()
                            }
                            
                            CustomDivider(colorScheme: colorScheme)
                            
                            // 備份按鈕
                            Button {
                                Task { await performBackup() }
                            } label: {
                                SettingRow(
                                    icon: "icloud.and.arrow.up.fill",
                                    title: backupService.isUploading
                                        ? backupService.uploadProgress
                                        : "備份到 iCloud",
                                    subtitle: "將所有資料上傳至您的 iCloud",
                                    titleColor: AviationTheme.Colors.cathayJade
                                ) {
                                    if backupService.isUploading {
                                        SwiftUI.ProgressView()
                                            .tint(AviationTheme.Colors.cathayJade)
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(AviationTheme.Colors.cathayJade)
                                            .font(.title3)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(backupService.isUploading || backupService.iCloudAvailable != true)
                        }
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    
                    // MARK: - 雲端備份列表
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "雲端備份列表", colorScheme: colorScheme)
                        
                        VStack(spacing: 0) {
                            if backupService.isLoadingList {
                                HStack {
                                    Spacer()
                                    SwiftUI.ProgressView("載入中...")
                                        .padding(.vertical, 24)
                                    Spacer()
                                }
                            } else if backupService.backupRecords.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "icloud.slash")
                                            .font(.title2)
                                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                        Text("尚無雲端備份")
                                            .font(AviationTheme.Typography.subheadline)
                                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                    }
                                    .padding(.vertical, 24)
                                    Spacer()
                                }
                            } else {
                                ForEach(Array(backupService.backupRecords.enumerated()), id: \.element.id) { index, record in
                                    if index > 0 {
                                        CustomDivider(colorScheme: colorScheme)
                                    }
                                    
                                    BackupRecordRow(
                                        record: record,
                                        isRestoring: backupService.isDownloading,
                                        onRestore: {
                                            selectedBackupID = record.id
                                            showingRestoreConfirmation = true
                                        },
                                        onDelete: {
                                            backupToDelete = record.id
                                            showingDeleteConfirmation = true
                                        }
                                    )
                                }
                            }
                        }
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                }
                .padding(.top, AviationTheme.Spacing.md)
                .padding(.bottom, AviationTheme.Spacing.xxl)
            }
        }
        .navigationTitle("iCloud 備份")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await backupService.checkiCloudStatus()
            await backupService.fetchBackupList()
        }
        .refreshable {
            await backupService.fetchBackupList()
        }
        // 還原確認
        .alert("確認還原", isPresented: $showingRestoreConfirmation) {
            Button("還原", role: .destructive) {
                guard let id = selectedBackupID else { return }
                Task { await performRestore(recordID: id) }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("還原將會取代目前所有本機資料，此操作無法復原。建議先建立一份備份。")
        }
        // 刪除確認
        .alert("刪除備份", isPresented: $showingDeleteConfirmation) {
            Button("刪除", role: .destructive) {
                guard let id = backupToDelete else { return }
                Task {
                    do {
                        try await backupService.deleteBackup(recordID: id)
                    } catch {
                        backupService.errorMessage = error.localizedDescription
                        backupService.showError = true
                    }
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("確定要從 iCloud 刪除此備份？")
        }
        // 錯誤提示
        .alert("錯誤", isPresented: $backupService.showError) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(backupService.errorMessage ?? "未知錯誤")
        }
        // 備份成功
        .alert("備份完成", isPresented: $showingBackupSuccess) {
            Button("確定", role: .cancel) { }
        } message: {
            Text("資料已成功上傳至 iCloud")
        }
        // 還原成功
        .alert("還原完成", isPresented: $showingRestoreSuccess) {
            Button("確定", role: .cancel) { }
        } message: {
            Text("資料已成功從 iCloud 還原")
        }
    }
    
    // MARK: - Computed Properties
    
    private var lastBackupDateText: String {
        guard let date = lastBackupDate else { return "尚未備份" }
        return date.formatted(.dateTime.year().month().day().hour().minute())
    }
    
    private var iCloudStatusColor: Color {
        switch backupService.iCloudAvailable {
        case true: return .green
        case false: return .red
        case nil: return .gray
        }
    }
    
    private var iCloudStatusText: String {
        switch backupService.iCloudAvailable {
        case true: return "已連線"
        case false: return "不可用"
        case nil: return "檢查中..."
        }
    }
    
    private var dataSummaryText: String {
        "\(viewModel.transactions.count) 筆交易、\(viewModel.flightGoals.count) 個目標、\(viewModel.creditCards.count) 張信用卡、\(viewModel.redeemedTickets.count) 張機票"
    }
    
    // MARK: - Actions
    
    private func performBackup() async {
        do {
            try await backupService.createBackup(modelContext: modelContext)
            await backupService.fetchBackupList()
            showingBackupSuccess = true
        } catch {
            backupService.errorMessage = error.localizedDescription
            backupService.showError = true
        }
    }
    
    private func performRestore(recordID: CKRecord.ID) async {
        do {
            try await backupService.restoreFromBackup(recordID: recordID, modelContext: modelContext)
            viewModel.loadData() // 重新載入記憶體中的資料
            showingRestoreSuccess = true
        } catch {
            backupService.errorMessage = error.localizedDescription
            backupService.showError = true
        }
    }
}

// MARK: - 備份紀錄列表行
private struct BackupRecordRow: View {
    @Environment(\.colorScheme) var colorScheme
    let record: CloudBackupService.BackupRecord
    let isRestoring: Bool
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 圖標
            Image(systemName: "doc.zipper")
                .font(.title3)
                .foregroundColor(AviationTheme.Colors.cathayJade)
                .frame(width: 28)
            
            // 備份資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(record.backupDate.formatted(.dateTime.year().month().day().hour().minute()))
                    .font(AviationTheme.Typography.body)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text("\(record.deviceName)")
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                
                Text(record.recordCounts)
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            }
            
            Spacer()
            
            if isRestoring {
                SwiftUI.ProgressView()
                    .tint(AviationTheme.Colors.cathayJade)
            } else {
                // 還原按鈕
                Button(action: onRestore) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                }
                .buttonStyle(.plain)
                
                // 刪除按鈕
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        CloudBackupView(viewModel: MileageViewModel())
            .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])
    }
}

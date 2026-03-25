import SwiftUI
import SwiftData
import CloudKit

struct CloudBackupView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: MileageViewModel
    
    @State private var backupService = CloudBackupService()
    @AppStorage("lastBackupDate") private var lastBackupDateTimestamp: Double = 0
    @AppStorage("cloudKitSyncEnabled") private var cloudKitSyncEnabled: Bool = true
    
    @State private var showingRestoreConfirmation = false
    @State private var selectedBackupID: CKRecord.ID?
    @State private var showingDeleteConfirmation = false
    @State private var backupToDelete: CKRecord.ID?
    @State private var showingBackupSuccess = false
    @State private var showingRestoreSuccess = false
    
    private var lastBackupDate: Date? {
        lastBackupDateTimestamp > 0 ? Date(timeIntervalSince1970: lastBackupDateTimestamp) : nil
    }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()
    
    var body: some View {
        ZStack {
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.xl) {
                    
                    // MARK: - 同步狀態
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "同步狀態", colorScheme: colorScheme)
                        
                        HStack(spacing: 14) {
                            Image(systemName: cloudKitSyncEnabled ? "arrow.triangle.2.circlepath.circle.fill" : "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(cloudKitSyncEnabled ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.secondaryText(colorScheme))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cloudKitSyncEnabled ? "iCloud 同步已啟用" : "iCloud 同步已關閉")
                                    .font(AviationTheme.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                Text(cloudKitSyncEnabled ? "資料會在相同 Apple ID 的裝置間自動同步" : "可在設定中重新開啟同步功能")
                                    .font(AviationTheme.Typography.caption)
                                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    
                    // MARK: - 建立備份（主要行動區）
                    VStack(spacing: 16) {
                        // 備份按鈕
                        Button {
                            Task { await performBackup() }
                        } label: {
                            HStack(spacing: 14) {
                                if backupService.isUploading {
                                    SwiftUI.ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "icloud.and.arrow.up.fill")
                                        .font(.title2)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(backupService.isUploading
                                         ? backupService.uploadProgress
                                         : "備份到 iCloud")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Text(dataSummaryText)
                                        .font(.caption)
                                        .opacity(0.85)
                                }
                                
                                Spacer()
                                
                                if !backupService.isUploading {
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .opacity(0.7)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [AviationTheme.Colors.cathayJade, AviationTheme.Colors.cathayJade.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                            .shadow(color: AviationTheme.Colors.cathayJade.opacity(0.3), radius: 12, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(backupService.isUploading || backupService.iCloudAvailable != true)
                        
                        // 狀態列：上次備份 + iCloud 狀態
                        HStack(spacing: 0) {
                            // 上次備份
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                Text(lastBackupDateText)
                                    .font(.caption)
                                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            }
                            
                            Spacer()
                            
                            // iCloud 狀態
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(iCloudStatusColor)
                                    .frame(width: 7, height: 7)
                                Text("iCloud \(iCloudStatusText)")
                                    .font(.caption)
                                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            }
                        }
                        .padding(.horizontal, 4)
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
        .navigationTitle("備份與同步")
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
        return Self.dateFormatter.string(from: date)
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
        return "\(viewModel.transactions.count) 筆交易、\(viewModel.flightGoals.count) 個目標、\(viewModel.redeemedTickets.count) 張機票"
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
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()
    
    @Environment(\.colorScheme) var colorScheme
    let record: CloudBackupService.BackupRecord
    let isRestoring: Bool
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 備份資訊
            HStack(spacing: 12) {
                Image(systemName: "doc.zipper")
                    .font(.title3)
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(BackupRecordRow.dateFormatter.string(from: record.backupDate))
                        .font(AviationTheme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text(record.deviceName)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    
                    Text(record.recordCounts)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            // 操作按鈕列
            if isRestoring {
                HStack {
                    Spacer()
                    SwiftUI.ProgressView("還原中...")
                        .tint(AviationTheme.Colors.cathayJade)
                    Spacer()
                }
                .padding(.bottom, 14)
            } else {
                HStack(spacing: 10) {
                    // 還原按鈕
                    Button(action: onRestore) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                                .font(.subheadline)
                            Text("還原")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AviationTheme.Colors.cathayJade.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    
                    // 刪除按鈕
                    Button(action: onDelete) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.subheadline)
                            Text("刪除")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        CloudBackupView(viewModel: MileageViewModel())
            .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])
    }
}

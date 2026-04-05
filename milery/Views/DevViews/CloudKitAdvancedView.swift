import SwiftUI
import CloudKit

struct CloudKitAdvancedView: View {
    @State private var backupService = CloudBackupService()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        List {
            Section("狀態") {
                HStack {
                    Label("iCloud 帳號", systemImage: "icloud")
                    Spacer()
                    Text(iCloudStatusText)
                        .foregroundStyle(iCloudStatusColor)
                }

                HStack {
                    Label("Record 數量", systemImage: "internaldrive")
                    Spacer()
                    Text("\(backupService.backupRecords.count)")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    Label("重新整理", systemImage: "arrow.clockwise")
                }
            }

            Section("CloudKit Records") {
                if backupService.isLoadingList {
                    HStack {
                        Spacer()
                        SwiftUI.ProgressView("讀取中...")
                        Spacer()
                    }
                } else if backupService.backupRecords.isEmpty {
                    Text("目前沒有可顯示的 record")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(backupService.backupRecords) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.id.recordName)
                                .font(.headline)
                                .textSelection(.enabled)

                            Text("Zone: \(record.id.zoneID.zoneName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            Text("Date: \(Self.dateFormatter.string(from: record.backupDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Device: \(record.deviceName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Schema: v\(record.schemaVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(record.recordCounts)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("CloudKit 進階檢視")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refresh()
        }
        .alert("錯誤", isPresented: $backupService.showError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(backupService.errorMessage ?? "未知錯誤")
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

    private func refresh() async {
        await backupService.checkiCloudStatus()
        await backupService.fetchBackupList()
    }
}

#Preview {
    NavigationStack {
        CloudKitAdvancedView()
    }
}

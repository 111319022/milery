import SwiftUI

struct ConsoleLogView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var console = AppConsoleStore.shared
    @State private var showingClearConfirm = false
    private let initialShowSyncRelated: Bool
    @State private var showOnlySyncRelated = false

    init(initialShowSyncRelated: Bool = false) {
        self.initialShowSyncRelated = initialShowSyncRelated
        _showOnlySyncRelated = State(initialValue: initialShowSyncRelated)
    }

    // MARK: - 過濾後的日誌（由新到舊）

    private var displayedEntries: [String] {
        let entries: [String]
        if showOnlySyncRelated {
            entries = console.entries.filter { line in
                line.contains("[Sync") || line.contains("CloudKit") || line.contains("iCloud")
            }
        } else {
            entries = console.entries
        }
        return entries.reversed()
    }

    // MARK: - 按日期分組

    /// 從日誌行提取日期字串（yyyy-MM-dd）
    private func extractDateKey(from entry: String) -> String {
        // 格式: [yyyy-MM-dd HH:mm:ss.SSS] ...
        guard let start = entry.firstIndex(of: "["),
              let end = entry.firstIndex(of: "]"),
              start < end else {
            return "未知日期"
        }
        let timestamp = String(entry[entry.index(after: start)..<end])
        // 取前 10 字元 = yyyy-MM-dd
        if timestamp.count >= 10 {
            return String(timestamp.prefix(10))
        }
        return "未知日期"
    }
    
    /// 從日誌行提取時間部分（HH:mm:ss）
    private func extractTime(from entry: String) -> String {
        guard let start = entry.firstIndex(of: "["),
              let end = entry.firstIndex(of: "]"),
              start < end else {
            return ""
        }
        let timestamp = String(entry[entry.index(after: start)..<end])
        // 取 HH:mm:ss（索引 11~18）
        if timestamp.count >= 19 {
            let timeStart = timestamp.index(timestamp.startIndex, offsetBy: 11)
            let timeEnd = timestamp.index(timestamp.startIndex, offsetBy: 19)
            return String(timestamp[timeStart..<timeEnd])
        }
        return ""
    }
    
    /// 從日誌行提取訊息（去掉時間戳）
    private func extractMessage(from entry: String) -> String {
        guard let end = entry.firstIndex(of: "]") else { return entry }
        let messageStart = entry.index(after: end)
        return String(entry[messageStart...]).trimmingCharacters(in: .whitespaces)
    }

    /// 將日期 key 轉為顯示用標題
    private func sectionTitle(for dateKey: String) -> String {
        guard dateKey != "未知日期" else { return dateKey }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return dateKey }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "M月d日（E）"
            displayFormatter.locale = Locale(identifier: "zh-Hant")
            return displayFormatter.string(from: date)
        }
    }
    
    /// 分組後的資料：[(dateKey, [entry])]，由新到舊
    private var groupedEntries: [(key: String, entries: [String])] {
        var dict: [String: [String]] = [:]
        var order: [String] = []
        for entry in displayedEntries {
            let key = extractDateKey(from: entry)
            if dict[key] == nil {
                order.append(key)
            }
            dict[key, default: []].append(entry)
        }
        return order.map { (key: $0, entries: dict[$0]!) }
    }

    // MARK: - Body

    var body: some View {
        List {
            Section {
                Toggle("只看同步相關", isOn: $showOnlySyncRelated)

                HStack {
                    Label("總筆數", systemImage: "number")
                    Spacer()
                    Text("\(displayedEntries.count)")
                        .foregroundStyle(.secondary)
                }

                Button {
                    let text = displayedEntries.joined(separator: "\n")
                    UIPasteboard.general.string = text
                } label: {
                    Label("複製目前清單", systemImage: "doc.on.doc")
                }

                Button(role: .destructive) {
                    showingClearConfirm = true
                } label: {
                    Label("清空日誌", systemImage: "trash")
                }
            }

            if displayedEntries.isEmpty {
                Section("日誌內容") {
                    Text("目前沒有可顯示的日誌")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(groupedEntries, id: \.key) { group in
                    Section(sectionTitle(for: group.key)) {
                        ForEach(Array(group.entries.enumerated()), id: \.offset) { _, entry in
                            LogEntryRow(
                                time: extractTime(from: entry),
                                message: extractMessage(from: entry)
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Console 日誌")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if initialShowSyncRelated {
                showOnlySyncRelated = true
            }
        }
        .alert("清空日誌", isPresented: $showingClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                console.clear()
            }
        } message: {
            Text("確定要刪除所有 App 內日誌嗎？")
        }
    }
}

// MARK: - 單筆日誌行
private struct LogEntryRow: View {
    let time: String
    let message: String
    
    /// 根據訊息標籤決定時間戳顏色（用於快速辨識類別）
    private var timeColor: Color {
        if message.contains("失敗") || message.contains("error") || message.contains("Error") { return .red }
        if message.contains("[Sync") { return .blue }
        if message.contains("[CloudBackup]") { return .purple }
        if message.contains("[SyncDiag]") { return .cyan }
        if message.contains("[DevAccess]") { return .orange }
        if message.contains("[Milery]") { return .green }
        return .secondary
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(time)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(timeColor)
                .frame(width: 62, alignment: .leading)
            
            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(nil)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ConsoleLogView()
    }
}

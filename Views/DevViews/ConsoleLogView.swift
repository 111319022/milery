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

    private var displayedEntries: [String] {
        if showOnlySyncRelated {
            return console.entries.filter { line in
                line.contains("[Sync") || line.contains("CloudKit") || line.contains("iCloud")
            }
        }
        return console.entries
    }

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

            Section("日誌內容") {
                if displayedEntries.isEmpty {
                    Text("目前沒有可顯示的日誌")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(displayedEntries.enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(nil)
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

#Preview {
    NavigationStack {
        ConsoleLogView()
    }
}

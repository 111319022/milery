import Foundation
import CloudKit

struct IssueReportEntry: Identifiable, Hashable {
    let id: String
    let recordID: CKRecord.ID
    let submittedAt: Date
    let content: String
    let contactEmail: String
    let appVersion: String
    let buildNumber: String
    let iOSVersion: String
    let deviceModel: String

    var contactEmailDisplayText: String {
        contactEmail.isEmpty ? "未填" : contactEmail
    }

    var titleText: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "（沒有內容）"
        }
        return String(trimmed.prefix(36)) + (trimmed.count > 36 ? "…" : "")
    }
}

final class IssueReportAdminService {
    static let shared = IssueReportAdminService()

    private let containerIdentifier = "iCloud.com.73app.milery"
    private let recordType = "IssueReport"

    private init() {}

    func fetchReports(limit: Int = 100) async throws -> [IssueReportEntry] {
        let publicDB = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "submittedAt", ascending: false)]

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: limit)
        let reports: [IssueReportEntry] = results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }

            let submittedAt = record["submittedAt"] as? Date ?? record.creationDate ?? Date.distantPast
            let content = record["content"] as? String ?? ""
            let contactEmail = record["contactEmail"] as? String ?? ""
            let appVersion = record["appVersion"] as? String ?? "unknown"
            let buildNumber = record["buildNumber"] as? String ?? "unknown"
            let iOSVersion = record["iOSVersion"] as? String ?? "unknown"
            let deviceModel = record["deviceModel"] as? String ?? "unknown"

            return IssueReportEntry(
                id: record.recordID.recordName,
                recordID: record.recordID,
                submittedAt: submittedAt,
                content: content,
                contactEmail: contactEmail,
                appVersion: appVersion,
                buildNumber: buildNumber,
                iOSVersion: iOSVersion,
                deviceModel: deviceModel
            )
        }

        return reports.sorted { $0.submittedAt > $1.submittedAt }
    }
}
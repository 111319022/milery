import Foundation
import CloudKit
import UIKit

final class IssueReportService {
    static let shared = IssueReportService()

    private let containerIdentifier = "iCloud.com.73app.milery"
    private let recordType = "IssueReport"

    private init() {}

    func submitReport(content: String, email: String) async throws {
        let publicDB = CKContainer(identifier: containerIdentifier).publicCloudDatabase

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw IssueReportError.emptyContent
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let iOSVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        let record = CKRecord(recordType: recordType)
        record["content"] = trimmedContent as CKRecordValue
        record["contactEmail"] = trimmedEmail as CKRecordValue
        record["appVersion"] = appVersion as CKRecordValue
        record["buildNumber"] = buildNumber as CKRecordValue
        record["iOSVersion"] = iOSVersion as CKRecordValue
        record["deviceModel"] = deviceModel as CKRecordValue
        record["submittedAt"] = Date() as CKRecordValue

        _ = try await publicDB.save(record)
        appLog("[IssueReport] 已送出問題回報")
    }
}

enum IssueReportError: LocalizedError {
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "請先輸入問題描述。"
        }
    }
}

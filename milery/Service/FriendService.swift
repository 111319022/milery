import Foundation
import CloudKit

// MARK: - 錯誤定義

enum FriendServiceError: LocalizedError {
    case iCloudUnavailable
    case profileNotFound
    case friendCodeNotFound
    case alreadyFriends
    case cannotAddSelf
    case codeGenerationFailed
    case cloudKitError(Error)
    
    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud 不可用，請確認已登入 iCloud 帳號"
        case .profileNotFound:
            return "找不到使用者資料"
        case .friendCodeNotFound:
            return "找不到此好友代碼，請確認是否正確"
        case .alreadyFriends:
            return "已經加過此好友了"
        case .cannotAddSelf:
            return "不能加自己為好友"
        case .codeGenerationFailed:
            return "好友代碼產生失敗，請稍後再試"
        case .cloudKitError(let error):
            return "iCloud 錯誤：\(error.localizedDescription)"
        }
    }
}

// MARK: - 好友服務

@MainActor
@Observable
final class FriendService {
    static let shared = FriendService()
    
    private let container = CKContainer(identifier: "iCloud.com.73app.milery")
    private var database: CKDatabase { container.publicCloudDatabase }
    
    // MARK: - Observable State
    
    var currentUserProfile: UserProfileData?
    var friends: [FriendData] = []
    var pendingOutgoing: [FriendData] = []
    var pendingIncoming: [FriendData] = []
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Data Types
    
    struct UserProfileData {
        let recordID: CKRecord.ID
        let userRecordID: CKRecord.Reference
        let friendCode: String
        var displayName: String
    }
    
    struct FriendData: Identifiable {
        let id: String
        let displayName: String
        let friendCode: String
        let status: String
        let isIncoming: Bool
    }
    
    private init() {}
    
    // MARK: - iCloud Check
    
    private func ensureiCloudAvailable() async throws {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw FriendServiceError.iCloudUnavailable
        }
    }
    
    private func currentUserRecordID() async throws -> CKRecord.ID {
        try await container.userRecordID()
    }
    
    // MARK: - Friend Code Generation
    
    /// 產生唯一 6 碼好友碼（排除 O/0/I/1 避免混淆）
    private func generateUniqueFriendCode() async throws -> String {
        let charset = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let codeLength = 6
        
        for _ in 0..<10 {
            let code = String((0..<codeLength).map { _ in charset.randomElement()! })
            
            let predicate = NSPredicate(format: "friendCode == %@", code)
            let query = CKQuery(recordType: "UserProfile", predicate: predicate)
            let (results, _) = try await database.records(matching: query, resultsLimit: 1)
            
            if results.isEmpty {
                return code
            }
            appLog("[FriendService] 好友碼碰撞: \(code), 重新產生")
        }
        
        throw FriendServiceError.codeGenerationFailed
    }
    
    // MARK: - Ensure / Fetch User Profile
    
    /// 首次進入好友頁面時呼叫，Lazy 建立 UserProfile
    func ensureUserProfile(defaultDisplayName: String) async throws -> UserProfileData {
        try await ensureiCloudAvailable()
        let userRecordID = try await currentUserRecordID()
        let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)
        
        // 嘗試取得已存在的 profile
        let predicate = NSPredicate(format: "userRecordID == %@", userRef)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        let (matchResults, _) = try await database.records(matching: query, resultsLimit: 1)
        
        if let (_, result) = matchResults.first,
           let record = try? result.get() {
            let profile = UserProfileData(
                recordID: record.recordID,
                userRecordID: userRef,
                friendCode: record["friendCode"] as? String ?? "",
                displayName: record["displayName"] as? String ?? ""
            )
            self.currentUserProfile = profile
            appLog("[FriendService] 載入已有 UserProfile, code: \(profile.friendCode)")
            return profile
        }
        
        // 建立新 profile
        let friendCode = try await generateUniqueFriendCode()
        let displayName = defaultDisplayName.isEmpty ? "Milery User" : defaultDisplayName
        
        let record = CKRecord(recordType: "UserProfile")
        record["userRecordID"] = userRef
        record["friendCode"] = friendCode as CKRecordValue
        record["displayName"] = displayName as CKRecordValue
        record["totalMiles"] = 0 as CKRecordValue
        record["goalCount"] = 0 as CKRecordValue
        record["completedRoutesCount"] = 0 as CKRecordValue
        record["lastUpdated"] = Date() as CKRecordValue
        record["sharingEnabled"] = 1 as CKRecordValue
        
        do {
            let saved = try await database.save(record)
            let profile = UserProfileData(
                recordID: saved.recordID,
                userRecordID: userRef,
                friendCode: friendCode,
                displayName: displayName
            )
            self.currentUserProfile = profile
            appLog("[FriendService] 建立新 UserProfile, code: \(friendCode)")
            return profile
        } catch {
            throw FriendServiceError.cloudKitError(error)
        }
    }
    
    // MARK: - Look Up Profile by Friend Code
    
    private func lookUpProfile(byFriendCode code: String) async throws -> CKRecord {
        let predicate = NSPredicate(format: "friendCode == %@", code.uppercased())
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        let (matchResults, _) = try await database.records(matching: query, resultsLimit: 1)
        
        guard let (_, result) = matchResults.first,
              let record = try? result.get() else {
            throw FriendServiceError.friendCodeNotFound
        }
        return record
    }
    
    // MARK: - Resolve Profile by UserRecordID Reference
    
    private func resolveProfile(for userRef: CKRecord.Reference) async throws -> CKRecord {
        let predicate = NSPredicate(format: "userRecordID == %@", userRef)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        let (results, _) = try await database.records(matching: query, resultsLimit: 1)
        guard let (_, result) = results.first, let record = try? result.get() else {
            throw FriendServiceError.profileNotFound
        }
        return record
    }
    
    // MARK: - Add Friend
    
    /// 加好友流程：
    /// 1. 查詢對方 UserProfile
    /// 2. 檢查不是自己、不是已加
    /// 3. 若對方已加我（反向 pending 存在）→ 雙方升級為 accepted
    /// 4. 否則建立 pending 關係
    func addFriend(byCode code: String) async throws {
        try await ensureiCloudAvailable()
        let myUserRecordID = try await currentUserRecordID()
        let myRef = CKRecord.Reference(recordID: myUserRecordID, action: .none)
        
        // 1. 查詢對方
        let targetProfile = try await lookUpProfile(byFriendCode: code.uppercased())
        guard let targetUserRef = targetProfile["userRecordID"] as? CKRecord.Reference else {
            throw FriendServiceError.profileNotFound
        }
        
        // 2. 不能加自己
        if targetUserRef.recordID == myUserRecordID {
            throw FriendServiceError.cannotAddSelf
        }
        
        // 3. 檢查我是否已加過對方
        let existingPred = NSPredicate(
            format: "fromUserRecordID == %@ AND toUserRecordID == %@", myRef, targetUserRef
        )
        let existingQuery = CKQuery(recordType: "FriendRelation", predicate: existingPred)
        let (existingResults, _) = try await database.records(matching: existingQuery, resultsLimit: 1)
        
        if let (_, result) = existingResults.first, let _ = try? result.get() {
            throw FriendServiceError.alreadyFriends
        }
        
        // 4. 檢查對方是否已加我（反向關係）
        let reversePred = NSPredicate(
            format: "fromUserRecordID == %@ AND toUserRecordID == %@", targetUserRef, myRef
        )
        let reverseQuery = CKQuery(recordType: "FriendRelation", predicate: reversePred)
        let (reverseResults, _) = try await database.records(matching: reverseQuery, resultsLimit: 1)
        
        if let (_, reverseResult) = reverseResults.first,
           let reverseRecord = try? reverseResult.get() {
            // 互加！升級為 accepted
            reverseRecord["status"] = "accepted" as CKRecordValue
            _ = try await database.save(reverseRecord)
            
            let myRelation = CKRecord(recordType: "FriendRelation")
            myRelation["fromUserRecordID"] = myRef
            myRelation["toUserRecordID"] = targetUserRef
            myRelation["status"] = "accepted" as CKRecordValue
            myRelation["createdAt"] = Date() as CKRecordValue
            _ = try await database.save(myRelation)
            
            appLog("[FriendService] 互加成功！code: \(code)")
        } else {
            // 單方加好友，建立 pending
            let myRelation = CKRecord(recordType: "FriendRelation")
            myRelation["fromUserRecordID"] = myRef
            myRelation["toUserRecordID"] = targetUserRef
            myRelation["status"] = "pending" as CKRecordValue
            myRelation["createdAt"] = Date() as CKRecordValue
            _ = try await database.save(myRelation)
            
            appLog("[FriendService] 已發送好友請求, code: \(code)")
        }
        
        await fetchFriends()
    }
    
    // MARK: - Fetch Friends
    
    /// 查詢所有好友關係，分為：已接受、等待對方、對方已加你
    func fetchFriends() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await ensureiCloudAvailable()
            let myUserRecordID = try await currentUserRecordID()
            let myRef = CKRecord.Reference(recordID: myUserRecordID, action: .none)
            
            // 查詢「我加的」關係
            let fromPred = NSPredicate(format: "fromUserRecordID == %@", myRef)
            let fromQuery = CKQuery(recordType: "FriendRelation", predicate: fromPred)
            let (fromResults, _) = try await database.records(matching: fromQuery)
            
            // 查詢「加我的」關係
            let toPred = NSPredicate(format: "toUserRecordID == %@", myRef)
            let toQuery = CKQuery(recordType: "FriendRelation", predicate: toPred)
            let (toResults, _) = try await database.records(matching: toQuery)
            
            var accepted: [FriendData] = []
            var outgoing: [FriendData] = []
            var incoming: [FriendData] = []
            
            // 處理「我加的」
            for (_, result) in fromResults {
                guard let record = try? result.get(),
                      let targetRef = record["toUserRecordID"] as? CKRecord.Reference,
                      let status = record["status"] as? String else { continue }
                
                if let profile = try? await resolveProfile(for: targetRef) {
                    let friend = FriendData(
                        id: record.recordID.recordName,
                        displayName: profile["displayName"] as? String ?? "Unknown",
                        friendCode: profile["friendCode"] as? String ?? "",
                        status: status,
                        isIncoming: false
                    )
                    if status == "accepted" {
                        accepted.append(friend)
                    } else {
                        outgoing.append(friend)
                    }
                }
            }
            
            // 處理「加我的」（只處理 pending 且我沒有反向關係的）
            for (_, result) in toResults {
                guard let record = try? result.get(),
                      let senderRef = record["fromUserRecordID"] as? CKRecord.Reference,
                      let status = record["status"] as? String else { continue }
                
                if status == "pending" {
                    // 檢查我是否已有反向關係
                    let alreadyHave = fromResults.contains { (_, r) in
                        guard let rec = try? r.get(),
                              let ref = rec["toUserRecordID"] as? CKRecord.Reference else { return false }
                        return ref.recordID == senderRef.recordID
                    }
                    
                    if !alreadyHave {
                        if let profile = try? await resolveProfile(for: senderRef) {
                            incoming.append(FriendData(
                                id: record.recordID.recordName,
                                displayName: profile["displayName"] as? String ?? "Unknown",
                                friendCode: profile["friendCode"] as? String ?? "",
                                status: "pending",
                                isIncoming: true
                            ))
                        }
                    }
                }
            }
            
            self.friends = accepted
            self.pendingOutgoing = outgoing
            self.pendingIncoming = incoming
            self.errorMessage = nil
            
            appLog("[FriendService] 好友列表更新: \(accepted.count) 已接受, \(outgoing.count) 等待, \(incoming.count) 收到")
            
        } catch {
            appLog("[FriendService] fetchFriends 失敗: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}

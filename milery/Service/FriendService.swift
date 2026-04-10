import Foundation
import CloudKit
import SwiftData

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
        // 好友進度（僅 accepted 好友有值）
        let totalMiles: Int
        let goalCount: Int
        let completedRoutesCount: Int
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
            
            // 碰撞檢查（若 record type 尚未存在則代表沒有碰撞）
            do {
                let predicate = NSPredicate(format: "friendCode == %@", code)
                let query = CKQuery(recordType: "UserProfile", predicate: predicate)
                let (results, _) = try await database.records(matching: query, resultsLimit: 1)
                
                if results.isEmpty {
                    return code
                }
                appLog("[FriendService] 好友碼碰撞: \(code), 重新產生")
            } catch {
                // Record type 不存在時查詢會失敗，此時不可能有碰撞
                return code
            }
        }
        
        throw FriendServiceError.codeGenerationFailed
    }
    
    // MARK: - Ensure / Fetch User Profile
    
    /// 首次進入好友頁面時呼叫，Lazy 建立 UserProfile
    /// CloudKit Development 環境在首次 save 時會自動建立 Record Type schema
    func ensureUserProfile(defaultDisplayName: String) async throws -> UserProfileData {
        try await ensureiCloudAvailable()
        let userRecordID = try await currentUserRecordID()
        let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)
        
        // 嘗試取得已存在的 profile（容錯：record type 不存在時跳過查詢直接建立）
        do {
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
        } catch {
            // Record type 可能尚未存在（首次使用），繼續建立
            appLog("[FriendService] 查詢 UserProfile 失敗（可能尚未建立 schema），將直接建立: \(error.localizedDescription)")
        }
        
        // 建立新 profile（首次 save 時 CloudKit Development 會自動建立 Record Type）
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
    /// 2. 檢查不是自己
    /// 3. 檢查是否已有我→對方的關係
    ///    - 有且 accepted → 已是好友
    ///    - 有且 pending，對方也有反向 → 升級自己這筆為 accepted
    /// 4. 沒有我→對方的關係時，檢查對方→我是否存在
    ///    - 存在 → 建立我→對方 accepted
    ///    - 不存在 → 建立我→對方 pending
    ///
    /// 注意：CloudKit Public DB 不允許修改別人建立的 record，
    /// 對方的 record 由對方下次 fetchFriends 時自動偵測升級。
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

        let targetRef = CKRecord.Reference(recordID: targetUserRef.recordID, action: .none)

        // 3. 檢查我是否已加過對方
        let existingPred = NSPredicate(
            format: "fromUserRecordID == %@ AND toUserRecordID == %@", myRef, targetRef
        )
        let existingQuery = CKQuery(recordType: "FriendRelation", predicate: existingPred)
        let (existingResults, _) = try await database.records(matching: existingQuery, resultsLimit: 1)

        if let (_, result) = existingResults.first, let existingRecord = try? result.get() {
            let existingStatus = existingRecord["status"] as? String ?? ""
            if existingStatus == "accepted" {
                throw FriendServiceError.alreadyFriends
            }
            // 已有 pending，查對方是否也加了我 → 升級自己這筆
            let reversePred = NSPredicate(
                format: "fromUserRecordID == %@ AND toUserRecordID == %@", targetRef, myRef
            )
            let reverseQuery = CKQuery(recordType: "FriendRelation", predicate: reversePred)
            let (reverseResults, _) = try await database.records(matching: reverseQuery, resultsLimit: 1)

            if reverseResults.first != nil {
                existingRecord["status"] = "accepted" as CKRecordValue
                _ = try await database.save(existingRecord)
                appLog("[FriendService] 升級已有記錄為 accepted, code: \(code)")
            } else {
                throw FriendServiceError.alreadyFriends
            }
            await fetchFriends()
            return
        }

        // 4. 沒有我→對方，檢查對方→我是否存在
        let reversePred = NSPredicate(
            format: "fromUserRecordID == %@ AND toUserRecordID == %@", targetRef, myRef
        )
        let reverseQuery = CKQuery(recordType: "FriendRelation", predicate: reversePred)
        let (reverseResults, _) = try await database.records(matching: reverseQuery, resultsLimit: 1)

        appLog("[FriendService] 反向查詢結果: \(reverseResults.count) 筆")

        let status: String
        if reverseResults.first != nil {
            status = "accepted"
            appLog("[FriendService] 互加成功！code: \(code)")
        } else {
            status = "pending"
            appLog("[FriendService] 已發送好友請求, code: \(code)")
        }

        let myRelation = CKRecord(recordType: "FriendRelation")
        myRelation["fromUserRecordID"] = myRef
        myRelation["toUserRecordID"] = targetRef
        myRelation["status"] = status as CKRecordValue
        myRelation["createdAt"] = Date() as CKRecordValue
        _ = try await database.save(myRelation)

        await fetchFriends()
    }
    
    // MARK: - Fetch Friends
    
    /// 查詢所有好友關係，分為：已接受、等待對方、對方已加你
    ///
    /// 判斷邏輯（以我的角度）：
    /// - 我→對方 存在 + 對方→我 存在 → accepted（若我的 record 還是 pending 則自動升級）
    /// - 我→對方 存在 + 對方→我 不存在 → outgoing pending
    /// - 我→對方 不存在 + 對方→我 存在 → incoming（顯示「加為好友」按鈕）
    func fetchFriends() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await ensureiCloudAvailable()
            let myUserRecordID = try await currentUserRecordID()
            let myRef = CKRecord.Reference(recordID: myUserRecordID, action: .none)

            // 查詢「我加別人」（容錯）
            let fromRecords: [CKRecord]
            do {
                let fromPred = NSPredicate(format: "fromUserRecordID == %@", myRef)
                let fromQuery = CKQuery(recordType: "FriendRelation", predicate: fromPred)
                let (results, _) = try await database.records(matching: fromQuery)
                fromRecords = results.compactMap { try? $0.1.get() }
            } catch {
                appLog("[FriendService] 查詢 FriendRelation(from) 失敗: \(error.localizedDescription)")
                fromRecords = []
            }

            // 查詢「別人加我」（容錯）
            let toRecords: [CKRecord]
            do {
                let toPred = NSPredicate(format: "toUserRecordID == %@", myRef)
                let toQuery = CKQuery(recordType: "FriendRelation", predicate: toPred)
                let (results, _) = try await database.records(matching: toQuery)
                toRecords = results.compactMap { try? $0.1.get() }
            } catch {
                appLog("[FriendService] 查詢 FriendRelation(to) 失敗: \(error.localizedDescription)")
                toRecords = []
            }

            // 建立「對方→我」的 lookup（key = 對方的 recordID name）
            var reverseByUser: [String: CKRecord] = [:]
            for record in toRecords {
                if let senderRef = record["fromUserRecordID"] as? CKRecord.Reference {
                    reverseByUser[senderRef.recordID.recordName] = record
                }
            }

            var accepted: [FriendData] = []
            var outgoing: [FriendData] = []
            var incoming: [FriendData] = []
            var processedUserIDs: Set<String> = []  // 避免重複

            // 處理「我加別人」
            for record in fromRecords {
                guard let targetRef = record["toUserRecordID"] as? CKRecord.Reference else { continue }
                let targetUserID = targetRef.recordID.recordName
                processedUserIDs.insert(targetUserID)

                let myStatus = record["status"] as? String ?? "pending"
                let hasReverse = reverseByUser[targetUserID] != nil

                // 雙向都存在 → accepted（自動升級自己的 record）
                if hasReverse {
                    if myStatus != "accepted" {
                        record["status"] = "accepted" as CKRecordValue
                        do {
                            _ = try await database.save(record)
                            appLog("[FriendService] 自動升級為 accepted: \(targetUserID)")
                        } catch {
                            appLog("[FriendService] 自動升級失敗: \(error.localizedDescription)")
                        }
                    }
                    if let profile = try? await resolveProfile(for: targetRef) {
                        accepted.append(FriendData(
                            id: record.recordID.recordName,
                            displayName: profile["displayName"] as? String ?? "Unknown",
                            friendCode: profile["friendCode"] as? String ?? "",
                            status: "accepted",
                            isIncoming: false,
                            totalMiles: profile["totalMiles"] as? Int ?? 0,
                            goalCount: profile["goalCount"] as? Int ?? 0,
                            completedRoutesCount: profile["completedRoutesCount"] as? Int ?? 0
                        ))
                    }
                } else if myStatus == "accepted" {
                    // 我的是 accepted 但對方已刪除反向 → 仍顯示為好友
                    if let profile = try? await resolveProfile(for: targetRef) {
                        accepted.append(FriendData(
                            id: record.recordID.recordName,
                            displayName: profile["displayName"] as? String ?? "Unknown",
                            friendCode: profile["friendCode"] as? String ?? "",
                            status: "accepted",
                            isIncoming: false,
                            totalMiles: profile["totalMiles"] as? Int ?? 0,
                            goalCount: profile["goalCount"] as? Int ?? 0,
                            completedRoutesCount: profile["completedRoutesCount"] as? Int ?? 0
                        ))
                    }
                } else {
                    // 只有我→對方 pending，對方還沒加
                    if let profile = try? await resolveProfile(for: targetRef) {
                        outgoing.append(FriendData(
                            id: record.recordID.recordName,
                            displayName: profile["displayName"] as? String ?? "Unknown",
                            friendCode: profile["friendCode"] as? String ?? "",
                            status: "pending",
                            isIncoming: false,
                            totalMiles: 0,
                            goalCount: 0,
                            completedRoutesCount: 0
                        ))
                    }
                }
            }

            // 處理「別人加我」（只處理我還沒有反向關係的）
            for record in toRecords {
                guard let senderRef = record["fromUserRecordID"] as? CKRecord.Reference else { continue }
                let senderUserID = senderRef.recordID.recordName

                // 已在上面處理過（雙向存在）
                if processedUserIDs.contains(senderUserID) { continue }

                // 對方加了我，但我沒有反向 → incoming
                if let profile = try? await resolveProfile(for: senderRef) {
                    incoming.append(FriendData(
                        id: record.recordID.recordName,
                        displayName: profile["displayName"] as? String ?? "Unknown",
                        friendCode: profile["friendCode"] as? String ?? "",
                        status: "pending",
                        isIncoming: true,
                        totalMiles: 0,
                        goalCount: 0,
                        completedRoutesCount: 0
                    ))
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
    
    // MARK: - Remove Friend
    
    /// 刪除好友（刪除雙向的 FriendRelation 記錄）
    func removeFriend(friendCode: String) async throws {
        try await ensureiCloudAvailable()
        let myUserRecordID = try await currentUserRecordID()
        let myRef = CKRecord.Reference(recordID: myUserRecordID, action: .none)
        
        // 1. 透過 friendCode 查詢對方簡介
        let targetProfile = try await lookUpProfile(byFriendCode: friendCode.uppercased())
        guard let targetUserRef = targetProfile["userRecordID"] as? CKRecord.Reference else {
            throw FriendServiceError.profileNotFound
        }
        let targetRef = CKRecord.Reference(recordID: targetUserRef.recordID, action: .none)
        
        // 2. 刪除我加對方的記錄 (from=me, to=target)
        let myToTargetPred = NSPredicate(
            format: "fromUserRecordID == %@ AND toUserRecordID == %@", myRef, targetRef
        )
        let myToTargetQuery = CKQuery(recordType: "FriendRelation", predicate: myToTargetPred)
        let (myToTargetResults, _) = try await database.records(matching: myToTargetQuery, resultsLimit: 1)
        
        if let (recordID, _) = myToTargetResults.first {
            do {
                try await database.deleteRecord(withID: recordID)
                appLog("[FriendService] 已刪除記錄: me→\(friendCode)")
            } catch {
                appLog("[FriendService] 刪除記錄失敗: \(error.localizedDescription)")
            }
        }
        
        // 3. 刪除對方加我的記錄 (from=target, to=me)
        let targetToMyPred = NSPredicate(
            format: "fromUserRecordID == %@ AND toUserRecordID == %@", targetRef, myRef
        )
        let targetToMyQuery = CKQuery(recordType: "FriendRelation", predicate: targetToMyPred)
        let (targetToMyResults, _) = try await database.records(matching: targetToMyQuery, resultsLimit: 1)
        
        if let (recordID, _) = targetToMyResults.first {
            do {
                try await database.deleteRecord(withID: recordID)
                appLog("[FriendService] 已刪除記錄: \(friendCode)→me")
            } catch {
                appLog("[FriendService] 刪除記錄失敗: \(error.localizedDescription)")
            }
        }
        
        // 4. 重新加載好友列表
        await fetchFriends()
    }
    
    // MARK: - Sync Local Stats to UserProfile
    
    /// 將本地 SwiftData 中的里程數據同步到 CloudKit Public DB 的 UserProfile
    func syncLocalStatsToProfile(context: ModelContext) async {
        guard let profile = currentUserProfile else {
            appLog("[FriendService] syncLocalStats 跳過：尚未建立 UserProfile")
            return
        }
        
        let activePID = ActiveProgramManager.activeProgramID
        
        // 讀取本地資料
        let totalMiles: Int
        let goalCount: Int
        let completedRoutesCount: Int
        
        do {
            let accountDescriptor = FetchDescriptor<MileageAccount>()
            let allAccounts = try context.fetch(accountDescriptor)
            let programAccounts = allAccounts.filter { $0.programID == activePID }
            totalMiles = programAccounts.first?.totalMiles ?? 0
            
            let goalDescriptor = FetchDescriptor<FlightGoal>()
            let allGoals = try context.fetch(goalDescriptor)
            goalCount = allGoals.filter { $0.programID == activePID }.count
            
            let ticketDescriptor = FetchDescriptor<RedeemedTicket>()
            let allTickets = try context.fetch(ticketDescriptor)
            completedRoutesCount = allTickets.filter { $0.programID == activePID }.count
        } catch {
            appLog("[FriendService] syncLocalStats 讀取本地資料失敗: \(error.localizedDescription)")
            return
        }
        
        // 更新 CloudKit UserProfile record
        do {
            let record = try await database.record(for: profile.recordID)
            record["totalMiles"] = totalMiles as CKRecordValue
            record["goalCount"] = goalCount as CKRecordValue
            record["completedRoutesCount"] = completedRoutesCount as CKRecordValue
            record["lastUpdated"] = Date() as CKRecordValue
            
            _ = try await database.save(record)
            appLog("[FriendService] syncLocalStats 成功: miles=\(totalMiles), goals=\(goalCount), tickets=\(completedRoutesCount)")
        } catch {
            appLog("[FriendService] syncLocalStats CloudKit 更新失敗: \(error.localizedDescription)")
        }
    }
}

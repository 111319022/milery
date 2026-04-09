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

        // 統一用 recordID 重建 Reference，確保 action 一致
        let targetRef = CKRecord.Reference(recordID: targetUserRef.recordID, action: .none)

        // 3. 檢查我是否已加過對方
        let existingPred = NSPredicate(
            format: "fromUserRecordID == %@ AND toUserRecordID == %@", myRef, targetRef
        )
        let existingQuery = CKQuery(recordType: "FriendRelation", predicate: existingPred)
        let (existingResults, _) = try await database.records(matching: existingQuery, resultsLimit: 1)

        if let (_, result) = existingResults.first, let _ = try? result.get() {
            throw FriendServiceError.alreadyFriends
        }

        // 4. 檢查對方是否已加我（反向關係）
        let reversePred = NSPredicate(
            format: "fromUserRecordID == %@ AND toUserRecordID == %@", targetRef, myRef
        )
        let reverseQuery = CKQuery(recordType: "FriendRelation", predicate: reversePred)
        let (reverseResults, _) = try await database.records(matching: reverseQuery, resultsLimit: 1)

        appLog("[FriendService] 反向查詢結果: \(reverseResults.count) 筆")

          if let (_, reverseResult) = reverseResults.first,
              (try? reverseResult.get()) != nil {
            // 互加！但我只能修改自己的記錄，不能修改對方的
            // 建立/更新自己的關係記錄設置為 accepted
            let myRelation = CKRecord(recordType: "FriendRelation")
            myRelation["fromUserRecordID"] = myRef
            myRelation["toUserRecordID"] = targetRef
            myRelation["status"] = "accepted" as CKRecordValue
            myRelation["createdAt"] = Date() as CKRecordValue
            _ = try await database.save(myRelation)

            appLog("[FriendService] 已確認互加！code: \(code)")
        } else {
            // 單方加好友，建立 pending
            let myRelation = CKRecord(recordType: "FriendRelation")
            myRelation["fromUserRecordID"] = myRef
            myRelation["toUserRecordID"] = targetRef
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
            
            // 查詢「我加別人」關係（容錯：record type 不存在時回傳空）
            let fromResults: [(CKRecord.ID, Result<CKRecord, Error>)]
            do {
                let fromPred = NSPredicate(format: "fromUserRecordID == %@", myRef)
                let fromQuery = CKQuery(recordType: "FriendRelation", predicate: fromPred)
                let (results, _) = try await database.records(matching: fromQuery)
                fromResults = results
            } catch {
                appLog("[FriendService] 查詢 FriendRelation(from) 失敗（schema 可能尚未建立）: \(error.localizedDescription)")
                fromResults = []
            }
            
            // 查詢「別人加我的」關係
            let toResults: [(CKRecord.ID, Result<CKRecord, Error>)]
            do {
                let toPred = NSPredicate(format: "toUserRecordID == %@", myRef)
                let toQuery = CKQuery(recordType: "FriendRelation", predicate: toPred)
                let (results, _) = try await database.records(matching: toQuery)
                toResults = results
            } catch {
                appLog("[FriendService] 查詢 FriendRelation(to) 失敗（schema 可能尚未建立）: \(error.localizedDescription)")
                toResults = []
            }
            
            var accepted: [FriendData] = []
            var outgoing: [FriendData] = []
            var incoming: [FriendData] = []
            
            // 處理「我加別人」
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
                        isIncoming: false,
                        totalMiles: profile["totalMiles"] as? Int ?? 0,
                        goalCount: profile["goalCount"] as? Int ?? 0,
                        completedRoutesCount: profile["completedRoutesCount"] as? Int ?? 0
                    )
                    if status == "accepted" {
                        accepted.append(friend)
                    } else {
                        outgoing.append(friend)
                    }
                }
            }
            
            // 處理「別人加我」
            for (_, result) in toResults {
                guard let record = try? result.get(),
                      let senderRef = record["fromUserRecordID"] as? CKRecord.Reference,
                      let status = record["status"] as? String else { continue }

                if status == "pending" {
                    // 檢查我是否也有 fromMe→sender 的關係
                    let myFromRecord = fromResults.compactMap { (_, r) -> CKRecord? in
                        guard let rec = try? r.get(),
                              let ref = rec["toUserRecordID"] as? CKRecord.Reference,
                              ref.recordID == senderRef.recordID else { return nil }
                        return rec
                    }.first

                    if let myRecord = myFromRecord, let myStatus = myRecord["status"] as? String,
                       myStatus == "accepted" {
                        // 我已經確認了，這是互加完成的狀態
                        if let profile = try? await resolveProfile(for: senderRef) {
                            let friendCode = profile["friendCode"] as? String ?? ""
                            accepted.append(FriendData(
                                id: myRecord.recordID.recordName,
                                displayName: profile["displayName"] as? String ?? "Unknown",
                                friendCode: friendCode,
                                status: "accepted",
                                isIncoming: false,
                                totalMiles: profile["totalMiles"] as? Int ?? 0,
                                goalCount: profile["goalCount"] as? Int ?? 0,
                                completedRoutesCount: profile["completedRoutesCount"] as? Int ?? 0
                            ))
                            // 從 outgoing 移除（已升級）
                            outgoing.removeAll { $0.friendCode == friendCode }
                        }
                    } else {
                        // 對方加了我，但我還沒確認（或只是pending）
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

import Foundation
import UIKit
import CloudKit

// MARK: - 個人資料管理服務

@MainActor
@Observable
final class ProfileService {
    static let shared = ProfileService()

    private let container = CKContainer(identifier: "iCloud.com.73app.milery")
    private var database: CKDatabase { container.publicCloudDatabase }

    // MARK: - Observable State

    var avatarImage: UIImage?

    // MARK: - 常數

    private let directoryName = "ProfileImages"
    private let avatarFilename = "avatar.jpg"
    private let maxImageDimension: CGFloat = 512
    private let compressionQuality: CGFloat = 0.7

    // MARK: - 好友頭貼快取

    private let friendAvatarCache = NSCache<NSString, UIImage>()

    private init() {
        loadLocalAvatar()
    }

    // MARK: - 本地目錄

    private var profileImagesDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(directoryName)
    }

    private var avatarFileURL: URL {
        profileImagesDirectory.appendingPathComponent(avatarFilename)
    }

    private func ensureDirectoryExists() {
        let url = profileImagesDirectory
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - 載入本地頭貼

    func loadLocalAvatar() {
        let fileURL = avatarFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            avatarImage = nil
            return
        }
        avatarImage = image
        appLog("[ProfileService] 載入本地頭貼成功")
    }

    // MARK: - 儲存頭貼（本地 + CloudKit）

    /// 儲存頭貼：縮圖 → 存本地 → 上傳 CloudKit
    func saveAvatar(_ image: UIImage) {
        ensureDirectoryExists()

        let resized = resizeIfNeeded(image)
        guard let data = resized.jpegData(compressionQuality: compressionQuality) else {
            appLog("[ProfileService] JPEG 編碼失敗")
            return
        }

        do {
            try data.write(to: avatarFileURL, options: .atomic)
            avatarImage = resized
            appLog("[ProfileService] 頭貼已存本地 size=\(Int(resized.size.width))x\(Int(resized.size.height))")
        } catch {
            appLog("[ProfileService] 頭貼存檔失敗: \(error.localizedDescription)")
            return
        }

        // 非同步上傳到 CloudKit
        Task {
            await uploadAvatarToCloudKit()
        }
    }

    // MARK: - 刪除頭貼

    func deleteAvatar() {
        try? FileManager.default.removeItem(at: avatarFileURL)
        avatarImage = nil
        appLog("[ProfileService] 頭貼已刪除")

        // 清除 CloudKit 上的 avatarAsset
        Task {
            await clearAvatarOnCloudKit()
        }
    }

    // MARK: - 上傳頭貼到 CloudKit

    func uploadAvatarToCloudKit() async {
        guard let profile = FriendService.shared.currentUserProfile else {
            appLog("[ProfileService] 上傳頭貼跳過：尚未建立 UserProfile")
            return
        }

        guard FileManager.default.fileExists(atPath: avatarFileURL.path) else {
            appLog("[ProfileService] 上傳頭貼跳過：本地無頭貼檔案")
            return
        }

        do {
            let record = try await database.record(for: profile.recordID)
            let asset = CKAsset(fileURL: avatarFileURL)
            record["avatarAsset"] = asset
            _ = try await database.save(record)
            appLog("[ProfileService] 頭貼已上傳 CloudKit")
        } catch {
            appLog("[ProfileService] 頭貼上傳 CloudKit 失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - 清除 CloudKit 頭貼

    private func clearAvatarOnCloudKit() async {
        guard let profile = FriendService.shared.currentUserProfile else { return }

        do {
            let record = try await database.record(for: profile.recordID)
            record["avatarAsset"] = nil
            _ = try await database.save(record)
            appLog("[ProfileService] CloudKit 頭貼已清除")
        } catch {
            appLog("[ProfileService] 清除 CloudKit 頭貼失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - 更新顯示名稱

    /// 更新 CloudKit UserProfile 的 displayName
    func updateDisplayName(_ name: String) async {
        guard let profile = FriendService.shared.currentUserProfile else {
            appLog("[ProfileService] 更新名稱跳過：尚未建立 UserProfile")
            return
        }

        do {
            let record = try await database.record(for: profile.recordID)
            record["displayName"] = name as CKRecordValue
            _ = try await database.save(record)
            appLog("[ProfileService] CloudKit 名稱已更新: \(name)")
        } catch {
            appLog("[ProfileService] 更新 CloudKit 名稱失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - 載入好友頭貼

    /// 從 CloudKit 載入好友的頭貼（帶快取）
    func loadFriendAvatar(for recordName: String) async -> UIImage? {
        // 快取檢查
        if let cached = friendAvatarCache.object(forKey: recordName as NSString) {
            return cached
        }

        do {
            let userRef = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: recordName),
                action: .none
            )
            let predicate = NSPredicate(format: "userRecordID == %@", userRef)
            let query = CKQuery(recordType: "UserProfile", predicate: predicate)
            let (results, _) = try await database.records(matching: query, resultsLimit: 1)

            guard let (_, result) = results.first,
                  let record = try? result.get(),
                  let asset = record["avatarAsset"] as? CKAsset,
                  let fileURL = asset.fileURL,
                  let data = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: data) else {
                return nil
            }

            friendAvatarCache.setObject(image, forKey: recordName as NSString)
            return image
        } catch {
            appLog("[ProfileService] 載入好友頭貼失敗 (\(recordName)): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 圖片處理

    private func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let maxDimension = max(image.size.width, image.size.height)
        guard maxDimension > maxImageDimension else { return image }

        let scale = maxImageDimension / maxDimension
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

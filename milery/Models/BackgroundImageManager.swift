import Foundation
import UIKit

// MARK: - 背景選擇列舉

enum BackgroundSelection: Equatable, RawRepresentable {
    case none                       // 預設
    case preset(name: String)       // Asset Catalog 預設圖片
    case custom(filename: String)   // 使用者上傳圖片
    case solidColor(hex: String)    // 純色背景
    case gradient(id: String)       // 內建漸層背景

    // MARK: - RawRepresentable（手動序列化，避免與 Codable 衝突造成遞迴）

    init?(rawValue: String) {
        if rawValue == "none" || rawValue.isEmpty {
            self = .none
        } else if rawValue.hasPrefix("preset:") {
            let name = String(rawValue.dropFirst(7))
            self = .preset(name: name)
        } else if rawValue.hasPrefix("custom:") {
            let filename = String(rawValue.dropFirst(7))
            self = .custom(filename: filename)
        } else if rawValue.hasPrefix("solidColor:") {
            let hex = String(rawValue.dropFirst(11))
            self = .solidColor(hex: hex)
        } else if rawValue.hasPrefix("gradient:") {
            let id = String(rawValue.dropFirst(9))
            self = .gradient(id: id)
        } else {
            self = .none
        }
    }

    var rawValue: String {
        switch self {
        case .none:
            return "none"
        case .preset(let name):
            return "preset:\(name)"
        case .custom(let filename):
            return "custom:\(filename)"
        case .solidColor(let hex):
            return "solidColor:\(hex)"
        case .gradient(let id):
            return "gradient:\(id)"
        }
    }
}

// MARK: - 背景圖片管理器

@MainActor
final class BackgroundImageManager {
    static let shared = BackgroundImageManager()

    private let directoryName = "BackgroundImages"
    private let maxImageDimension: CGFloat = 1920
    private let compressionQuality: CGFloat = 0.8
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {
        ensureDirectoryExists()
    }

    // MARK: - 目錄

    var backgroundImagesDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(directoryName)
    }

    private func ensureDirectoryExists() {
        let url = backgroundImagesDirectory
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - 預設圖片（Asset Catalog）

    private let presetNamesInfoPlistKey = "BackgroundPresetNames"

    /// 自動抓取 Asset Catalog 中 backgroundpic 資料夾的圖片名稱。
    /// 僅讀取 App 內可存取清單，避免執行期沙盒無法掃描專案原始碼目錄。
    func presetImageNames() -> [String] {
        var results = configuredBackgroundPresetNamesFromInfoPlist()

        // 開發階段 fallback：若 plist 尚未配置，嘗試掃描專案原始碼（在沙盒通常不可用）。
        if results.isEmpty {
            results = discoverBackgroundAssetNamesFromProject()
        }

        print("[BGDBG][presetImageNames] backgroundpic-only count=\(results.count) names=\(results)")
        return results
    }

    private func configuredBackgroundPresetNamesFromInfoPlist() -> [String] {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: presetNamesInfoPlistKey) as? [String] else {
            print("[BGDBG][presetImageNames] info plist key missing: \(presetNamesInfoPlistKey)")
            return []
        }

        let sanitized = raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.replacingOccurrences(of: "backgroundpic/", with: "") }

        return Array(Set(sanitized)).sorted()
    }

    private func discoverBackgroundAssetNamesFromProject() -> [String] {
        let managerFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = managerFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let backgroundGroupURL = projectRoot.appendingPathComponent("Assets.xcassets/backgroundpic")

        guard let childPaths = try? FileManager.default.contentsOfDirectory(atPath: backgroundGroupURL.path) else {
            print("[BGDBG][presetImageNames] project scan failed path=\(backgroundGroupURL.path)")
            return []
        }

        let baseNames = childPaths
            .filter { $0.hasSuffix(".imageset") }
            .map { String($0.dropLast(".imageset".count)) }

        // 僅回傳 backgroundpic 內的 base name。
        return baseNames.sorted()
    }

    /// 從 backgroundpic 群組載入預設圖，優先 namespaced，次要回退 base name。
    /// - Note: 仍只會用 presetImageNames() 掃到的名稱，不會額外擴散到其他資料夾。
    func loadPresetImage(name: String) -> UIImage? {
        // 相容舊版：已經存成 "backgroundpic/xxx" 的值
        if name.contains("/") {
            if let img = UIImage(named: name) {
                print("[BGDBG][loadPresetImage] hit exact=\(name)")
                return img
            }
        }

        let baseName = name.replacingOccurrences(of: "backgroundpic/", with: "")

        if let img = UIImage(named: "backgroundpic/\(baseName)") {
            print("[BGDBG][loadPresetImage] hit namespaced=backgroundpic/\(baseName)")
            return img
        }
        if let img = UIImage(named: baseName) {
            print("[BGDBG][loadPresetImage] hit plain=\(baseName)")
            return img
        }
        print("[BGDBG][loadPresetImage] miss name=\(name)")
        return nil
    }

    // MARK: - 自訂圖片

    /// 儲存使用者上傳的圖片，回傳檔名（UUID.jpg）
    func saveCustomImage(_ image: UIImage) -> String? {
        let resized = resizeIfNeeded(image)
        guard let data = resized.jpegData(compressionQuality: compressionQuality) else {
            print("[BGDBG][saveCustomImage] jpeg encode failed")
            return nil
        }

        let filename = "bg_\(UUID().uuidString).jpg"
        let fileURL = backgroundImagesDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL, options: .atomic)
            imageCache.setObject(resized, forKey: filename as NSString)
            print("[BGDBG][saveCustomImage] saved filename=\(filename) size=\(Int(resized.size.width))x\(Int(resized.size.height)) bytes=\(data.count)")
            return filename
        } catch {
            print("[BGDBG][saveCustomImage] write failed filename=\(filename) error=\(error.localizedDescription)")
            return nil
        }
    }

    func saveOriginalCustomImage(_ image: UIImage, baseFilename: String) {
        let originalFilename = "original_" + baseFilename
        let fileURL = backgroundImagesDirectory.appendingPathComponent(originalFilename)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL, options: .atomic)
            print("[BGDBG][saveOriginal] saved filename=\(originalFilename) size=\(Int(image.size.width))x\(Int(image.size.height)) bytes=\(data.count)")
        } else {
            print("[BGDBG][saveOriginal] jpeg encode failed base=\(baseFilename)")
        }
    }

    func loadOriginalCustomImage(filename: String) -> UIImage? {
        let originalFilename = "original_" + filename
        let fileURL = backgroundImagesDirectory.appendingPathComponent(originalFilename)
        // 改用 Data(contentsOf:) 並強制解碼，避免重啟後 lazy decode 造成白畫面
        if let image = loadDecodedImage(at: fileURL, maxDimension: 3000) {
            print("[BGDBG][loadOriginal] hit filename=\(originalFilename) size=\(Int(image.size.width))x\(Int(image.size.height))")
            return image
        }
        print("[BGDBG][loadOriginal] miss filename=\(originalFilename), fallback to cropped=\(filename)")
        return loadCustomImage(filename: filename) // Fallback
    }

    func copyOriginalCustomImage(from oldFilename: String, to newFilename: String) {
        let oldURL = backgroundImagesDirectory.appendingPathComponent("original_" + oldFilename)
        let newURL = backgroundImagesDirectory.appendingPathComponent("original_" + newFilename)
        
        do {
            if FileManager.default.fileExists(atPath: oldURL.path) {
                let data = try Data(contentsOf: oldURL)
                try data.write(to: newURL, options: .atomic)
                print("[BGDBG][copyOriginal] copied old=\(oldFilename) -> new=\(newFilename) bytes=\(data.count)")
            } else {
                // 如果沒有原圖（舊版遺漏），把當下裁切的結果當作原圖複製
                let croppedOldURL = backgroundImagesDirectory.appendingPathComponent(oldFilename)
                if FileManager.default.fileExists(atPath: croppedOldURL.path) {
                    let data = try Data(contentsOf: croppedOldURL)
                    try data.write(to: newURL, options: .atomic)
                    print("[BGDBG][copyOriginal] fallback copied cropped old=\(oldFilename) -> new=\(newFilename) bytes=\(data.count)")
                }
            }
        } catch {
            print("[BGDBG][copyOriginal] failed old=\(oldFilename) new=\(newFilename) error=\(error.localizedDescription)")
        }
    }

    func replaceCustomImage(_ image: UIImage, filename: String) -> Bool {
        let resized = resizeIfNeeded(image)
        guard let data = resized.jpegData(compressionQuality: compressionQuality) else { return false }
        let fileURL = backgroundImagesDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL, options: .atomic)
            imageCache.setObject(resized, forKey: filename as NSString)
            return true
        } catch {
            return false
        }
    }

    /// 從磁碟載入自訂圖片（帶快取）
    func loadCustomImage(filename: String) -> UIImage? {
        if let cached = imageCache.object(forKey: filename as NSString) {
            print("[BGDBG][loadCustom] cache hit filename=\(filename) size=\(Int(cached.size.width))x\(Int(cached.size.height))")
            return cached
        }

        let fileURL = backgroundImagesDirectory.appendingPathComponent(filename)
        guard let image = loadDecodedImage(at: fileURL, maxDimension: maxImageDimension) else {
            print("[BGDBG][loadCustom] failed filename=\(filename)")
            return nil
        }

        imageCache.setObject(image, forKey: filename as NSString)
        print("[BGDBG][loadCustom] disk hit filename=\(filename) size=\(Int(image.size.width))x\(Int(image.size.height))")
        return image
    }

    /// 刪除自訂圖片
    func deleteCustomImage(filename: String) {
        let fileURL = backgroundImagesDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
        
        let originalFileURL = backgroundImagesDirectory.appendingPathComponent("original_" + filename)
        try? FileManager.default.removeItem(at: originalFileURL)
        
        imageCache.removeObject(forKey: filename as NSString)
        print("[BGDBG][delete] removed filename=\(filename) and original_\(filename)")
    }

    /// 列出所有自訂圖片檔名（包含原圖與裁切圖，作為除錯用）
    func listAllCustomImages() -> [String] {
        let url = backgroundImagesDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return [] }
        return files
            .filter { $0.hasSuffix(".jpg") }
            .sorted()
    }

    /// 列出所有自訂圖片檔名
    func listCustomImages() -> [String] {
        let url = backgroundImagesDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return [] }
        let result = files
            .filter { $0.hasSuffix(".jpg") && !$0.hasPrefix("original_") }
            .sorted()
        print("[BGDBG][listCustomImages] count=\(result.count)")
        return result
    }

    /// 取得自訂圖片檔案的 URL (供除錯管理使用)
    func customImageURL(filename: String) -> URL? {
        return backgroundImagesDirectory.appendingPathComponent(filename)
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

    private func loadDecodedImage(at fileURL: URL, maxDimension: CGFloat) -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
                        print("[BGDBG][loadDecodedImage] read/decode failed path=\(fileURL.lastPathComponent)")
            return nil
        }

        // 重新 rasterize 成可直接渲染的 bitmap，避免重啟後第一次進入裁切器出現白畫面
        let normalized = resizeIfNeeded(image)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let targetSize: CGSize
        let currentMax = max(normalized.size.width, normalized.size.height)
        if currentMax > maxDimension {
            let ratio = maxDimension / currentMax
            targetSize = CGSize(width: normalized.size.width * ratio, height: normalized.size.height * ratio)
        } else {
            targetSize = normalized.size
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        print("[BGDBG][loadDecodedImage] ok path=\(fileURL.lastPathComponent) src=\(Int(image.size.width))x\(Int(image.size.height)) rendered=\(Int(rendered.size.width))x\(Int(rendered.size.height)) bytes=\(data.count)")
        return rendered
    }

    // MARK: - 輔助

    /// 取得背景選擇的描述文字
    static func displayName(for selection: BackgroundSelection) -> String {
        switch selection {
        case .none: return "預設"
        case .preset(let name): return name
        case .custom: return "自訂圖片"
        case .solidColor: return "純色背景"
        case .gradient(let id):
            return GradientRegistry.definition(for: id)?.name ?? "漸層背景"
        }
    }
}

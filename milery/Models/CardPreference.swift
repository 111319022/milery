import Foundation
import SwiftData

/// 輕量級信用卡偏好設定，透過 SwiftData + CloudKit 同步。
/// 信用卡定義（費率等）以程式碼為準，此 Model 僅儲存用戶的啟用狀態與等級選擇。
@Model
final class CardPreference {
    /// 使用 CardBrand.rawValue 作為識別（不使用 .unique，因 CloudKit 不支援 unique constraints）
    var cardBrandRaw: String = ""
    var isActive: Bool = false
    var tierRaw: String = ""
    
    init(cardBrand: CardBrand, isActive: Bool, tierID: String = "") {
        self.cardBrandRaw = cardBrand.rawValue
        self.isActive = isActive
        self.tierRaw = tierID
    }
    
    var cardBrand: CardBrand? {
        CardBrand(rawValue: cardBrandRaw)
    }
}

import Foundation
import SwiftData

/// 輕量級信用卡偏好設定，透過 SwiftData + CloudKit 同步。
/// 信用卡定義（費率等）以程式碼為準，此 Model 僅儲存用戶的啟用狀態與等級選擇。
@Model
final class CardPreference {
    /// 使用 CardBrand.rawValue 作為唯一識別
    @Attribute(.unique) var cardBrandRaw: String = ""
    var isActive: Bool = false
    var tierRaw: String = ""
    
    init(cardBrand: CardBrand, isActive: Bool, tier: CathayCardTier? = nil) {
        self.cardBrandRaw = cardBrand.rawValue
        self.isActive = isActive
        self.tierRaw = tier?.rawValue ?? ""
    }
    
    var cardBrand: CardBrand? {
        CardBrand(rawValue: cardBrandRaw)
    }
    
    var cathayTier: CathayCardTier? {
        guard !tierRaw.isEmpty else { return nil }
        return CathayCardTier(rawValue: tierRaw)
    }
}

import Foundation
import SwiftData

// MARK: - 信用卡管理（重建、偏好儲存、啟用切換、等級切換）

extension MileageViewModel {
    
    /// 信用卡規則以程式碼為準，用戶偏好（isActive / tier）透過 SwiftData CardPreference 同步。
    /// 通用版：遍歷 CardBrandRegistry.allDefinitions 建立卡片。
    func rebuildCreditCards() {
        guard let context = modelContext else { return }
        
        // 從 SwiftData 讀取 CardPreference
        let prefs: [CardPreference]
        do {
            prefs = try context.fetch(FetchDescriptor<CardPreference>())
        } catch {
            appLog("[Card] 載入信用卡偏好失敗: \(error.localizedDescription)")
            return
        }
        
        // CloudKit 不支援 unique constraints，手動清除重複記錄
        let grouped = Dictionary(grouping: prefs, by: \.cardBrandRaw)
        for (_, group) in grouped where group.count > 1 {
            for dup in group.dropFirst() { context.delete(dup) }
        }
        let dedupedPrefs = grouped.compactMapValues(\.first).values
        
        var cards: [CreditCardRule] = []
        var needsSave = false
        
        for def in CardBrandRegistry.allDefinitions {
            let pref = dedupedPrefs.first { $0.cardBrandRaw == def.brandID.rawValue }
            
            // 決定偏好值（優先使用 SwiftData，再 fallback 舊 UserDefaults，最後用預設值）
            let udActiveKey = "card_\(def.brandID.rawValue)_active"
            let udTierKey = "card_\(def.brandID.rawValue)_tier"
            
            let isActive = pref?.isActive
                ?? (UserDefaults.standard.object(forKey: udActiveKey) as? Bool)
                ?? def.defaultIsActive
            
            let tierID = {
                if let raw = pref?.tierRaw, !raw.isEmpty, def.tier(for: raw) != nil { return raw }
                if let raw = UserDefaults.standard.string(forKey: udTierKey), def.tier(for: raw) != nil { return raw }
                return def.defaultTierID
            }()
            
            let card = def.makeCard(tierID: tierID)
            card.isActive = isActive
            cards.append(card)
            
            // 確保 CardPreference 記錄存在
            if pref == nil {
                let newPref = CardPreference(cardBrand: def.brandID, isActive: isActive, tierID: tierID)
                context.insert(newPref)
                needsSave = true
            }
        }
        
        self.creditCards = cards
        
        if needsSave {
            saveContext()
        }
        
        // 清理 store 中殘留的舊版 CreditCardRule 記錄
        do {
            let existing = try context.fetch(FetchDescriptor<CreditCardRule>())
            if !existing.isEmpty {
                for card in existing {
                    context.delete(card)
                }
                saveContext()
            }
        } catch {
            appLog("[Card] 清理舊版 CreditCardRule 失敗: \(error.localizedDescription)")
        }
    }
    
    /// 儲存信用卡用戶偏好到 SwiftData CardPreference（透過 CloudKit 同步）
    func saveCardPreferences() {
        guard let context = modelContext else { return }
        let prefs: [CardPreference]
        do {
            prefs = try context.fetch(FetchDescriptor<CardPreference>())
        } catch {
            appLog("[Card] 儲存偏好時讀取失敗: \(error.localizedDescription)")
            return
        }
        
        for card in creditCards {
            if let pref = prefs.first(where: { $0.cardBrandRaw == card.cardBrandRaw }) {
                pref.isActive = card.isActive
                pref.tierRaw = card.cardTierRaw
            } else {
                let newPref = CardPreference(
                    cardBrand: card.cardBrand,
                    isActive: card.isActive,
                    tierID: card.cardTierRaw
                )
                context.insert(newPref)
            }
        }
        saveContext()
    }
    
    // 新增信用卡
    func addCreditCard(_ card: CreditCardRule) {
        guard let context = modelContext else { return }
        context.insert(card)
        saveContext()
        loadData()
    }
    
    // 刪除信用卡
    func deleteCreditCard(_ card: CreditCardRule) {
        guard let context = modelContext else { return }
        context.delete(card)
        saveContext()
        loadData()
    }
    
    // 切換信用卡啟用狀態
    func toggleCardActive(_ card: CreditCardRule) {
        card.isActive.toggle()
        saveCardPreferences()
    }
    
    // 通用切換卡片等級
    func updateCardTier(_ card: CreditCardRule, tierID: String) {
        card.updateTier(tierID)
        saveCardPreferences()
    }
}

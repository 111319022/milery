import Foundation
import SwiftData

@Model
final class MileageProgram {
    var id: UUID = UUID()
    var name: String = "Asia Miles"
    var programTypeRaw: String = MilageProgramType.asiaMiles.rawValue
    var createdDate: Date = Date()
    var isDefault: Bool = false

    var programType: MilageProgramType {
        get { MilageProgramType(rawValue: programTypeRaw) ?? .custom }
        set { programTypeRaw = newValue.rawValue }
    }

    init(name: String, programType: MilageProgramType, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.programTypeRaw = programType.rawValue
        self.createdDate = Date()
        self.isDefault = isDefault
    }
}

/// 里程計劃類型
enum MilageProgramType: String, Codable, CaseIterable {
    case asiaMiles = "亞洲萬里通"
    case custom = "自訂里程計劃"

    var icon: String {
        switch self {
        case .asiaMiles: return "airplane.circle.fill"
        case .custom: return "star.circle.fill"
        }
    }

    /// 是否支援 CathayAwardChart 自動計算
    var supportsCathayAwardChart: Bool {
        self == .asiaMiles
    }
}

/// 管理當前啟用的里程計劃
enum ActiveProgramManager {
    private static let key = "activeMileageProgramID"

    static var activeProgramID: UUID? {
        get {
            guard let str = UserDefaults.standard.string(forKey: key) else { return nil }
            return UUID(uuidString: str)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: key)
        }
    }
}

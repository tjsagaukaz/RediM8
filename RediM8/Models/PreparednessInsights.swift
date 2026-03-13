import Foundation

struct ForgottenItemInsight: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let priority: Int
}

enum SupplyExpiryStatus: Equatable {
    case overdue
    case expiringSoon
    case healthy
}

struct SupplyExpiryReminder: Identifiable, Equatable {
    let id: UUID
    let itemName: String
    let categoryTitle: String
    let expiryDate: Date
    let daysUntilExpiry: Int
    let status: SupplyExpiryStatus

    var title: String {
        if daysUntilExpiry < 0 {
            return "\(itemName) expired \(abs(daysUntilExpiry)) days ago"
        }
        if daysUntilExpiry == 0 {
            return "\(itemName) expires today"
        }
        if daysUntilExpiry == 1 {
            return "\(itemName) expires tomorrow"
        }
        return "\(itemName) expires in \(daysUntilExpiry) days"
    }

    var detail: String {
        "\(categoryTitle) • Replace before \(DateFormatter.rediM8Short.string(from: expiryDate))"
    }
}

struct FamilyRoleTask: Identifiable, Equatable {
    let id: UUID
    let memberName: String
    let role: String
    let taskTitle: String
    let taskDetail: String
    let systemImage: String
    let isPrimaryUser: Bool
}

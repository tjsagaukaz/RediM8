import Foundation

enum SupplyExpiryCategory: String, CaseIterable, Codable, Identifiable {
    case medication
    case batteries
    case food
    case waterTreatment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .medication:
            "Medications"
        case .batteries:
            "Batteries"
        case .food:
            "Food"
        case .waterTreatment:
            "Water Treatment"
        }
    }

    var systemImage: String {
        switch self {
        case .medication:
            "pills.fill"
        case .batteries:
            "battery.100"
        case .food:
            "fork.knife"
        case .waterTreatment:
            "drop.fill"
        }
    }

    var defaultItemName: String {
        switch self {
        case .medication:
            "First aid kit"
        case .batteries:
            "Backup batteries"
        case .food:
            "Shelf-stable food"
        case .waterTreatment:
            "Water treatment tablets"
        }
    }

    var defaultReminderLeadDays: Int {
        switch self {
        case .medication:
            60
        case .batteries:
            90
        case .food:
            45
        case .waterTreatment:
            60
        }
    }

    var defaultShelfLifeMonths: Int {
        switch self {
        case .medication:
            6
        case .batteries:
            12
        case .food:
            6
        case .waterTreatment:
            12
        }
    }
}

struct SupplyExpiryItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var category: SupplyExpiryCategory
    var quantity: String
    var expiryDate: Date
    var reminderLeadDays: Int

    init(
        id: UUID = UUID(),
        name: String,
        category: SupplyExpiryCategory,
        quantity: String = "",
        expiryDate: Date,
        reminderLeadDays: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.expiryDate = expiryDate
        self.reminderLeadDays = reminderLeadDays ?? category.defaultReminderLeadDays
    }

    static func starter(category: SupplyExpiryCategory, calendar: Calendar = .current, referenceDate: Date = .now) -> SupplyExpiryItem {
        let expiryDate = calendar.date(byAdding: .month, value: category.defaultShelfLifeMonths, to: referenceDate) ?? referenceDate
        return SupplyExpiryItem(
            name: category.defaultItemName,
            category: category,
            expiryDate: expiryDate
        )
    }
}

struct Supplies: Codable, Equatable {
    var waterLitres: Double
    var foodDays: Double
    var fuelLitres: Double
    var batteryCapacity: Double
    var trackedExpiryItems: [SupplyExpiryItem]

    init(
        waterLitres: Double,
        foodDays: Double,
        fuelLitres: Double,
        batteryCapacity: Double,
        trackedExpiryItems: [SupplyExpiryItem] = []
    ) {
        self.waterLitres = waterLitres
        self.foodDays = foodDays
        self.fuelLitres = fuelLitres
        self.batteryCapacity = batteryCapacity
        self.trackedExpiryItems = trackedExpiryItems
    }

    static let empty = Supplies(
        waterLitres: 20,
        foodDays: 3,
        fuelLitres: 10,
        batteryCapacity: 30,
        trackedExpiryItems: []
    )

    private enum CodingKeys: String, CodingKey {
        case waterLitres
        case foodDays
        case fuelLitres
        case batteryCapacity
        case trackedExpiryItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        waterLitres = try container.decodeIfPresent(Double.self, forKey: .waterLitres) ?? 20
        foodDays = try container.decodeIfPresent(Double.self, forKey: .foodDays) ?? 3
        fuelLitres = try container.decodeIfPresent(Double.self, forKey: .fuelLitres) ?? 10
        batteryCapacity = try container.decodeIfPresent(Double.self, forKey: .batteryCapacity) ?? 30
        trackedExpiryItems = try container.decodeIfPresent([SupplyExpiryItem].self, forKey: .trackedExpiryItems) ?? []
    }
}

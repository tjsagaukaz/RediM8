import Foundation

struct WaterRuntimeEstimate: Equatable {
    let storedWaterLitres: Double
    let dailyUseLitres: Double
    let estimatedDays: Double
    let recommendedTargetLitres: Double
    let recommendedReserveDays: Int

    var estimatedDaysText: String {
        guard estimatedDays.isFinite else {
            return "0 days"
        }
        if estimatedDays >= 10 {
            return "\(estimatedDays.roundedIntString) days"
        }
        return String(format: "%.1f days", max(estimatedDays, 0))
    }

    var recommendedTargetText: String {
        "\(recommendedTargetLitres.roundedIntString)L"
    }

    var statusTitle: String {
        if estimatedDays >= Double(recommendedReserveDays) {
            return "On Target"
        }
        if estimatedDays >= 3 {
            return "Below Target"
        }
        return "Urgent Gap"
    }

    var statusMessage: String {
        if estimatedDays >= Double(recommendedReserveDays) {
            return "Your stored water covers the current \(recommendedReserveDays)-day planning target."
        }

        let shortfall = max(recommendedTargetLitres - storedWaterLitres, 0)
        if estimatedDays >= 3 {
            return "Add \(shortfall.roundedIntString)L to reach the current \(recommendedReserveDays)-day target."
        }

        return "You only have about \(estimatedDaysText) of water at the current usage rate. Add \(shortfall.roundedIntString)L as soon as practical."
    }
}

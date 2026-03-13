import Foundation

final class WaterRuntimeService {
    private let prepService: PrepService
    private let recommendedReserveDays = 7

    init(prepService: PrepService) {
        self.prepService = prepService
    }

    func estimate(for profile: UserProfile, scenarios: [PrepScenario]) -> WaterRuntimeEstimate {
        let targets = prepService.recommendedTargets(for: profile, scenarios: scenarios)
        let dailyUseLitres = max(targets.waterLitres / Double(recommendedReserveDays), 0.1)
        let estimatedDays = profile.supplies.waterLitres / dailyUseLitres

        return WaterRuntimeEstimate(
            storedWaterLitres: profile.supplies.waterLitres,
            dailyUseLitres: dailyUseLitres,
            estimatedDays: estimatedDays,
            recommendedTargetLitres: targets.waterLitres,
            recommendedReserveDays: recommendedReserveDays
        )
    }
}

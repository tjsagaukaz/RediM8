import Combine
import Foundation

@MainActor
final class GoBagViewModel: ObservableObject {
    @Published private(set) var plan: GoBagPlan
    @Published private(set) var evacuationPrepScore: Int

    private let appState: AppState
    private let goBagService: GoBagService
    private var profile: UserProfile
    private var prepScore: PrepScore
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        goBagService = appState.goBagService
        profile = appState.profile
        prepScore = appState.prepScore
        plan = goBagService.plan(for: appState.profile)
        evacuationPrepScore = Self.evacuationScore(from: appState.prepScore)

        appState.$profile
            .sink { [weak self] profile in
                guard let self else { return }
                self.profile = profile
                self.refresh()
            }
            .store(in: &cancellables)

        appState.$prepScore
            .sink { [weak self] score in
                guard let self else { return }
                self.prepScore = score
                self.refresh()
            }
            .store(in: &cancellables)

        goBagService.$completedItemIDs
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    func isItemComplete(_ itemID: String) -> Bool {
        goBagService.isItemComplete(itemID)
    }

    func setItemComplete(_ itemID: String, isComplete: Bool) {
        goBagService.setItem(itemID, isComplete: isComplete)
    }

    private func refresh() {
        plan = goBagService.plan(for: profile)
        evacuationPrepScore = Self.evacuationScore(from: prepScore)
    }

    private static func evacuationScore(from prepScore: PrepScore) -> Int {
        prepScore.categoryScores.first(where: { $0.category == .evacuation })?.score ?? 0
    }
}

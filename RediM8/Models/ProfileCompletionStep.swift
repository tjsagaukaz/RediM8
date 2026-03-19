import Foundation

struct ProfileCompletionStep: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let isComplete: Bool
}

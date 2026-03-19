import SwiftUI

struct ProfileCompletionCard: View {
    let profile: UserProfile
    let onStepTapped: (ProfileCompletionStep) -> Void

    @State private var isExpanded = false

    private var steps: [ProfileCompletionStep] { profile.profileCompletionSteps }
    private var completedCount: Int { steps.filter(\.isComplete).count }
    private var totalCount: Int { steps.count }
    private var fraction: Double { profile.profileCompletionFraction }

    var body: some View {
        CollapsiblePanelCard(
            title: "Complete Your Profile",
            subtitle: "\(completedCount) of \(totalCount) sections done. Each one makes RediM8 more useful.",
            accent: fraction >= 1.0 ? ColorTheme.ready : ColorTheme.info,
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 4) {
                progressHeader

                ForEach(steps) { step in
                    stepRow(step)
                }
            }
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(ColorTheme.divider, lineWidth: 5)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        fraction >= 1.0 ? ColorTheme.ready : ColorTheme.info,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(fraction * 100))%")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(ColorTheme.text)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(fraction >= 1.0 ? "Profile Complete" : "Keep Building")
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)

                Text(fraction >= 1.0
                     ? "RediM8 has everything it needs for accurate planning."
                     : "Fill in each section so targets, scores, and emergency shortcuts are accurate.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 8)
    }

    private func stepRow(_ step: ProfileCompletionStep) -> some View {
        Button {
            if !step.isComplete {
                onStepTapped(step)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(step.isComplete ? ColorTheme.ready.opacity(0.16) : ColorTheme.divider.opacity(0.4))
                        .frame(width: 34, height: 34)

                    Image(systemName: step.isComplete ? "checkmark" : step.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(step.isComplete ? ColorTheme.ready : ColorTheme.textMuted)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(step.isComplete ? ColorTheme.textMuted : ColorTheme.text)
                        .strikethrough(step.isComplete)

                    if !step.isComplete {
                        Text(step.detail)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textFaint)
                    }
                }

                Spacer()

                if !step.isComplete {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTheme.textFaint)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                step.isComplete ? Color.clear : Color.black.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(step.isComplete)
    }
}

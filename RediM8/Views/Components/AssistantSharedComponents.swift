import SwiftUI

struct UserQueryBubble: View {
    let query: String

    var body: some View {
        HStack {
            Spacer(minLength: 24)

            Text(query)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [
                            ColorTheme.panelRaised,
                            ColorTheme.panelElevated
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ColorTheme.info.opacity(0.16), lineWidth: 1)
                )
        }
    }
}

struct AssistantComposerBar: View {
    @Binding var draft: String
    let placeholder: String
    let supportLine: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                TextField(placeholder, text: $draft, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(TacticalTextFieldStyle())

                Text(supportLine)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textFaint)
            }

            Button {
                onSubmit()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(
                        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ColorTheme.textFaint
                            : ColorTheme.info
                    )
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

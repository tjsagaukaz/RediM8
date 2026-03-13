import SwiftUI

struct EmergencyCardDeckView: View {
    let cards: [Guide]
    @Binding var selectedGuide: Guide?

    var body: some View {
        if cards.isEmpty {
            Text("Emergency cards are unavailable right now. Reopen the app to restore offline guidance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            TabView {
                ForEach(cards) { guide in
                    Button {
                        selectedGuide = guide
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                Text("Emergency Card")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(ColorTheme.warning)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(ColorTheme.warning.opacity(0.14), in: Capsule())

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(guide.title)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text(guide.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(guide.steps.prefix(4).enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(index + 1).")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(ColorTheme.warning)
                                        Text(step)
                                            .font(.subheadline)
                                            .foregroundStyle(ColorTheme.text)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 260)
        }
    }
}

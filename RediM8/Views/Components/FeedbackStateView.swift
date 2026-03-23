import SwiftUI

// MARK: - Data State

/// Represents the lifecycle of an async data operation.
/// Use in ViewModels to drive FeedbackStateView in the UI.
enum DataState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(String)
    case offlineFallback(T, reason: String)
    /// Data is available but may be outdated. Shows content with a staleness banner.
    case stale(T, reason: String)
    /// Fresh data is being fetched while showing previous data. Shows content with a refresh indicator.
    case refreshing(T)
}

extension DataState {
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isRefreshing: Bool {
        if case .refreshing = self { return true }
        return false
    }

    var value: T? {
        switch self {
        case let .loaded(value), let .offlineFallback(value, _),
             let .stale(value, _), let .refreshing(value):
            return value
        default:
            return nil
        }
    }

    var errorMessage: String? {
        if case let .failed(message) = self { return message }
        return nil
    }
}

// MARK: - Feedback Views

/// Loading indicator styled for RediM8's dark command UI.
struct LoadingFeedbackView: View {
    let message: String

    init(_ message: String = "Loading…") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: RediSpacing.content) {
            ProgressView()
                .tint(ColorTheme.accent)

            Text(message)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

/// Error state with retry action.
struct FailedFeedbackView: View {
    let message: String
    let retryAction: (() -> Void)?

    init(_ message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retry
    }

    var body: some View {
        VStack(spacing: RediSpacing.content) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(ColorTheme.warning)

            Text(message)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)

            if let retryAction {
                Button(action: retryAction) {
                    Text("RETRY")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.accent)
                        .padding(.horizontal, RediSpacing.content)
                        .padding(.vertical, RediSpacing.compact)
                        .background(ColorTheme.gunmetal)
                        .clipShape(RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                                .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

/// Offline fallback banner — shows at top of content when using cached data.
struct OfflineFallbackBanner: View {
    let reason: String

    var body: some View {
        HStack(spacing: RediSpacing.compact) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTheme.warning)

            Text(reason)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, RediSpacing.card)
        .padding(.vertical, RediSpacing.compact)
        .background(ColorTheme.warning.opacity(0.06))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorTheme.warning.opacity(0.2))
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline: \(reason)")
    }
}

/// Stale data banner — shows at top of content when data may be outdated.
struct StaleBanner: View {
    let reason: String

    var body: some View {
        HStack(spacing: RediSpacing.compact) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTheme.textSecondary)

            Text(reason)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, RediSpacing.card)
        .padding(.vertical, RediSpacing.compact)
        .background(ColorTheme.textSecondary.opacity(0.06))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorTheme.textSecondary.opacity(0.2))
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stale data: \(reason)")
    }
}

/// Refreshing indicator — inline spinner shown above content during background refresh.
struct RefreshingBanner: View {
    var body: some View {
        HStack(spacing: RediSpacing.compact) {
            ProgressView()
                .tint(ColorTheme.accent)
                .scaleEffect(0.7)

            Text("Updating…")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, RediSpacing.card)
        .padding(.vertical, RediSpacing.compact)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Refreshing data")
    }
}

// MARK: - Convenience Container

/// Renders loading/failed/offline states automatically from a DataState value.
/// Pass content to render when data is available.
struct DataStateView<T, Content: View>: View {
    let state: DataState<T>
    let loadingMessage: String
    let retryAction: (() -> Void)?
    private let content: (T) -> Content

    init(
        _ state: DataState<T>,
        loadingMessage: String = "Loading…",
        retry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.state = state
        self.loadingMessage = loadingMessage
        self.retryAction = retry
        self.content = content
    }

    var body: some View {
        switch state {
        case .idle:
            EmptyView()

        case .loading:
            LoadingFeedbackView(loadingMessage)

        case let .loaded(value):
            content(value)

        case let .failed(message):
            FailedFeedbackView(message, retry: retryAction)

        case let .offlineFallback(value, reason):
            VStack(spacing: 0) {
                OfflineFallbackBanner(reason: reason)
                content(value)
            }

        case let .stale(value, reason):
            VStack(spacing: 0) {
                StaleBanner(reason: reason)
                content(value)
            }

        case let .refreshing(value):
            VStack(spacing: 0) {
                RefreshingBanner()
                content(value)
            }
        }
    }
}

// MARK: - Previews

#Preview("LoadingFeedbackView") {
    LoadingFeedbackView("Fetching weather data…")
        .background(ColorTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("FailedFeedbackView") {
    VStack(spacing: 24) {
        FailedFeedbackView("Unable to reach server. Check your connection.", retry: {})
        FailedFeedbackView("Data corrupted.")
    }
    .background(ColorTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("StaleBanner") {
    VStack(spacing: 0) {
        StaleBanner(reason: "Last refreshed 45 minutes ago")

        Text("Content below the banner")
            .font(RediTypography.body)
            .foregroundStyle(ColorTheme.text)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
    .background(ColorTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("RefreshingBanner") {
    VStack(spacing: 0) {
        RefreshingBanner()

        Text("Content below the banner")
            .font(RediTypography.body)
            .foregroundStyle(ColorTheme.text)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
    .background(ColorTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("OfflineFallbackBanner") {
    VStack(spacing: 0) {
        OfflineFallbackBanner(reason: "Showing cached data from 2 hours ago")

        Text("Content below the banner")
            .font(RediTypography.body)
            .foregroundStyle(ColorTheme.text)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
    .background(ColorTheme.background)
    .preferredColorScheme(.dark)
}

import SwiftUI

extension Animation {
    static var spinnerBadgeAppearance: Animation {
        .spring(response: 0.36, dampingFraction: 0.82, blendDuration: 0.08)
    }
}

extension AnyTransition {
    static var spinnerBadgeAppearance: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.45).combined(with: .opacity),
            removal: .scale(scale: 0.82).combined(with: .opacity)
        )
    }
}

struct EmptyStateView: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
    }
}

struct NavigationTitleBadge: View {
    var title: String
    var message: String?
    var isLoadingError = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
            if isLoadingError {
                PendingErrorBadge()
                    .transition(.spinnerBadgeAppearance)
            } else if let message, !message.isEmpty {
                ErrorBadge(message: message)
            }
        }
        .animation(.spinnerBadgeAppearance, value: isLoadingError)
    }
}

struct PendingErrorBadge: View {
    var body: some View {
        ProgressView()
            .controlSize(.mini)
            .frame(width: 12, height: 12)
            .accessibilityLabel("Checking backend")
    }
}

struct BackendPageToolbar: ViewModifier {
    @EnvironmentObject private var app: AppModel
    var tab: AppTab

    func body(content: Content) -> some View {
        content
            .navigationTitle(tab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavigationTitleBadge(title: tab.title, message: app.visibleBackendErrorMessage, isLoadingError: app.showsBackendErrorSpinner)
                }
                ToolbarItem(id: "backend-refresh", placement: .topBarTrailing) {
                    RefreshToolbarButton(
                        tab: tab,
                        isRefreshing: app.isToolbarRefreshing(tab),
                        accessibilityLabel: tab.refreshAccessibilityLabel
                    ) {
                        Task { await app.refreshFromToolbar(tab) }
                    }
                    .equatable()
                }
            }
    }
}

extension View {
    func backendPageToolbar(tab: AppTab) -> some View {
        modifier(BackendPageToolbar(tab: tab))
    }
}

struct RefreshToolbarButton: View, Equatable {
    var tab: AppTab
    var isRefreshing: Bool
    var accessibilityLabel: String
    var action: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tab == rhs.tab &&
            lhs.isRefreshing == rhs.isRefreshing &&
            lhs.accessibilityLabel == rhs.accessibilityLabel
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "arrow.clockwise")
                    .opacity(isRefreshing ? 0 : 1)
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.accentColor)
                        .transition(.spinnerBadgeAppearance)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(.rect)
            .animation(.spinnerBadgeAppearance, value: isRefreshing)
        }
        .disabled(isRefreshing)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ErrorBadge: View {
    var message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption2)
            .lineLimit(1)
            .foregroundStyle(.orange)
            .labelStyle(.iconOnly)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.orange.opacity(0.14), in: Capsule())
            .accessibilityLabel(message)
    }
}

extension AppTab {
    var refreshAccessibilityLabel: String {
        switch self {
        case .proxies:
            return "Refresh proxies"
        case .rule:
            return "Refresh rules"
        case .connections:
            return "Refresh connections"
        case .more:
            return "Refresh backend"
        }
    }
}

struct StatRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

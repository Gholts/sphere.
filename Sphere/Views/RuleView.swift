import SwiftUI

struct RuleView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Rule Providers") {
                    if app.ruleProviders.isEmpty {
                        Text("No providers")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(app.ruleProviders) { provider in
                            RuleProviderRow(provider: provider) {
                                Task { await app.refreshRuleProvider(provider.name) }
                            }
                        }
                    }
                }

                Section("Rules") {
                    if app.rules.isEmpty {
                        EmptyStateView(title: "No Rules", message: "Backend returned no rule data.", systemImage: "list.bullet.rectangle")
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(app.rules) { rule in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.payload)
                                    .lineLimit(2)
                                HStack {
                                    Text(rule.type)
                                    Spacer()
                                    Text(rule.proxy)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .backendPageToolbar(tab: .rule)
            .refreshable {
                await app.refreshRules(source: .pullToRefresh)
            }
        }
    }
}

struct RuleProviderRow: View {
    var provider: RuleProvider
    var refresh: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                HStack {
                    Text(provider.behavior ?? provider.vehicleType ?? provider.type ?? "Provider")
                    if let count = provider.ruleCount {
                        Text("\(count) rules")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Refresh \(provider.name)")
        }
    }
}

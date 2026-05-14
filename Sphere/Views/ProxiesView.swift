import SwiftUI
import UIKit

struct ProxiesView: View {
    @EnvironmentObject private var app: AppModel
    private let proxyColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            List {
                if app.proxyCollection.groups.isEmpty {
                    EmptyStateView(title: "No Proxy Groups", message: "Refresh after backend connects.", systemImage: "point.3.connected.trianglepath.dotted")
                        .listRowBackground(Color.clear)
                } else {
                    Section("Providers") {
                        if app.proxyProviders.isEmpty {
                            Text("No providers")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(app.proxyProviders) { provider in
                                ProxyProviderRow(provider: provider) {
                                    Task { await app.refreshProxyProvider(provider.name) }
                                }
                            }
                        }
                    }
                    
                    Section("Groups") {
                        ForEach(app.proxyCollection.groups) { group in
                            ProxyGroupSection(group: group, proxyColumns: proxyColumns)
                        }
                    }
                }
            }
            .backendPageToolbar(tab: .proxies)
            .refreshable {
                await app.refreshProxies(source: .pullToRefresh)
            }
        }
    }
}

struct ProxyGroupSection: View {
    @EnvironmentObject private var app: AppModel
    @State private var isExpanded = false
    var group: ProxyItem
    var proxyColumns: [GridItem]

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                if isExpanded {
                    LazyVGrid(columns: proxyColumns, spacing: 8) {
                        ForEach(group.all, id: \.self) { proxyName in
                            ProxyChoiceButton(
                                name: proxyName,
                                proxy: app.proxyItem(named: proxyName),
                                isSelected: proxyName == group.now
                            ) {
                                Task { await app.selectProxy(group: group.name, proxy: proxyName) }
                            }
                        }
                    }
                    .padding(.leading, -20)
                    .padding(-5)
                }
            } label: {
                HStack(spacing: 8) {
                    ProxyIconView(icon: group.icon, size: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.headline)
                        Text("\(group.type) · \(group.all.count) nodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                isExpanded = app.isProxyGroupExpanded(group.name)
            }
            .onChange(of: group.name) {
                isExpanded = app.isProxyGroupExpanded(group.name)
            }
            .onChange(of: isExpanded) {
                app.setProxyGroupExpanded(isExpanded, groupName: group.name)
            }
        }
    }
}

struct ProxyProviderRow: View {
    var provider: ProxyProvider
    var refresh: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack() {
                    Text(provider.name)
                    Text(provider.vehicleType ?? provider.type ?? "Provider")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remains data: \(ByteFormat.bytes(provider.remainingBytes)) / \(ByteFormat.bytes(provider.totalBytes))")
                    Text("Expire: \(DateFormat.expire(provider.expireAt))")
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

struct ProxyChoiceButton: View {
    var name: String
    var proxy: ProxyItem?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ProxyIconView(icon: proxy?.icon, size: 16)
                    Text(proxy?.name ?? name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .imageScale(.small)
                    }
                }

                if let proxy {
                    ProxyMetaLine(proxy: proxy)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(proxy?.name ?? name)\(isSelected ? ", selected" : "")")
    }
}

struct ProxyMetaLine: View {
    var proxy: ProxyItem

    var body: some View {
        Text(proxy.metaBadges.joined(separator: " · "))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
}

struct ProxyIconView: View {
    var icon: String?
    var size: CGFloat = 16

    var body: some View {
        if let icon, !icon.isEmpty {
            iconBody(icon)
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: 3))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func iconBody(_ icon: String) -> some View {
        if icon.hasPrefix("data:image/svg+xml") {
            Image(systemName: "network")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        } else {
            CachedProxyIconImage(icon: icon)
                .id(icon)
        }
    }
}

private struct CachedProxyIconImage: View {
    var icon: String
    @State private var image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Color.clear
                .task(id: icon) {
                    if let cachedImage = ProxyIconCache.cachedImage(for: icon) {
                        image = cachedImage
                    } else {
                        image = await ProxyIconCache.image(for: icon)
                    }
                }
        }
    }
}

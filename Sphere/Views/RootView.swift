import SwiftUI

struct RootView: View {
    @StateObject private var app = AppModel()

    var body: some View {
        Group {
            if app.hasProfiles {
                AppTabView()
                    .environmentObject(app)
                    .environmentObject(app.liveStore)
                    .environmentObject(app.logStore)
            } else {
                ProfileWizardView()
                    .environmentObject(app)
            }
        }
    }
}

struct AppTabView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        TabView(selection: $app.selectedTab) {
            ProxiesView()
                .tabItem { Label(AppTab.proxies.title, systemImage: AppTab.proxies.symbol) }
                .tag(AppTab.proxies)

            RuleView()
                .tabItem { Label(AppTab.rule.title, systemImage: AppTab.rule.symbol) }
                .tag(AppTab.rule)

            ConnectionsView()
                .tabItem { Label(AppTab.connections.title, systemImage: AppTab.connections.symbol) }
                .tag(AppTab.connections)

            MoreView()
                .tabItem { Label(AppTab.more.title, systemImage: AppTab.more.symbol) }
                .tag(AppTab.more)
        }
        .task(id: VisibleRefreshKey(profileID: app.selectedProfileID, tab: app.selectedTab)) {
            app.stopAutoRefresh()
            app.startLiveStreams()
            await app.refreshSelectedTab(source: .automatic)
            if !Task.isCancelled {
                app.startAutoRefresh()
            }
        }
        .onDisappear {
            app.stopLiveStreams()
            app.stopAutoRefresh()
        }
    }
}

private struct VisibleRefreshKey: Equatable {
    var profileID: UUID?
    var tab: AppTab
}

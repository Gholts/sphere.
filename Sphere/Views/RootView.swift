import SwiftUI
import UIKit

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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if usesIPadSidebar {
                AppIPadSidebarTabView()
            } else {
                AppBottomTabView()
            }
        }
        .modifier(VisibleRefreshLifecycle())
    }

    private var usesIPadSidebar: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }
}

private struct AppBottomTabView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        TabView(selection: $app.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                AppTabContent(tab: tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
    }
}

private struct AppIPadSidebarTabView: View {
    @EnvironmentObject private var app: AppModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var profileForm: ProfileFormPresentation?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AppSidebarView(profileForm: $profileForm)
        } detail: {
            AppTabContent(tab: app.selectedTab)
                .environment(
                    \.iPadTopNavigationControls,
                    IPadTopNavigationControls(isPresented: columnVisibility == .detailOnly)
                )
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $profileForm) { form in
            ProfileWizardView(editingProfile: form.editingProfile, canDismiss: true)
                .environmentObject(app)
        }
    }
}

private struct AppSidebarView: View {
    @EnvironmentObject private var app: AppModel
    @Binding var profileForm: ProfileFormPresentation?
    @State private var editMode: EditMode = .inactive

    private var isEditingProfiles: Bool {
        editMode == .active
    }

    var body: some View {
        List(selection: selectedTabBinding) {
            Section("Navigation") {
                ForEach(AppTab.allCases) { tab in
                    AppSidebarTabRow(tab: tab)
                        .tag(tab)
                }
            }

            Section("Profiles") {
                if isEditingProfiles {
                    editableProfileRows
                } else {
                    ForEach(app.profiles) { profile in
                        Button {
                            app.selectProfile(profile.id)
                        } label: {
                            AppSidebarProfileRow(
                                profile: profile,
                                isSelected: profile.id == app.selectedProfile?.id
                            )
                        }
                        .buttonStyle(.plain)
                        .profileSwipeActions(
                            profile: profile,
                            profileForm: $profileForm,
                            delete: { app.deleteProfile(profile) }
                        )
                        .accessibilityLabel(profile.name)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditingProfiles ? "Done" : "Edit") {
                    withAnimation(.smooth(duration: 0.22)) {
                        editMode = isEditingProfiles ? .inactive : .active
                    }
                }
            }
        }
    }

    private var selectedTabBinding: Binding<AppTab?> {
        Binding(
            get: { app.selectedTab },
            set: { tab in
                guard let tab, tab != app.selectedTab else { return }
                app.selectedTab = tab
            }
        )
    }

    @ViewBuilder
    private var editableProfileRows: some View {
        ForEach(app.profiles) { profile in
            AppSidebarProfileRow(
                profile: profile,
                isSelected: profile.id == app.selectedProfile?.id
            )
            .profileSwipeActions(
                profile: profile,
                profileForm: $profileForm,
                delete: { app.deleteProfile(profile) }
            )
        }
        .onMove(perform: app.moveProfiles)
    }
}

private extension View {
    func profileSwipeActions(
        profile: APIProfile,
        profileForm: Binding<ProfileFormPresentation?>,
        delete: @escaping () -> Void
    ) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }

            Button {
                profileForm.wrappedValue = .edit(profile)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.accentColor)
        }
    }
}

private struct AppSidebarTabRow: View {
    var tab: AppTab

    var body: some View {
        Label(tab.title, systemImage: tab.symbol)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppSidebarProfileRow: View {
    var profile: APIProfile
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .lineLimit(1)
                Text("\(profile.kind.title) · \(profile.baseURL)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(.tint)
            }
        }
    }
}

private struct AppTabContent: View {
    var tab: AppTab

    var body: some View {
        switch tab {
        case .proxies:
            ProxiesView()
        case .rule:
            RuleView()
        case .connections:
            ConnectionsView()
        case .more:
            MoreView()
        }
    }
}

private struct VisibleRefreshLifecycle: ViewModifier {
    @EnvironmentObject private var app: AppModel

    func body(content: Content) -> some View {
        content
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

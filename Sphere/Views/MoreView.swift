import SwiftUI
import UIKit

struct MoreView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var live: LiveBackendStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var profileForm: ProfileFormPresentation?

    var body: some View {
        NavigationStack {
            List {
                Section("Backend") {
                    if !usesIPadSidebar {
                        Picker("Profile", selection: profileBinding) {
                            ForEach(app.profiles) { profile in
                                Text(profile.name).tag(Optional(profile.id))
                            }
                        }
                    }

                    Button {
                        profileForm = .add
                    } label: {
                        Label("Add Profile", systemImage: "plus.circle")
                    }

                    if let profile = app.selectedProfile {
                        AdaptiveStatRows(metrics: [
                            StatMetric(title: "Type", value: profile.kind.title),
                            StatMetric(title: "URL", value: profile.baseURL)
                        ])

                        Button {
                            profileForm = .edit(profile)
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }
                    }
                }

                Section("Overview") {
                    Picker(selection: modeBinding) {
                        ForEach(ClashMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    } label: {
                        Text("Mode")
                            .foregroundStyle(.secondary)
                    }

                    OverviewRows(overview: live.overview)
                }

                if canUpdateCore {
                    Section("Update Core") {
                        ForEach(CoreUpdateChannel.allCases) { channel in
                            Button {
                                Task { await app.upgradeCore(channel: channel) }
                            } label: {
                                Label(channel.title, systemImage: "arrow.down.circle")
                            }
                            .disabled(app.isUpdatingCore)
                        }
                    }
                }

                Section("Tools") {
                    NavigationLink {
                        ConfigEditorView()
                    } label: {
                        Label("Configuration", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink {
                        LogBookView()
                    } label: {
                        Label("Log Book", systemImage: "doc.text.magnifyingglass")
                    }
                }

                if !usesIPadSidebar {
                    Section("Profiles") {
                        ForEach(app.profiles) { profile in
                            Button {
                                profileForm = .edit(profile)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(profile.name)
                                        Text("\(profile.kind.title) · \(profile.baseURL)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                        .onDelete(perform: app.deleteProfiles)
                    }
                }
            }
            .backendPageToolbar(tab: .more)
            .sheet(item: $profileForm) { form in
                ProfileWizardView(editingProfile: form.editingProfile, canDismiss: true)
                    .environmentObject(app)
            }
            .refreshable {
                await app.refreshAll(source: .pullToRefresh)
            }
        }
    }

    private var profileBinding: Binding<UUID?> {
        Binding(
            get: { app.selectedProfileID },
            set: { app.selectProfile($0) }
        )
    }

    private var modeBinding: Binding<ClashMode> {
        Binding(
            get: { app.clashMode },
            set: { mode in Task { await app.updateMode(mode) } }
        )
    }

    private var canUpdateCore: Bool {
        app.selectedProfile?.kind == .mihomo && !live.overview.version.localizedCaseInsensitiveContains("sing-box")
    }

    private var usesIPadSidebar: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }
}

struct OverviewRows: View {
    var overview: BackendOverview

    var body: some View {
        AdaptiveStatRows(metrics: [
            StatMetric(title: "Version", value: overview.version),
            StatMetric(title: "Memory", value: ByteFormat.memoryBytes(overview.memoryBytes)),
            StatMetric(title: "Upload", value: ByteFormat.speedBytes(overview.uploadBytesPerSecond)),
            StatMetric(title: "Download", value: ByteFormat.speedBytes(overview.downloadBytesPerSecond)),
            StatMetric(title: "Active Connections", value: overview.activeConnections.map(String.init) ?? "n/a")
        ])
    }
}

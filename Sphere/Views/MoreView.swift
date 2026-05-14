import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var live: LiveBackendStore
    @State private var showAddProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section("Backend") {
                    Picker("Profile", selection: profileBinding) {
                        ForEach(app.profiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }

                    Button {
                        showAddProfile = true
                    } label: {
                        Label("Add Profile", systemImage: "plus.circle")
                    }

                    if let profile = app.selectedProfile {
                        StatRow(title: "Type", value: profile.kind.title)
                        StatRow(title: "URL", value: profile.baseURL)
                    }
                }

                Section("Mode") {
                    Picker("Mode", selection: modeBinding) {
                        ForEach(ClashMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Overview") {
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

                Section("Profiles") {
                    ForEach(app.profiles) { profile in
                        VStack(alignment: .leading) {
                            Text(profile.name)
                            Text("\(profile.kind.title) · \(profile.baseURL)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: app.deleteProfiles)
                }
            }
            .backendPageToolbar(tab: .more)
            .sheet(isPresented: $showAddProfile) {
                ProfileWizardView(canDismiss: true)
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
}

struct OverviewRows: View {
    var overview: BackendOverview

    var body: some View {
        StatRow(title: "Version", value: overview.version)
        StatRow(title: "Memory", value: ByteFormat.memoryBytes(overview.memoryBytes))
        StatRow(title: "Upload", value: ByteFormat.speedBytes(overview.uploadBytesPerSecond))
        StatRow(title: "Download", value: ByteFormat.speedBytes(overview.downloadBytesPerSecond))
        StatRow(title: "Active Connections", value: overview.activeConnections.map(String.init) ?? "n/a")
    }
}

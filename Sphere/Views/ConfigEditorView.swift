import SwiftUI

struct ConfigEditorView: View {
    @EnvironmentObject private var app: AppModel
    @State private var draft: [String: String] = [:]
    @State private var isLoadingConfig = false

    private var scalarKeys: [String] {
        app.configs.keys
            .filter { app.configs[$0]?.isScalar == true }
            .sorted()
    }

    private var nestedKeys: [String] {
        app.configs.keys
            .filter { app.configs[$0]?.isScalar == false }
            .sorted()
    }

    private var changedValues: [String: JSONValue] {
        scalarKeys.reduce(into: [:]) { result, key in
            guard let original = app.configs[key], let text = draft[key] else { return }
            let parsed = JSONScalarParser.parse(text, fallback: original)
            if parsed != original {
                result[key] = parsed
            }
        }
    }

    var body: some View {
        List {
            if isLoadingConfig && app.configs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else if app.configs.isEmpty {
                EmptyStateView(title: "No Config", message: "Refresh config or check backend connection.", systemImage: "slider.horizontal.3")
                    .listRowBackground(Color.clear)
            } else if scalarKeys.isEmpty {
                EmptyStateView(title: "No Scalar Config", message: "Backend returned only nested fields.", systemImage: "slider.horizontal.3")
                    .listRowBackground(Color.clear)
            } else {
                Section("Editable") {
                    ForEach(scalarKeys, id: \.self) { key in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(key)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField(key, text: binding(for: key))
                                .textInputAutocapitalization(.never)
                        }
                    }
                }
            }

            if !nestedKeys.isEmpty {
                Section("Nested") {
                    ForEach(nestedKeys, id: \.self) { key in
                        StatRow(title: key, value: app.configs[key]?.displayText ?? "")
                    }
                }
            }
        }
        .navigationTitle("Configuration")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await reload() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel("Reload config")
                .disabled(isLoadingConfig)

                Button {
                    Task { await save() }
                } label: {
                    Image(systemName: "checkmark")
                }
                .disabled(changedValues.isEmpty)
                .accessibilityLabel("Save config")
            }
        }
        .task(id: app.selectedProfileID) {
            await load()
        }
        .onChange(of: app.configs) {
            pruneDraft()
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { draft[key] ?? app.configs[key]?.displayText ?? "" },
            set: { draft[key] = $0 }
        )
    }

    private func load() async {
        isLoadingConfig = true
        await app.loadConfig()
        isLoadingConfig = false
        pruneDraft()
    }

    private func save() async {
        await app.patchConfig(changedValues)
        pruneDraft()
    }

    private func reload() async {
        isLoadingConfig = true
        await app.reloadConfig()
        isLoadingConfig = false
        pruneDraft()
    }

    private func pruneDraft() {
        let validKeys = Set(scalarKeys)
        draft = draft.filter { key, _ in validKeys.contains(key) }
    }
}

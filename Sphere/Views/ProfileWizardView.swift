import SwiftUI

struct ProfileWizardView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Mihomo"
    @State private var kind: BackendKind = .mihomo
    @State private var baseURL = "http://127.0.0.1:9090"
    @State private var secret = ""
    @State private var testResult: ProfileTestResult?
    @State private var isTesting = false
    private let minimumTestingIndicatorDuration: TimeInterval = 0.35
    var canDismiss = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(BackendKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    TextField("Controller URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    SecureField("Secret", text: $secret)
                        .textContentType(nil)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !kind.isImplemented {
                        Label("\(kind.title) saved only. Client comes later.", systemImage: "hammer")
                    }

                    Button {
                        Task { await test() }
                    } label: {
                        HStack(spacing: 8) {
                            Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.accentColor)
                                    .transition(.spinnerBadgeAppearance)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.tint)
                        .animation(.spinnerBadgeAppearance, value: isTesting)
                    }
                    .disabled(!kind.isImplemented || baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .allowsHitTesting(!isTesting)

                    Button {
                        saveProfile()
                    } label: {
                        Label("Save Profile", systemImage: "checkmark.circle")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let testResult {
                        Label {
                            Text(testResult.message)
                        } icon: {
                            Image(systemName: testResult.systemImage)
                        }
                        .foregroundStyle(testResult.tint)
                    }
                }
            }
            .navigationTitle("Add Backend")
            .navigationBarTitleDisplayMode(canDismiss ? .inline : .automatic)
            .toolbar {
                if canDismiss {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var profile: APIProfile {
        APIProfile(name: name, kind: kind, baseURL: baseURL, secret: secret)
    }

    private func test() async {
        guard !isTesting else { return }
        let startedAt = Date()
        isTesting = true
        let nextResult: ProfileTestResult
        do {
            let overview = try await app.testProfile(profile)
            nextResult = .success(CoreVersionDisplay.successMessage(for: overview.version, kind: kind))
        } catch {
            nextResult = .failure(error.localizedDescription)
        }
        await waitForMinimumTestingIndicatorDuration(since: startedAt)
        testResult = nextResult
        isTesting = false
    }

    private func waitForMinimumTestingIndicatorDuration(since startedAt: Date) async {
        let remaining = minimumTestingIndicatorDuration - Date().timeIntervalSince(startedAt)
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .milliseconds(Int(remaining * 1_000)))
    }

    private func saveProfile() {
        app.addProfile(profile)
        if canDismiss {
            dismiss()
        }
    }
}

private struct ProfileTestResult: Equatable {
    enum Status {
        case success
        case failure
    }

    var message: String
    var status: Status

    static func success(_ message: String) -> Self {
        Self(message: message, status: .success)
    }

    static func failure(_ message: String) -> Self {
        Self(message: message, status: .failure)
    }

    var systemImage: String {
        switch status {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch status {
        case .success:
            return .green
        case .failure:
            return .red
        }
    }
}

enum CoreVersionDisplay {
    private static let coreNameTokens = ["mihomo", "sing-box", "singbox", "clash", "surge"]

    static func successMessage(for version: String, kind: BackendKind) -> String {
        "OK: \(coreAndVersion(for: version, kind: kind))"
    }

    static func coreAndVersion(for version: String, kind: BackendKind) -> String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanVersion = trimmed.isEmpty ? "Unknown" : trimmed
        let lowercased = cleanVersion.lowercased()
        if coreNameTokens.contains(where: lowercased.contains) {
            return cleanVersion
        }
        return "\(kind.title) \(cleanVersion)"
    }
}

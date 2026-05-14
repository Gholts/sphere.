import SwiftUI

struct LogBookView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var logs: LogStore

    var body: some View {
        List {
            Section("Level") {
                Picker("Level", selection: levelBinding) {
                    ForEach(LogLevel.allCases) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Logs") {
                if logs.entries.isEmpty {
                    Text("Waiting for logs")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(logs.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.type.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(color(for: entry.type))
                                Spacer()
                                Text(entry.date.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.payload)
                                .font(.system(.footnote, design: .monospaced))
                        }
                    }
                }
            }
        }
        .navigationTitle("Log Book")
        .onAppear {
            app.startLogs()
        }
        .onDisappear {
            app.stopLogs()
        }
    }

    private var levelBinding: Binding<LogLevel> {
        Binding(
            get: { logs.level },
            set: {
                logs.level = $0
                app.startLogs()
            }
        )
    }

    private func color(for type: String) -> Color {
        switch type.lowercased() {
        case "error":
            return .red
        case "warning", "warn":
            return .orange
        case "debug":
            return .purple
        default:
            return .secondary
        }
    }
}

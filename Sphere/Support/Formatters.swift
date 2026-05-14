import Foundation

enum ByteFormat {
    static func bytes(_ value: Int64?) -> String {
        guard let value else { return "n/a" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .binary)
    }

    static func memoryBytes(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return iecBytes(Int64(value))
    }

    static func speedBytes(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file))/s"
    }

    private static func iecBytes(_ value: Int64) -> String {
        let units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
        var amount = Double(value)
        var unitIndex = 0
        while abs(amount) >= 1024, unitIndex < units.count - 1 {
            amount /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(value) B"
        }
        let number = amount >= 10 || amount.rounded() == amount
            ? String(format: "%.0f", amount)
            : String(format: "%.1f", amount)
        return "\(number) \(units[unitIndex])"
    }
}

enum DateFormat {
    static func short(_ date: Date?) -> String {
        guard let date else { return "n/a" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func expire(_ date: Date?) -> String {
        guard let date else { return "No expiry" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

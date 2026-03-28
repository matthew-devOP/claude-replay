import Foundation

extension Date {
    func relativeString() -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .full
        return f.localizedString(for: self, relativeTo: Date())
    }
    func shortRelativeString() -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: Date())
    }
}

extension TimeInterval {
    func formattedDuration() -> String {
        let t = Int(self); let h = t / 3600; let m = (t % 3600) / 60; let s = t % 60
        if h > 0 { return "\(h)h \(m)m" }
        else if m > 0 { return "\(m)m \(s)s" }
        else { return "\(s)s" }
    }
    func timerString() -> String {
        let t = Int(self); let h = t / 3600; let m = (t % 3600) / 60; let s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

extension String {
    func parseISO8601() -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: self) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: self)
    }
}

extension Int64 {
    func formattedFileSize() -> String { ByteCountFormatter.string(fromByteCount: self, countStyle: .file) }
}
extension UInt64 {
    func formattedFileSize() -> String { ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file) }
}

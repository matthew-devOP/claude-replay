import Foundation

/// Configuration options for exporting a session as an HTML replay.
struct ExportOptions: Codable, Hashable, Sendable {
    var theme: ThemeName
    var speed: Double
    var showThinking: Bool
    var showToolCalls: Bool
    var userLabel: String
    var assistantLabel: String
    var title: String
    var description: String
    var ogImage: String?
    var redactSecrets: Bool
    var bookmarks: [Bookmark]
    var minified: Bool
    var compress: Bool
    var timing: TimingOptions

    struct TimingOptions: Codable, Hashable, Sendable {
        var pauseBeforeAssistant: Int
        var charMultiplier: Int
        var minDuration: Int
        var maxDuration: Int

        static let `default` = TimingOptions(
            pauseBeforeAssistant: 500,
            charMultiplier: 30,
            minDuration: 1000,
            maxDuration: 10000
        )
    }

    static let `default` = ExportOptions(
        theme: .tokyoNight,
        speed: 1.0,
        showThinking: true,
        showToolCalls: true,
        userLabel: "Human",
        assistantLabel: "Assistant",
        title: "",
        description: "",
        ogImage: nil,
        redactSecrets: false,
        bookmarks: [],
        minified: false,
        compress: true,
        timing: .default
    )
}

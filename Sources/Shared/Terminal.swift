import AppKit

struct RKTerminal: Identifiable, Hashable {
    enum Launch: Hashable {
        case directory
        case command(String, [String])
    }

    let bundleID: String
    let name: String
    let launch: Launch

    var id: String { bundleID }
}

struct RKTerminalRequest: Codable {
    let dir: String
    let bundleID: String
}

enum RKTerminals {
    static let known: [RKTerminal] = [
        RKTerminal(bundleID: "com.apple.Terminal", name: "Terminal", launch: .directory),
        RKTerminal(bundleID: "com.googlecode.iterm2", name: "iTerm", launch: .directory),
        RKTerminal(bundleID: "dev.warp.Warp-Stable", name: "Warp", launch: .directory),
        RKTerminal(bundleID: "com.mitchellh.ghostty", name: "Ghostty",
                   launch: .command("Contents/MacOS/ghostty", ["--working-directory=$DIR"])),
        RKTerminal(bundleID: "net.kovidgoyal.kitty", name: "kitty",
                   launch: .command("Contents/MacOS/kitty", ["--directory=$DIR"])),
        RKTerminal(bundleID: "org.alacritty", name: "Alacritty",
                   launch: .command("Contents/MacOS/alacritty", ["--working-directory=$DIR"])),
        RKTerminal(bundleID: "com.github.wez.wezterm", name: "WezTerm",
                   launch: .command("Contents/MacOS/wezterm", ["start", "--cwd=$DIR"])),
    ]

    static func appURL(_ terminal: RKTerminal) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleID)
    }

    static func installed() -> [RKTerminal] {
        known.filter { appURL($0) != nil }
    }

    static func terminal(bundleID: String) -> RKTerminal? {
        known.first { $0.bundleID == bundleID }
    }

    static func preferred(_ configured: String) -> RKTerminal? {
        let available = installed()
        if !configured.isEmpty, let match = available.first(where: { $0.bundleID == configured }) {
            return match
        }
        return available.first
    }
}

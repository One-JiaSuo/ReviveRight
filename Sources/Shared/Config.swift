import Foundation
import Darwin

enum RKTemplate {
    static let all: [String] = ["txt", "md", "rtf", "docx", "doc", "xlsx", "csv", "pptx"]

    static func title(_ ext: String) -> String {
        switch ext {
        case "txt": return "文本文件.txt"
        case "md": return "Markdown.md"
        case "rtf": return "富文本.rtf"
        case "docx": return "Word 文档.docx"
        case "doc": return "Word 97 文档.doc"
        case "xlsx": return "Excel 表格.xlsx"
        case "csv": return "CSV 表格.csv"
        case "pptx": return "PowerPoint.pptx"
        default: return "未命名.\(ext)"
        }
    }

    static func icon(_ ext: String) -> String {
        switch ext {
        case "txt": return "doc.text"
        case "md": return "doc.plaintext"
        case "rtf": return "doc.richtext"
        case "docx", "doc": return "doc.text.fill"
        case "xlsx": return "tablecells"
        case "csv": return "square.grid.2x2"
        case "pptx": return "rectangle.on.rectangle"
        default: return "doc"
        }
    }

    static func normalized(_ list: [String]) -> [String] {
        all.filter { list.contains($0) }
    }
}

enum SendMode: String, Codable, CaseIterable, Identifiable {
    case copy
    case move
    var id: String { rawValue }
    var title: String { self == .copy ? "复制" : "移动" }
}

struct RKDirectory: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var path: String

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}

struct RKEnabled: Codable {
    var copyPath = true
    var copyName = true
    var copy = true
    var cut = true
    var paste = true
    var hide = true
    var extensionHidden = true
    var lock = true
    var info = true
    var alias = true
    var airdrop = true
    var folderFromName = true
    var newFile = true
    var sendTo = true
    var terminal = true
    var trash = true

    enum CodingKeys: String, CodingKey {
        case copyPath, copyName, copy, cut, paste, hide, extensionHidden, lock, info, alias, airdrop, folderFromName
        case newFile, sendTo, terminal, trash
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        copyPath = (try? c.decodeIfPresent(Bool.self, forKey: .copyPath)) ?? true
        copyName = (try? c.decodeIfPresent(Bool.self, forKey: .copyName)) ?? true
        copy = (try? c.decodeIfPresent(Bool.self, forKey: .copy)) ?? true
        cut = (try? c.decodeIfPresent(Bool.self, forKey: .cut)) ?? true
        paste = (try? c.decodeIfPresent(Bool.self, forKey: .paste)) ?? true
        hide = (try? c.decodeIfPresent(Bool.self, forKey: .hide)) ?? true
        extensionHidden = (try? c.decodeIfPresent(Bool.self, forKey: .extensionHidden)) ?? true
        lock = (try? c.decodeIfPresent(Bool.self, forKey: .lock)) ?? true
        info = (try? c.decodeIfPresent(Bool.self, forKey: .info)) ?? true
        alias = (try? c.decodeIfPresent(Bool.self, forKey: .alias)) ?? true
        airdrop = (try? c.decodeIfPresent(Bool.self, forKey: .airdrop)) ?? true
        folderFromName = (try? c.decodeIfPresent(Bool.self, forKey: .folderFromName)) ?? true
        newFile = (try? c.decodeIfPresent(Bool.self, forKey: .newFile)) ?? true
        sendTo = (try? c.decodeIfPresent(Bool.self, forKey: .sendTo)) ?? true
        terminal = (try? c.decodeIfPresent(Bool.self, forKey: .terminal)) ?? true
        trash = (try? c.decodeIfPresent(Bool.self, forKey: .trash)) ?? true
    }
}

struct RKConfig: Codable {
    var enabled = RKEnabled()
    var templates: [String] = RKTemplate.all
    var openAfterCreate = true
    var defaultTerminal = ""
    var sendMode: SendMode = .copy
    var commonDirs: [RKDirectory] = []

    enum CodingKeys: String, CodingKey {
        case enabled, templates, openAfterCreate, defaultTerminal, sendMode, commonDirs
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? c.decodeIfPresent(RKEnabled.self, forKey: .enabled)) ?? RKEnabled()
        templates = (try? c.decodeIfPresent([String].self, forKey: .templates)).map(RKTemplate.normalized) ?? RKTemplate.all
        openAfterCreate = (try? c.decodeIfPresent(Bool.self, forKey: .openAfterCreate)) ?? true
        defaultTerminal = (try? c.decodeIfPresent(String.self, forKey: .defaultTerminal)) ?? ""
        sendMode = (try? c.decodeIfPresent(SendMode.self, forKey: .sendMode)) ?? .copy
        commonDirs = (try? c.decodeIfPresent([RKDirectory].self, forKey: .commonDirs)) ?? []
    }

    static var realHome: URL {
        if let pw = getpwuid(getuid()) {
            return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir))
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var supportDirectory: URL {
        realHome.appendingPathComponent("Library/Application Support/RightKit", isDirectory: true)
    }

    static var configURL: URL {
        supportDirectory.appendingPathComponent("config.json")
    }

    static func load() -> RKConfig {
        guard let data = try? Data(contentsOf: configURL),
              let cfg = try? JSONDecoder().decode(RKConfig.self, from: data)
        else { return RKConfig() }
        return cfg
    }

    static func defaultConfig() -> RKConfig {
        var cfg = RKConfig()
        let downloads = realHome.appendingPathComponent("Downloads")
        if FileManager.default.fileExists(atPath: downloads.path) {
            cfg.commonDirs = [RKDirectory(name: "下载", path: downloads.path)]
        }
        return cfg
    }

    @discardableResult
    static func ensureExists() -> RKConfig {
        if FileManager.default.fileExists(atPath: configURL.path) {
            return load()
        }
        let cfg = defaultConfig()
        cfg.save()
        return cfg
    }

    func save() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? enc.encode(self) else { return }
        try? data.write(to: Self.configURL, options: .atomic)
    }
}

import Cocoa
import FinderSync

enum RKActions {
    private static let cutType = NSPasteboard.PasteboardType("com.shining.rightkit.cut")
    private final class BundleToken {}

    static func copyToPasteboard(_ urls: [URL], cut: Bool) {
        guard !urls.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
        if cut {
            pb.setData(Data([1]), forType: cutType)
        }
    }

    static func pasteboardFileURLs() -> [URL] {
        let objects = NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [NSURL] ?? []
        return objects.map { $0 as URL }
    }

    static func pasteboardIsCut() -> Bool {
        NSPasteboard.general.data(forType: cutType) != nil
    }

    static func isExtensionHidden(_ url: URL) -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.extensionHidden] as? Bool) ?? false
    }

    @discardableResult
    static func setExtensionHidden(_ urls: [URL], hidden: Bool) -> (Int, [String]) {
        var done = 0
        var errors: [String] = []
        for url in urls {
            do {
                try FileManager.default.setAttributes([.extensionHidden: hidden], ofItemAtPath: url.path)
                done += 1
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (done, errors)
    }

    static func isLocked(_ url: URL) -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.immutable] as? Bool) ?? false
    }

    @discardableResult
    static func setLocked(_ urls: [URL], locked: Bool) -> (Int, [String]) {
        var done = 0
        var errors: [String] = []
        for url in urls {
            do {
                try FileManager.default.setAttributes([.immutable: locked], ofItemAtPath: url.path)
                done += 1
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (done, errors)
    }

    static func uniqueDirectory(in dir: URL, base: String) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent(base, isDirectory: true)
        var index = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base) \(index)", isDirectory: true)
            index += 1
        }
        return candidate
    }

    @discardableResult
    static func createFolder(namedAfter url: URL) -> Result<URL, Error> {
        let parent = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let target = uniqueDirectory(in: parent, base: base.isEmpty ? "新建文件夹" : base)
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            return .success(target)
        } catch {
            return .failure(error)
        }
    }

    @discardableResult
    static func createAlias(for url: URL, in dir: URL) -> Result<URL, Error> {
        let fm = FileManager.default
        let base = "\(url.lastPathComponent) 快捷方式"
        var target = dir.appendingPathComponent(base)
        var index = 2
        while fm.fileExists(atPath: target.path) {
            target = dir.appendingPathComponent("\(base) \(index)")
            index += 1
        }
        do {
            let data = try url.bookmarkData(options: [.suitableForBookmarkFile],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            try URL.writeBookmarkData(data, to: target)
            return .success(target)
        } catch {
            return .failure(error)
        }
    }

    @discardableResult
    static func writeHostRequest(_ name: String, paths: [String]) -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(at: RKConfig.supportDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(paths) else { return false }
        let url = RKConfig.supportDirectory.appendingPathComponent("\(name).json")
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    static func templateData(_ ext: String) -> Data? {
        var candidates: [URL] = []
        for bundle in [Bundle.main, Bundle(for: BundleToken.self)] {
            if let resources = bundle.resourceURL {
                candidates.append(resources.appendingPathComponent("Templates/\(ext)"))
            }
            candidates.append(bundle.bundleURL.appendingPathComponent("Contents/Resources/Templates/\(ext)"))
        }
        for url in candidates {
            if let data = try? Data(contentsOf: url) { return data }
        }
        return nil
    }

    static func copyStrings(_ values: [String]) {
        guard !values.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(values.joined(separator: "\n"), forType: .string)
    }

    static func isHidden(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isHiddenKey]))?.isHidden ?? false
    }

    @discardableResult
    static func setHidden(_ urls: [URL], hidden: Bool) -> (Int, [String]) {
        var done = 0
        var errors: [String] = []
        for url in urls {
            do {
                var target = url
                var values = URLResourceValues()
                values.isHidden = hidden
                try target.setResourceValues(values)
                done += 1
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (done, errors)
    }

    static func uniqueFile(in dir: URL, base: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent("\(base).\(ext)")
        var index = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base) \(index).\(ext)")
            index += 1
        }
        return candidate
    }

    static func uniqueDestination(for url: URL, in dir: URL) -> URL {
        let fm = FileManager.default
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var candidate = dir.appendingPathComponent(url.lastPathComponent)
        var index = 2
        while fm.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(name) \(index)" : "\(name) \(index).\(ext)"
            candidate = dir.appendingPathComponent(numbered)
            index += 1
        }
        return candidate
    }

    @discardableResult
    static func createFile(in dir: URL, ext: String) -> Result<URL, Error> {
        let fm = FileManager.default
        let target = uniqueFile(in: dir, base: "未命名", ext: ext)
        let content: Data
        switch ext {
        case "rtf":
            content = Data("{\\rtf1\\ansi\\ansicpg936\\cocoartf2706\n{\\fonttbl\\f0\\fnil\\fcharset0 .AppleSystemUIFont;}\n\\f0\\fs24 \\cf0 }\n".utf8)
        case "docx", "doc", "xlsx", "pptx":
            guard let template = templateData(ext) else {
                return .failure(NSError(domain: "RightKit", code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: "缺少 \(ext) 模板资源"]))
            }
            content = template
        default:
            content = Data()
        }
        let ok = fm.createFile(atPath: target.path, contents: content)
        if !ok {
            return .failure(NSError(domain: "RightKit", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "createFile 返回 false"]))
        }
        return .success(target)
    }

    @discardableResult
    static func send(_ urls: [URL], to: dir: URL, move: Bool) -> (Int, [String]) {
        let fm = FileManager.default
        var done = 0
        var errors: [String] = []
        for url in urls {
            let destination = uniqueDestination(for: url, in: dir)
            do {
                if move {
                    try fm.moveItem(at: url, to: destination)
                } else {
                    try fm.copyItem(at: url, to: destination)
                }
                done += 1
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (done, errors)
    }

    static func writeTerminalRequest(dir: URL, bundleID: String) -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(at: RKConfig.supportDirectory, withIntermediateDirectories: true)
        let request = RKTerminalRequest(dir: dir.path, bundleID: bundleID)
        guard let data = try? JSONEncoder().encode(request) else { return false }
        let url = RKConfig.supportDirectory.appendingPathComponent("terminal.json")
        return (try? data.write(to: url, options: .atomic)) != nil
    }

}

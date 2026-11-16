import Cocoa
import FinderSync

func rklog(_ message: String) {
    let url = RKConfig.supportDirectory.appendingPathComponent("ext.log")
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: url)
    }
}

func rkImage(_ name: String) -> NSImage? {
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    image?.size = NSSize(width: 16, height: 16)
    return image
}

class FinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        rklog("init")
    }

    private var selectedURLs: [URL] {
        FIFinderSyncController.default().selectedItemURLs() ?? []
    }

    private var actionKeys: [String: String] = [:]

    private var currentDirectory: URL? {
        let fm = FileManager.default
        if let target = FIFinderSyncController.default().targetedURL() {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: target.path, isDirectory: &isDir), isDir.boolValue {
                return target
            }
            return target.deletingLastPathComponent()
        }
        return selectedURLs.first?.deletingLastPathComponent()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let cfg = RKConfig.load()
        let selected = selectedURLs
        let directory = currentDirectory
        let menu = NSMenu(title: "")

        func add(_ title: String, _ key: String, icon: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(menuAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key
            item.image = rkImage(icon)
            actionKeys[title] = key
            menu.addItem(item)
            return item
        }

        if cfg.enabled.copyPath, !selected.isEmpty || directory != nil {
            _ = add("拷贝路径", "copyPath", icon: "point.topleft.down.to.point.bottomright.curvepath")
        }
        if cfg.enabled.copyName, !selected.isEmpty {
            _ = add("拷贝文件（夹）名称", "copyName", icon: "character.cursor.ibeam")
        }
        if cfg.enabled.copy, !selected.isEmpty {
            _ = add("拷贝", "copyFile", icon: "doc.on.doc")
        }
        if cfg.enabled.cut, !selected.isEmpty {
            _ = add("剪切", "cutFile", icon: "scissors")
        }
        if cfg.enabled.paste, directory != nil {
            _ = add("粘贴", "pasteFile", icon: "doc.on.clipboard")
        }

        if cfg.enabled.newFile, !cfg.templates.isEmpty, directory != nil {
            let item = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
            item.image = rkImage("doc.badge.plus")
            let submenu = NSMenu(title: "新建文件")
            for ext in cfg.templates {
                let sub = NSMenuItem(title: titleForTemplate(ext), action: #selector(menuAction(_:)), keyEquivalent: "")
                sub.target = self
                sub.representedObject = "new:\(ext)"
                sub.image = rkImage(iconForTemplate(ext))
                actionKeys[sub.title] = "new:\(ext)"
                submenu.addItem(sub)
            }
            item.submenu = submenu
            menu.addItem(item)
        }

        if cfg.enabled.sendTo, !cfg.commonDirs.isEmpty, !selected.isEmpty {
            let item = NSMenuItem(title: "发送到", action: nil, keyEquivalent: "")
            item.image = rkImage("paperplane")
            let submenu = NSMenu(title: "发送到")
            for dir in cfg.commonDirs {
                let title = "\(cfg.sendMode.title)到 \(dir.name)"
                let sub = NSMenuItem(title: title, action: #selector(menuAction(_:)), keyEquivalent: "")
                sub.target = self
                sub.representedObject = "send:\(dir.id.uuidString)"
                sub.image = rkImage(cfg.sendMode == .move ? "arrow.right.square" : "folder")
                actionKeys[sub.title] = "send:\(dir.id.uuidString)"
                submenu.addItem(sub)
            }
            item.submenu = submenu
            menu.addItem(item)
        }

        if cfg.enabled.hide, !selected.isEmpty {
            let allHidden = selected.allSatisfy { RKActions.isHidden($0) }
            _ = add(allHidden ? "取消隐藏已选文件" : "隐藏已选文件", "toggleHide",
                    icon: allHidden ? "eye" : "eye.slash")
        }
        if cfg.enabled.extensionHidden, !selected.isEmpty {
            let allHidden = selected.allSatisfy { RKActions.isExtensionHidden($0) }
            _ = add(allHidden ? "显示文件扩展名" : "隐藏文件扩展名", "toggleExtensionHidden",
                    icon: allHidden ? "tag" : "tag.slash")
        }
        if cfg.enabled.lock, !selected.isEmpty {
            let allLocked = selected.allSatisfy { RKActions.isLocked($0) }
            _ = add(allLocked ? "解锁已选文件" : "锁定已选文件", "toggleLock",
                    icon: allLocked ? "lock.open" : "lock")
        }
        if cfg.enabled.folderFromName, !selected.isEmpty {
            _ = add("按文件名建文件夹", "folderFromName", icon: "folder.badge.plus")
        }
        if cfg.enabled.info, !selected.isEmpty {
            _ = add("文件信息…", "fileInfo", icon: "info.circle")
        }
        if cfg.enabled.alias, !selected.isEmpty {
            _ = add("发送快捷方式到桌面", "aliasToDesktop", icon: "arrow.up.forward.square")
        }
        if cfg.enabled.airdrop, !selected.isEmpty {
            _ = add("AirDrop", "airdrop", icon: "antenna.radiowaves.left.and.right")
        }

        if cfg.enabled.terminal, directory != nil {
            let installed = RKTerminals.installed()
            if installed.count <= 1 {
                _ = add("在终端中打开", "terminal", icon: "terminal")
            } else {
                let preferred = RKTerminals.preferred(cfg.defaultTerminal)
                var ordered = installed
                if let preferred, let index = ordered.firstIndex(of: preferred) {
                    ordered.remove(at: index)
                    ordered.insert(preferred, at: 0)
                }
                let item = NSMenuItem(title: "在终端中打开", action: nil, keyEquivalent: "")
                item.image = rkImage("terminal")
                let submenu = NSMenu(title: "在终端中打开")
                for terminal in ordered {
                    let isPreferred = terminal == preferred
                    let sub = NSMenuItem(title: terminal.name, action: #selector(menuAction(_:)), keyEquivalent: "")
                    sub.target = self
                    sub.representedObject = "term:\(terminal.bundleID)"
                    sub.image = rkImage(isPreferred ? "checkmark.circle" : "terminal")
                    actionKeys[sub.title] = "term:\(terminal.bundleID)"
                    submenu.addItem(sub)
                }
                item.submenu = submenu
                menu.addItem(item)
            }
        }
        if cfg.enabled.trash, !selected.isEmpty {
            _ = add("删除到废纸篓", "trash", icon: "trash")
        }

        _ = add("右键复活设置…", "settings", icon: "gearshape")

        rklog("menu kind=\(menuKind.rawValue) selected=\(selected.count) dir=\(directory?.path ?? "-") items=\(menu.items.count)")
        return menu
    }

    private func titleForTemplate(_ ext: String) -> String {
        RKTemplate.title(ext)
    }

    private func iconForTemplate(_ ext: String) -> String {
        RKTemplate.icon(ext)
    }

    private func openTerminal(_ dir: URL, bundleID: String) {
        let installed = RKTerminals.installed()
        let terminal = (bundleID.isEmpty ? nil : installed.first { $0.bundleID == bundleID })
            ?? installed.first
        guard let terminal else {
            rklog("terminal: none installed")
            return
        }
        if RKActions.writeTerminalRequest(dir: dir, bundleID: terminal.bundleID),
           NSWorkspace.shared.open(URL(string: "rightkit://terminal")!) {
            rklog("terminal \(terminal.name) dir=\(dir.path)")
        } else {
            rklog("terminal: request failed \(terminal.name)")
        }
    }

    @objc func menuAction(_ sender: NSMenuItem) {
        let key = (sender.representedObject as? String) ?? actionKeys[sender.title]
        guard let key else {
            rklog("action: unknown item title=\(sender.title)")
            return
        }
        let cfg = RKConfig.load()
        let selected = selectedURLs

        if key == "copyPath" {
            let values = selected.isEmpty ? [currentDirectory?.path].compactMap { $0 } : selected.map { $0.path }
            RKActions.copyStrings(values)
            rklog("copyPath count=\(values.count)")
        } else if key == "copyName" {
            RKActions.copyStrings(selected.map { $0.lastPathComponent })
            rklog("copyName count=\(selected.count)")
        } else if key == "copyFile" {
            RKActions.copyToPasteboard(selected, cut: false)
            rklog("copy count=\(selected.count)")
        } else if key == "cutFile" {
            RKActions.copyToPasteboard(selected, cut: true)
            rklog("cut count=\(selected.count)")
        } else if key == "pasteFile" {
            guard let dir = currentDirectory else {
                rklog("paste: no directory")
                return
            }
            let urls = RKActions.pasteboardFileURLs()
            guard !urls.isEmpty else {
                rklog("paste: clipboard has no files")
                return
            }
            let move = RKActions.pasteboardIsCut()
            let result = RKActions.send(urls, to: dir, move: move)
            rklog("paste move=\(move) dir=\(dir.path) done=\(result.0) errors=\(result.1.joined(separator: "; "))")
        } else if key == "toggleHide" {
            let allHidden = selected.allSatisfy { RKActions.isHidden($0) }
            let result = RKActions.setHidden(selected, hidden: !allHidden)
            rklog("toggleHide hidden=\(!allHidden) done=\(result.0) errors=\(result.1.joined(separator: "; "))")
        } else if key == "toggleExtensionHidden" {
            let allHidden = selected.allSatisfy { RKActions.isExtensionHidden($0) }
            let result = RKActions.setExtensionHidden(selected, hidden: !allHidden)
            rklog("toggleExt hidden=\(!allHidden) done=\(result.0) errors=\(result.1.joined(separator: "; "))")
        } else if key == "toggleLock" {
            let allLocked = selected.allSatisfy { RKActions.isLocked($0) }
            let result = RKActions.setLocked(selected, locked: !allLocked)
            rklog("toggleLock locked=\(!allLocked) done=\(result.0) errors=\(result.1.joined(separator: "; "))")
        } else if key == "folderFromName" {
            var done = 0
            var errors: [String] = []
            for url in selected {
                switch RKActions.createFolder(namedAfter: url) {
                case .success(let dirURL): done += 1; rklog("folder: \(dirURL.path)")
                case .failure(let error): errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            rklog("folderFromName done=\(done) errors=\(errors.joined(separator: "; "))")
        } else if key == "fileInfo" {
            let paths = selected.map { $0.path }
            if RKActions.writeHostRequest("info", paths: paths) {
                _ = NSWorkspace.shared.open(URL(string: "rightkit://info")!)
            } else {
                rklog("fileInfo: request write failed")
            }
        } else if key == "aliasToDesktop" {
            let desktop = RKConfig.realHome.appendingPathComponent("Desktop", isDirectory: true)
            var done = 0
            var errors: [String] = []
            for url in selected {
                switch RKActions.createAlias(for: url, in: desktop) {
                case .success(let aliasURL): done += 1; rklog("alias: \(aliasURL.path)")
                case .failure(let error): errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            rklog("aliasToDesktop done=\(done) errors=\(errors.joined(separator: "; "))")
        } else if key == "airdrop" {
            let paths = selected.map { $0.path }
            if RKActions.writeHostRequest("airdrop", paths: paths) {
                let ok = NSWorkspace.shared.open(URL(string: "rightkit://airdrop")!)
                rklog("airdrop requested open=\(ok)")
            } else {
                rklog("airdrop: request write failed")
            }
        } else if key.hasPrefix("new:") {
            let ext = String(key.dropFirst(4))
            guard let dir = currentDirectory else {
                rklog("new file: no directory")
                return
            }
            switch RKActions.createFile(in: dir, ext: ext) {
            case .success(let url):
                rklog("new file: \(url.path)")
                if cfg.openAfterCreate {
                    NSWorkspace.shared.open(url)
                }
            case .failure(let error): rklog("new file failed: \(error.localizedDescription)")
            }
        } else if key.hasPrefix("send:") {
            let id = String(key.dropFirst(5))
            guard let dir = cfg.commonDirs.first(where: { $0.id.uuidString == id }) else {
                rklog("send: target not found")
                return
            }
            let result = RKActions.send(selected, to: URL(fileURLWithPath: dir.path), move: cfg.sendMode == .move)
            rklog("send \(cfg.sendMode.rawValue) dir=\(dir.path) done=\(result.0) errors=\(result.1.joined(separator: "; "))")
        } else if key == "terminal" || key.hasPrefix("term:") {
            guard let dir = currentDirectory else { return }
            let requested = key.hasPrefix("term:") ? String(key.dropFirst(5)) : cfg.defaultTerminal
            openTerminal(dir, bundleID: requested)
        } else if key == "trash" {
            RKActions.trash(selected)
            rklog("trash requested count=\(selected.count)")
        } else if key == "settings" {
            let ok = NSWorkspace.shared.open(URL(string: "rightkit://settings")!)
            rklog("settings open=\(ok)")
        }
    }
}

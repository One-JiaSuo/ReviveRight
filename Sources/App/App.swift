import AppKit
import Combine
import SwiftUI
import FinderSync

final class ConfigStore: ObservableObject {
    @Published var config: RKConfig

    init() {
        config = RKConfig.ensureExists()
    }

    func update<T>(_ keyPath: WritableKeyPath<RKConfig, T>, _ value: T) {
        var copy = config
        copy[keyPath: keyPath] = value
        config = copy
        copy.save()
    }

    func binding<T>(_ keyPath: WritableKeyPath<RKConfig, T>) -> Binding<T> {
        Binding(get: { self.config[keyPath: keyPath] },
                set: { self.update(keyPath, $0) })
    }

    func templateBinding(_ ext: String) -> Binding<Bool> {
        Binding(
            get: { self.config.templates.contains(ext) },
            set: { enabled in
                var copy = self.config
                copy.templates.removeAll { $0 == ext }
                if enabled { copy.templates.append(ext) }
                copy.templates = RKTemplate.normalized(copy.templates)
                self.config = copy
                copy.save()
            })
    }
}

struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    var onShowOnboarding: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                group("菜单项") {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("拷贝路径", isOn: store.binding(\.enabled.copyPath))
                            Toggle("拷贝文件（夹）名称", isOn: store.binding(\.enabled.copyName))
                            Toggle("拷贝", isOn: store.binding(\.enabled.copy))
                            Toggle("剪切", isOn: store.binding(\.enabled.cut))
                            Toggle("粘贴", isOn: store.binding(\.enabled.paste))
                            Toggle("隐藏 / 取消隐藏", isOn: store.binding(\.enabled.hide))
                            Toggle("显示 / 隐藏文件扩展名", isOn: store.binding(\.enabled.extensionHidden))
                            Toggle("锁定 / 解锁", isOn: store.binding(\.enabled.lock))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("文件信息", isOn: store.binding(\.enabled.info))
                            Toggle("发送快捷方式到桌面", isOn: store.binding(\.enabled.alias))
                            Toggle("AirDrop", isOn: store.binding(\.enabled.airdrop))
                            Toggle("按文件名建文件夹", isOn: store.binding(\.enabled.folderFromName))
                            Toggle("新建文件", isOn: store.binding(\.enabled.newFile))
                            Toggle("发送到常用目录", isOn: store.binding(\.enabled.sendTo))
                            Toggle("在终端中打开", isOn: store.binding(\.enabled.terminal))
                            Toggle("删除到废纸篓", isOn: store.binding(\.enabled.trash))
                        }
                        Spacer(minLength: 0)
                    }
                }

                group("新建文件模板") {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(RKTemplate.all.prefix(4), id: \.self) { ext in
                                Toggle(RKTemplate.title(ext), isOn: store.templateBinding(ext))
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(RKTemplate.all.dropFirst(4), id: \.self) { ext in
                                Toggle(RKTemplate.title(ext), isOn: store.templateBinding(ext))
                            }
                            Toggle("新建后自动打开", isOn: store.binding(\.openAfterCreate))
                        }
                        Spacer(minLength: 0)
                    }
                }

                group("发送到") {
                    Picker("方式", selection: store.binding(\.sendMode)) {
                        ForEach(SendMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)

                    ForEach(store.config.commonDirs) { dir in
                        HStack {
                            Text(dir.name)
                            Text(dir.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                var copy = store.config
                                copy.commonDirs.removeAll { $0.id == dir.id }
                                store.config = copy
                                copy.save()
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        addDirectory()
                    } label: {
                        Label("添加文件夹…", systemImage: "folder.badge.plus")
                    }
                }

                group("终端") {
                    HStack {
                        Text("默认终端")
                        Picker("", selection: store.binding(\.defaultTerminal)) {
                            Text("自动").tag("")
                            ForEach(RKTerminals.installed()) { terminal in
                                Text(terminal.name).tag(terminal.bundleID)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                    Text("右键菜单「在终端中打开」列出全部已安装终端，默认项带 ✓ 且排在最前。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                group("维护") {
                    HStack {
                        Button("打开设置…") { onOpenSettings() }
                        Spacer()
                        Button("开始使用") { onFinish() }
                            .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560, height: 500, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            extensionEnabled = FIFinderSyncController.isExtensionEnabled
        }
    }

    private func stepHeader(_ index: Int, _ title: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.16))
                    .frame(width: 24, height: 24)
                Text("\(index)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }
            Text(title).font(.headline)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let onboardingKey = "hasSeenOnboarding"
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var onboardingWindow: NSWindow?
    private var infoWindow: NSWindow?
    private let store = ConfigStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "contextualmenu.and.cursorarrow",
                            accessibilityDescription: "右键复活")
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        item.button?.image = image
        let menu = NSMenu()
        func addMenu(_ title: String, _ action: Selector, _ icon: String, key: String = "") -> NSMenuItem {
            let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
            entry.target = self
            entry.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
            entry.image?.size = NSSize(width: 16, height: 16)
            return entry
        }
        _ = addMenu("打开设置…", #selector(openSettings), "gearshape", key: ",")
        _ = addMenu("新手指引", #selector(showOnboarding), "lightbulb")
        _ = addMenu("管理 Finder 扩展…", #selector(manageExtension), "puzzlepiece.extension")
        _ = addMenu("打开扩展日志", #selector(openLog), "doc.text")
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "退出 ReviveRight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        item.menu = menu
        statusItem = item

        if CommandLine.arguments.contains("--settings") {
            DispatchQueue.main.async { self.openSettings() }
        } else if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            DispatchQueue.main.async { self.presentOnboarding() }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "rightkit" {
            switch url.host {
            case "info": openInfo()
            case "airdrop": performAirDrop()
            case "terminal": performTerminalOpen()
            case "trash": performTrash()
            default: openSettings()
            }
            return
        }
    }

    private func readHostRequest(_ name: String) -> [URL] {
        let url = RKConfig.supportDirectory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: url),
              let paths = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return paths.map { URL(fileURLWithPath: $0) }
    }

    private func openInfo() {
        let items = readHostRequest("info").map(FileInfoItem.init)
        guard !items.isEmpty else { return }
        if let win = infoWindow {
            win.contentViewController = NSHostingController(rootView: FileInfoView(items: items))
            win.title = items.count == 1 ? "\(items[0].name) — 文件信息" : "文件信息"
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: FileInfoView(items: items))
        let win = NSWindow(contentViewController: hosting)
        win.title = items.count == 1 ? "\(items[0].name) — 文件信息" : "文件信息"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.isReleasedWhenClosed = false
        win.center()
        infoWindow = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    private func performAirDrop() {
        let urls = readHostRequest("airdrop").filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { return }
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return }
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
    }

    private func performTrash() {
        let urls = readHostRequest("trash").filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
        guard !urls.isEmpty else {
            NSLog("trash: nothing to remove")
            return
        }
        NSWorkspace.shared.recycle(urls) { _, error in
            if let error {
                NSLog("trash failed: \(error.localizedDescription)")
            } else {
                NSLog("trashed \(urls.count) item(s)")
            }
        }
    }

    private func performTerminalOpen() {
        let requestURL = RKConfig.supportDirectory.appendingPathComponent("terminal.json")
        guard let data = try? Data(contentsOf: requestURL),
              let request = try? JSONDecoder().decode(RKTerminalRequest.self, from: data),
              let terminal = RKTerminals.terminal(bundleID: request.bundleID),
              let app = RKTerminals.appURL(terminal)
        else { return }
        let dir = URL(fileURLWithPath: request.dir)
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        switch terminal.launch {
        case .directory:
            NSWorkspace.shared.open([dir], withApplicationAt: app,
                                    configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error {
                    NSLog("terminal open failed: \(error.localizedDescription)")
                }
            }
        case .command(let relative, let arguments):
            let process = Process()
            process.executableURL = app.appendingPathComponent(relative)
            process.arguments = arguments.map { $0.replacingOccurrences(of: "$DIR", with: dir.path) }
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                NSLog("terminal spawn failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func showOnboarding() {
        presentOnboarding()
    }

    private func presentOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingView(
                onFinish: { [weak self] in
                    UserDefaults.standard.set(true, forKey: Self.onboardingKey)
                    self?.onboardingWindow?.close()
                },
                onOpenSettings: { [weak self] in self?.openSettings() })
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "欢迎使用右键复活"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.center()
            onboardingWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettings() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(
                store: store,
                onShowOnboarding: { [weak self] in self?.presentOnboarding() }))
            let win = NSWindow(contentViewController: hosting)
            win.title = "右键复活设置"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func manageExtension() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    @objc private func openLog() {
        let log = RKConfig.supportDirectory.appendingPathComponent("ext.log")
        if FileManager.default.fileExists(atPath: log.path) {
            NSWorkspace.shared.open(log)
        }
    }
}

@main
enum ReviveRightMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

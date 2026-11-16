# ReviveRight（右键复活）

<img src="Resources/AppIcon.iconset/icon_128x128@2x.png" width="96" align="right" alt="ReviveRight">

把 macOS 上那些“消失的右键”找回来：新建文件、复制路径、在终端打开、显示扩展名、文件信息……
全部长回 Finder 原生的右键菜单里，不替换 Finder、不注入进程、不常驻一大堆内存。

![image-20261116132241016](https://shining320.oss-cn-beijing.aliyuncs.com/img/image-20261116132241016.png)

## 为什么叫“右键复活”

macOS 的右键菜单（官方叫上下文菜单）这些年越做越克制。苹果只留了它认为你需要的几项——
拷贝、重命名、压缩、共享、快速操作——而很多人从 Windows 过来，或者习惯过 Windows
资源管理器那种“什么都能右键一下”的手感，就会觉得 Mac 的右键少了点什么：

- **新建文件**：Finder 里没有“新建文本文档”，想建个文件得先开编辑器另存为；
- **复制路径**：终端和脚本里最常用的绝对路径，右键里找不到；
- **在终端中打开**：想在当前目录开终端，只能拖拽或者敲 `cd`；
- **显示/隐藏扩展名、隐藏文件、锁定文件**：都藏在“显示简介”或终端命令里；
- **文件信息面板**：要精确看大小、权限、所有者，得层层点开；
- **建快捷方式、AirDrop**：有的入口深，有的干脆没有。

原生：

![image-20261116133735933](https://shining320.oss-cn-beijing.aliyuncs.com/img/image-20261116133735933.png)

这些不是系统坏了，是 macOS 本来就不给你。装第三方右键工具可以补上，但要么收费订阅，
要么功能堆成一座山，要么在主程序之外再挂一堆后台进程。

**ReviveRight 就是干一件事：用系统官方的 FinderSync 扩展机制，把这些能力补回原生菜单。**
它不修改 Finder、不做注入，菜单和系统原生菜单一样点开、一样跟手；配置改完下一次右键
立即生效，不用重启 Finder。

## 功能一览

Finder 右键菜单（选中文件/文件夹或空白处）：

| 菜单项 | 说明 |
| --- | --- |
| 拷贝路径 | 选中项逐行写入剪贴板；空白处复制当前目录 |
| 拷贝文件（夹）名称 | 仅文件名/文件夹名，逐行 |
| 拷贝 / 剪切 / 粘贴 | 与 Finder 剪贴板互通；剪切后粘贴执行移动，同名自动加序号 |
| 隐藏 / 取消隐藏已选文件 | 按当前选中项状态动态切换 |
| 显示 / 隐藏文件扩展名 | 按选中项扩展名状态动态切换 |
| 锁定 / 解锁已选文件 | 切换文件的不可更改（immutable）标志 |
| 按文件名建文件夹 | 以文件主名在同目录建文件夹，重名自动加序号 |
| 文件信息… | 名称、路径、种类、大小、时间、权限、所有者、锁定与隐藏状态 |
| 发送快捷方式到桌面 | 在桌面生成 Finder 别名文件 |
| AirDrop | 通过系统共享服务发送选中项 |
| 新建文件 ▸ | txt / md / rtf / docx / doc / xlsx / csv / pptx，自动去重命名 |
| 发送到 ▸ | 复制或移动到常用目录（同名自动加序号） |
| 在终端中打开 ▸ | 打开当前目录：子菜单列出已安装的终端，默认项带 ✓ 并置顶；只装一个终端时为普通菜单项 |
| 删除到废纸篓 | 移入废纸篓 |
| 右键复活设置… | 打开设置窗口（菜单栏图标被系统隐藏时的备用入口，`rightkit://settings`） |

设置窗口（菜单栏图标 → 打开设置…，或 Finder 右键菜单 → 右键复活设置…）：

- 首次启动显示新手指引（菜单栏「新手指引」可再次打开）
- 16 个菜单项开关，逐项启用/禁用（双列排布）
- 新建文件模板勾选（txt / md / rtf / docx / doc / xlsx / csv / pptx）与「新建后自动打开」
- 默认终端选择（自动 / Terminal / iTerm / Warp / Ghostty / kitty / Alacritty / WezTerm，按已安装项列出）
- 常用目录增删、「复制 / 移动」模式切换
- 维护：管理 Finder 扩展、打开配置文件夹、打开扩展日志、扩展状态显示

> 带刘海的 Mac 上，右侧菜单栏容量有限。若其他状态项过多，新图标会被系统放进
> 刘海后的隐藏区（不显示）。右键菜单里的「右键复活设置…」始终可用；想显示菜单栏图标时，
> 隐藏任意一个其他状态项（如 Stats 的某个模块）即可，或重启控制中心（`killall ControlCenter`）。

配置即时生效：扩展每次构建菜单都会重新读取配置，无需重启 Finder。

## 下载与安装

从 [Releases](../../releases) 下载 `ReviveRight-x.y.z.zip`：

1. 解压，把 `ReviveRight.app` 拖进「应用程序」。
2. 首次打开会被 Gatekeeper 拦截（未公证）。右键 →「打开」，或执行
   `xattr -dr com.apple.quarantine /Applications/ReviveRight.app`。
   若提示 App 已损坏，也是用这条命令修复。
3. 启动后按新手指引启用 Finder 扩展（或系统设置 → 通用 → 登录项与扩展 → 访达扩展）。
4. 首次对桌面/文稿/下载中的文件操作时，按提示授予一次访问权限。

要求 macOS 14+；安装包为 Universal 二进制，Apple Silicon 与 Intel 均可运行。

## 系统要求

- macOS 14+（已在 macOS 26 / Apple Silicon 验证）
- 自行编译需要 Command Line Tools（`xcode-select --install`），无需 Xcode

## 构建与安装

```bash
cd rightkit
make sign          # 编译（arm64 + x86_64 通用）并组装、签名
make install       # 复制到 ~/Applications
make register      # 向系统注册扩展并启用，重启 Finder
open ~/Applications/ReviveRight.app
```

或一键：

```bash
./scripts/install.sh
```

只在本机快速迭代时可以用 `make ARCHS=arm64 sign`，编译更快。

打发布包（版本号取自 `Resources/App-Info.plist`）：

```bash
make dist          # 生成 build/ReviveRight-<版本>.zip
```

推 `v*` 标签后 GitHub Actions 会自动构建并在 Releases 附上 zip。

验证：

```bash
make verify        # pluginkit 注册状态 + 扩展宿主进程
```

## 扩展启用

首次安装后如右键菜单未出现：

1. 系统设置 → 通用 → 登录项与扩展 → 文件提供程序（或「访达扩展」）
2. 启用「右键复活扩展」
3. 必要时 `killall Finder`

应用内「管理 Finder 扩展…」可直接打开该面板。

## 配置

路径：`~/Library/Application Support/RightKit/config.json`（沿用旧目录名，改名不丢配置）

```json
{
  "enabled": {"copyPath": true, "copyName": true, "copy": true, "cut": true, "paste": true,
               "hide": true, "extensionHidden": true, "lock": true, "info": true,
               "alias": true, "airdrop": true, "folderFromName": true,
               "newFile": true, "sendTo": true, "terminal": true, "trash": true},
  "templates": ["txt", "md", "rtf", "docx", "doc", "xlsx", "csv", "pptx"],
  "openAfterCreate": true,
  "defaultTerminal": "",
  "sendMode": "copy",
  "commonDirs": [{"id": "UUID", "name": "下载", "path": "/Users/<user>/Downloads"}]
}
```

扩展日志：`~/Library/Application Support/RightKit/ext.log`（菜单构建与动作结果都记录在这里）。

## 工程结构

```
Makefile                    # swiftc 构建 / 组装 / 签名 / 安装 / 打包 / 注册
Sources/Shared/Config.swift # 配置模型与读写
Sources/App/App.swift       # 菜单栏宿主 + SwiftUI 设置窗口 + 新手指引
Sources/Ext/FinderSync.swift# Finder 右键菜单
Sources/Ext/Actions.swift   # 文件动作实现
Resources/                  # Info.plist / entitlements / AppIcon / 文档模板
scripts/gen_icon.swift      # 生成 App 图标（iconset → icns）
scripts/install.sh          # 一键安装
.github/workflows/build.yml # CI：构建 + 打包，打标签自动发 Release
```

## 实现说明与限制

- Finder 扩展必须在 App Sandbox 内运行（`pkd` 要求），本工具使用
  `com.apple.security.temporary-exception.files.absolute-path.read-write = ["/"]`
  以支持对任意目录的写操作。该 entitlement 仅适合自用，无法上架 App Store。
- ad-hoc 签名（`--sign -`）无团队 ID，不能使用 App Groups；宿主与扩展通过
  `~/Library/Application Support/RightKit/config.json` 共享配置。
- 沙盒内 `HOME` 会被重定向，配置路径通过 `getpwuid(getuid())` 还原真实家目录。
- FinderSync 菜单项跨进程回传时 `representedObject` 会丢失，动作分发以菜单标题兜底映射
  （`actionKeys`），修改菜单标题时需同步更新。
- 终端打开也交给宿主执行：扩展写 `terminal.json`（目录 + 终端 Bundle ID）后打开 `rightkit://terminal`。
  Terminal / iTerm / Warp 走 LaunchServices 直接以目录打开；Ghostty / kitty / Alacritty / WezTerm
  需按各自命令行参数（`--working-directory`、`--directory`、`start --cwd`）启动，沙盒扩展内无法派生这些进程。
- 文件信息窗口与 AirDrop 需要窗口/共享 UI，扩展进程内无法直接呈现：扩展先把路径写入
  `~/Library/Application Support/RightKit/info.json` / `airdrop.json`，再通过 `rightkit://info`
  或 `rightkit://airdrop` 交给宿主执行。
- 每次重新签名会改变 cdhash，TCC 对桌面/文稿/下载的授权可能重置，按提示重新允许即可。

## 卸载

```bash
pluginkit -r ~/Applications/ReviveRight.app/Contents/PlugIns/ReviveRightFinder.appex || true
rm -rf ~/Applications/ReviveRight.app
rm -rf ~/Library/Application\ Support/RightKit
killall Finder
```

## 许可证

作者：One-JiaSuo

GPL-3.0，全文见 [LICENSE](LICENSE)。Copyright (C) 2026 One-JiaSuo。

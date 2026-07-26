import AppKit
import Darwin
import Foundation
import WebKit

// MdReader — companion Markdown viewer for grok-md-reader.
// URL scheme: md-reader://open?path=<absolute-path>
// Phase 3: FS hot-reload + session history list (side-channel from plugin data dir).

enum MdReaderConstants {
    static let schemeHost = "md-reader"
    static let appName = "MdReader"
}

let _mdApp = NSApplication.shared
let _mdDelegate = AppDelegate()
_mdApp.delegate = _mdDelegate
_mdApp.setActivationPolicy(.regular)
_mdApp.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: ViewerController?
    private var pendingPaths: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vc = ViewerController()
        self.controller = vc
        vc.showWindow()

        let args = Array(CommandLine.arguments.dropFirst())
        var paths: [String] = []
        var seenDash = false
        for a in args {
            if a == "--" {
                seenDash = true
                continue
            }
            if a.hasPrefix("-"), !seenDash { continue }
            paths.append(a)
        }
        if let first = paths.first {
            vc.openPath(first)
        } else if !pendingPaths.isEmpty {
            for p in pendingPaths { vc.openPath(p) }
            pendingPaths.removeAll()
        } else {
            vc.showWelcome()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleIncomingURL(url)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if let c = controller {
            c.openPath(filename)
        } else {
            pendingPaths.append(filename)
        }
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func handleIncomingURL(_ url: URL) {
        if url.isFileURL {
            let path = url.path
            if let c = controller { c.openPath(path) } else { pendingPaths.append(path) }
            return
        }
        guard url.scheme?.lowercased() == MdReaderConstants.schemeHost else { return }
        var path: String?
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            path = comps.queryItems?.first(where: { $0.name == "path" })?.value
            if path == nil {
                let p = comps.path
                if !p.isEmpty, p != "/" { path = p }
            }
        }
        guard let path, !path.isEmpty else { return }
        if let c = controller {
            c.openPath(path)
        } else {
            pendingPaths.append(path)
        }
    }
}

final class ViewerController: NSObject, WKNavigationDelegate, NSMenuItemValidation {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var titleLabel: NSTextField!
    private var historyButton: NSPopUpButton!
    private var statusLabel: NSTextField!
    private var currentPath: String?
    private let resourceDir: URL

    // FS watch
    private var fileSource: DispatchSourceFileSystemObject?
    private var fileFD: CInt = -1
    private var reloadWorkItem: DispatchWorkItem?
    private var lastRenderedContentHash: Int = 0

    // history side-channel watch
    private var historySource: DispatchSourceFileSystemObject?
    private var historyFD: CInt = -1
    private var historyPaths: [String] = []

    override init() {
        if let res = Bundle.main.resourceURL {
            resourceDir = res
        } else {
            resourceDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
        super.init()
        buildUI()
        startHistoryWatch()
        reloadHistoryMenu()
    }

    deinit {
        stopFileWatch()
        stopHistoryWatch()
    }

    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showWelcome() {
        stopFileWatch()
        currentPath = nil
        lastRenderedContentHash = 0
        titleLabel.stringValue = "\(MdReaderConstants.appName) — /open path.md · history in toolbar"
        statusLabel.stringValue = "idle"
        let html = shellHTML(
            title: MdReaderConstants.appName,
            bodyHTML: """
            <div class="welcome">
              <h1>MdReader</h1>
              <p>Grok CLI 伴生 Markdown 渲染窗（热刷新 · 会话历史）。</p>
              <ul>
                <li><code>/open path.md</code> / <code>open_path.py</code></li>
                <li>URL：<code>md-reader://open?path=/absolute/file.md</code></li>
                <li>工具栏 History：本次会话 hook 侧信道记录的 md</li>
              </ul>
            </div>
            """,
            baseURL: resourceDir
        )
        webView.loadHTMLString(html, baseURL: resourceDir)
        reloadHistoryMenu()
    }

    func openPath(_ raw: String) {
        let expanded = (raw as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), !isDir.boolValue else {
            stopFileWatch()
            currentPath = expanded
            showError("文件不存在或不是普通文件（可能已删除/移动）：\n\(expanded)")
            statusLabel.stringValue = "missing"
            return
        }
        guard !expanded.hasPrefix("http://"), !expanded.hasPrefix("https://") else {
            showError("拒绝 URL，仅本地文件。")
            return
        }
        currentPath = expanded
        titleLabel.stringValue = expanded
        window.title = "\(MdReaderConstants.appName) — \(URL(fileURLWithPath: expanded).lastPathComponent)"
        renderFile(at: expanded, reason: "open")
        startFileWatch(path: expanded)
        reloadHistoryMenu()
        showWindow()
    }

    // MARK: - Render

    private func showError(_ message: String) {
        titleLabel.stringValue = currentPath ?? "错误"
        let escaped = htmlEscape(message)
        let html = shellHTML(
            title: "Error",
            bodyHTML: "<pre class=\"error\">\(escaped)</pre>",
            baseURL: resourceDir
        )
        webView.loadHTMLString(html, baseURL: resourceDir)
        showWindow()
    }

    private func renderFile(at path: String, reason: String) {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            showError("无法读取：\(error.localizedDescription)")
            statusLabel.stringValue = "read-error"
            return
        }
        if data.count > 10 * 1024 * 1024 {
            showError("文件过大（>\(data.count) bytes），拒绝加载。")
            return
        }
        let hash = data.hashValue
        if reason == "watch", hash == lastRenderedContentHash {
            return
        }
        lastRenderedContentHash = hash

        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            showError("无法将文件解码为文本。")
            return
        }

        let ext = (path as NSString).pathExtension.lowercased()
        let isMarkdown = ["md", "markdown", "mdc", "mdx"].contains(ext)

        let body: String
        if isMarkdown {
            let b64 = Data(text.utf8).base64EncodedString()
            body = """
            <article id="content" class="markdown-body"></article>
            <script>
            (function() {
              const b64 = "\(b64)";
              const bin = atob(b64);
              const bytes = new Uint8Array(bin.length);
              for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
              const src = new TextDecoder("utf-8").decode(bytes);
              const html = marked.parse(src, { gfm: true, breaks: false });
              const el = document.getElementById("content");
              el.innerHTML = html;
              document.querySelectorAll("pre code").forEach((block) => {
                try { hljs.highlightElement(block); } catch (e) {}
              });
              const base = \(jsString(URL(fileURLWithPath: path).deletingLastPathComponent().path + "/"));
              el.querySelectorAll("img[src]").forEach((img) => {
                const s = img.getAttribute("src") || "";
                if (s.startsWith("http://") || s.startsWith("https://") || s.startsWith("data:") || s.startsWith("file:")) return;
                img.setAttribute("src", "file://" + base + s);
              });
            })();
            </script>
            """
        } else {
            body = "<pre class=\"plain\">\(htmlEscape(text))</pre>"
        }

        let html = shellHTML(
            title: URL(fileURLWithPath: path).lastPathComponent,
            bodyHTML: body,
            baseURL: resourceDir
        )
        let base = URL(fileURLWithPath: path).deletingLastPathComponent()
        webView.loadHTMLString(html, baseURL: base)
        statusLabel.stringValue = reason == "watch" ? "hot-reload" : "loaded"
        titleLabel.stringValue = path
    }

    // MARK: - File watch (DispatchSource)

    private func stopFileWatch() {
        reloadWorkItem?.cancel()
        reloadWorkItem = nil
        fileSource?.cancel()
        fileSource = nil
        if fileFD >= 0 {
            close(fileFD)
            fileFD = -1
        }
    }

    private func startFileWatch(path: String) {
        stopFileWatch()
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            statusLabel.stringValue = "watch-failed"
            return
        }
        fileFD = fd
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename, .delete, .link, .revoke],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.onFileEvent()
        }
        src.setCancelHandler {
            // fd closed in stopFileWatch
        }
        src.resume()
        fileSource = src
        statusLabel.stringValue = "watching"
    }

    private func onFileEvent() {
        guard let path = currentPath else { return }
        // Debounce rapid writes (~250ms)
        reloadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.handleWatchedPathChange(path)
        }
        reloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func handleWatchedPathChange(_ path: String) {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if !exists || isDir.boolValue {
            // deleted / replaced / moved — keep window, show soft error, re-arm watch if recreated later
            stopFileWatch()
            showError("文件已删除或移动：\n\(path)\n\n窗口保留；重新 /open 或从 History 切换。")
            statusLabel.stringValue = "gone"
            // Poll briefly in case of atomic replace (write temp + rename)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, self.currentPath == path else { return }
                var d: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &d), !d.boolValue {
                    self.renderFile(at: path, reason: "watch")
                    self.startFileWatch(path: path)
                }
            }
            return
        }
        renderFile(at: path, reason: "watch")
        // Some editors replace via rename: re-open watch fd
        startFileWatch(path: path)
    }

    // MARK: - History (plugin data side-channel)

    private func resolveDataDirs() -> [URL] {
        var dirs: [URL] = []
        let env = ProcessInfo.processInfo.environment
        for key in ["GROK_PLUGIN_DATA", "CLAUDE_PLUGIN_DATA", "MD_READER_DATA"] {
            if let v = env[key], !v.isEmpty {
                dirs.append(URL(fileURLWithPath: (v as NSString).expandingTildeInPath))
            }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let pluginData = home.appendingPathComponent(".grok/plugin-data")
        if let kids = try? FileManager.default.contentsOfDirectory(
            at: pluginData,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for kid in kids {
                let cand = kid.appendingPathComponent("md-reader")
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: cand.path, isDirectory: &isDir), isDir.boolValue {
                    dirs.append(cand)
                }
            }
        }
        dirs.append(home.appendingPathComponent(".grok/plugin-data/user/md-reader"))
        dirs.append(home.appendingPathComponent(".config/grok-md-reader"))
        // dedupe
        var seen = Set<String>()
        return dirs.filter { d in
            let p = d.path
            if seen.contains(p) { return false }
            seen.insert(p)
            return true
        }
    }

    private func loadHistoryPaths() -> [String] {
        for dir in resolveDataDirs() {
            let current = dir.appendingPathComponent("history/current.json")
            if let data = try? Data(contentsOf: current),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let paths = obj["paths"] as? [String],
               !paths.isEmpty
            {
                return paths
            }
        }
        // fallback: last_path only
        for dir in resolveDataDirs() {
            let last = dir.appendingPathComponent("last_path")
            if let s = try? String(contentsOf: last, encoding: .utf8) {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return [t] }
            }
        }
        return []
    }

    private func reloadHistoryMenu() {
        historyPaths = loadHistoryPaths()
        historyButton.removeAllItems()
        historyButton.addItem(withTitle: "History (\(historyPaths.count))")
        historyButton.menu?.items.first?.isEnabled = false

        if historyPaths.isEmpty {
            let empty = NSMenuItem(title: "(no session md yet)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            historyButton.menu?.addItem(empty)
        } else {
            for (i, p) in historyPaths.enumerated().reversed() {
                let name = URL(fileURLWithPath: p).lastPathComponent
                let item = NSMenuItem(title: name, action: #selector(historyItemSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = p
                item.toolTip = p
                if p == currentPath {
                    item.state = .on
                }
                historyButton.menu?.addItem(item)
                _ = i
            }
        }
        let refresh = NSMenuItem(title: "Refresh list", action: #selector(refreshHistoryClicked(_:)), keyEquivalent: "r")
        refresh.target = self
        historyButton.menu?.addItem(NSMenuItem.separator())
        historyButton.menu?.addItem(refresh)
    }

    @objc private func historyItemSelected(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        openPath(path)
    }

    @objc private func refreshHistoryClicked(_ sender: Any?) {
        reloadHistoryMenu()
        statusLabel.stringValue = "history-refreshed"
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        true
    }

    private func stopHistoryWatch() {
        historySource?.cancel()
        historySource = nil
        if historyFD >= 0 {
            close(historyFD)
            historyFD = -1
        }
    }

    private func startHistoryWatch() {
        stopHistoryWatch()
        // Watch first existing history directory parent
        for dir in resolveDataDirs() {
            let hist = dir.appendingPathComponent("history")
            try? FileManager.default.createDirectory(at: hist, withIntermediateDirectories: true)
            let fd = open(hist.path, O_EVTONLY)
            if fd >= 0 {
                historyFD = fd
                let src = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .extend, .rename, .delete],
                    queue: .main
                )
                src.setEventHandler { [weak self] in
                    self?.reloadHistoryMenu()
                }
                src.resume()
                historySource = src
                return
            }
        }
    }

    // MARK: - UI

    private func buildUI() {
        let style = NSWindow.StyleMask.titled
            .union(.closable)
            .union(.miniaturizable)
            .union(.resizable)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 720),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = MdReaderConstants.appName
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MdReaderMain")

        let content = NSView(frame: window.contentView!.bounds)
        content.autoresizingMask = [.width, .height]

        historyButton = NSPopUpButton(frame: .zero, pullsDown: true)
        historyButton.translatesAutoresizingMaskIntoConstraints = false
        historyButton.controlSize = .small
        historyButton.font = NSFont.systemFont(ofSize: 11)

        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel = NSTextField(labelWithString: "idle")
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.alignment = .right
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(historyButton)
        content.addSubview(titleLabel)
        content.addSubview(statusLabel)
        content.addSubview(webView)
        NSLayoutConstraint.activate([
            historyButton.topAnchor.constraint(equalTo: content.topAnchor, constant: 4),
            historyButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            historyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            statusLabel.centerYAnchor.constraint(equalTo: historyButton.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            statusLabel.widthAnchor.constraint(equalToConstant: 110),

            titleLabel.centerYAnchor.constraint(equalTo: historyButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: historyButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -8),

            webView.topAnchor.constraint(equalTo: historyButton.bottomAnchor, constant: 4),
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == "about" || navigationAction.navigationType == .other {
            decisionHandler(.allow)
            return
        }
        if url.isFileURL {
            decisionHandler(.allow)
            return
        }
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    // MARK: - HTML shell

    private func shellHTML(title: String, bodyHTML: String, baseURL: URL) -> String {
        let marked = loadResource("marked.min.js")
        let hljs = loadResource("highlight.min.js")
        let mdCSS = loadResource("github-markdown.min.css")
        let hlCSS = loadResource("highlight-github-dark.min.css")
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width, initial-scale=1"/>
          <title>\(htmlEscape(title))</title>
          <style>
            \(mdCSS)
            \(hlCSS)
            :root { color-scheme: light dark; }
            html, body { margin: 0; padding: 0; background: #0d1117; color: #e6edf3; }
            @media (prefers-color-scheme: light) {
              html, body { background: #ffffff; color: #1f2328; }
            }
            body { padding: 16px 28px 48px; }
            .markdown-body { box-sizing: border-box; min-width: 200px; max-width: 920px; margin: 0 auto; }
            .markdown-body img { max-width: 100%; }
            pre.plain, pre.error {
              white-space: pre-wrap; word-break: break-word;
              font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
              font-size: 13px; line-height: 1.5;
              background: rgba(127,127,127,0.12); padding: 16px; border-radius: 8px;
            }
            pre.error { color: #ff7b72; }
            .welcome { max-width: 640px; margin: 48px auto; font-family: -apple-system, system-ui, sans-serif; }
            .welcome code { background: rgba(127,127,127,0.15); padding: 1px 6px; border-radius: 4px; }
          </style>
          <script>\(marked)</script>
          <script>\(hljs)</script>
        </head>
        <body>
          \(bodyHTML)
        </body>
        </html>
        """
    }

    private func loadResource(_ name: String) -> String {
        let url = resourceDir.appendingPathComponent(name)
        if let s = try? String(contentsOf: url, encoding: .utf8) {
            return s
        }
        let dev = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent(name)
        if let s = try? String(contentsOf: dev, encoding: .utf8) {
            return s
        }
        return "/* missing resource: \(name) */"
    }
}

private func htmlEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

private func jsString(_ s: String) -> String {
    let escaped = s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
    return "\"\(escaped)\""
}

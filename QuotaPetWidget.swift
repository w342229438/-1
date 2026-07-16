import AppKit

private enum DoodleMetrics {
    static let scale: CGFloat = 0.86
    static let logicalWidth: CGFloat = 280
    static let compactLogicalHeight: CGFloat = 126
    static let cardLogicalSize = NSSize(width: 360, height: 116)

    static func displaySize(logicalHeight: CGFloat) -> NSSize {
        NSSize(width: logicalWidth * scale, height: logicalHeight * scale)
    }

    static var compactDisplaySize: NSSize {
        displaySize(logicalHeight: compactLogicalHeight)
    }

    static var cardDisplaySize: NSSize {
        NSSize(width: cardLogicalSize.width * scale, height: cardLogicalSize.height * scale)
    }
}

@main
struct QuotaPetWidgetApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private var panel: FloatingPanel?
    private var statusItem: NSStatusItem?
    private var settingsController: SettingsWindowController?
    private var hoverPanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
#if GLASS_STYLE
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 108, height: 310),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = GlassIconWidgetView(
            store: store,
            detailChanged: { [weak self] detail, kind in
                self?.updateHoverPanel(detail: detail, kind: kind)
            }
        )
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel

        let hoverPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 92),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        hoverPanel.level = .floating
        hoverPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hoverPanel.hidesOnDeactivate = false
        hoverPanel.backgroundColor = .clear
        hoverPanel.isOpaque = false
        hoverPanel.hasShadow = false
        hoverPanel.ignoresMouseEvents = true
        hoverPanel.contentView = HoverDetailCard(frame: NSRect(x: 0, y: 0, width: 450, height: 92))
        self.hoverPanel = hoverPanel
#else
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: DoodleMetrics.compactDisplaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let widget = DoodleWidgetView(
            store: store,
            detailChanged: { [weak self] detail, kind in
                self?.updateHoverPanel(detail: detail, kind: kind)
            },
            contentHeightChanged: { [weak self] height in
                self?.resizeMainPanel(contentHeight: height)
            }
        )
        panel.contentView = widget
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel

        let hoverPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: DoodleMetrics.cardDisplaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        hoverPanel.level = .floating
        hoverPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hoverPanel.hidesOnDeactivate = false
        hoverPanel.backgroundColor = .clear
        hoverPanel.isOpaque = false
        hoverPanel.hasShadow = false
        hoverPanel.ignoresMouseEvents = true
        let card = DoodleQuotaCard(frame: NSRect(origin: .zero, size: DoodleMetrics.cardDisplaySize))
        hoverPanel.contentView = card
        self.hoverPanel = hoverPanel
#endif

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "chart.pie.fill", accessibilityDescription: "额度小组件")
        let menu = NSMenu()
        menu.addItem(menuItem(title: "显示额度小组件", action: #selector(showWidget)))
        menu.addItem(menuItem(title: "隐藏额度小组件", action: #selector(hideWidget)))
        menu.addItem(menuItem(title: "设置", action: #selector(showSettings)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWidget()
        return true
    }

    @objc private func showWidget() {
        panel?.orderFrontRegardless()
    }

    @objc private func hideWidget() {
        panel?.orderOut(nil)
        hoverPanel?.orderOut(nil)
    }

    @objc private func showSettings() {
        let controller = SettingsWindowController(store: store)
        settingsController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateHoverPanel(detail: HoverDetail?, kind: QuotaDetailKind?) {
        guard let detail, let panel, let hoverPanel else {
            hoverPanel?.orderOut(nil)
            return
        }
#if GLASS_STYLE
        guard let card = hoverPanel.contentView as? HoverDetailCard else {
            hoverPanel.orderOut(nil)
            return
        }
        card.configure(with: detail)
        let visibleFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let rowCenter: CGFloat
        switch kind {
        case .hourly: rowCenter = 64
        case .weekly: rowCenter = 155
        case .reset: rowCenter = 246
        case nil: rowCenter = 64
        }
        let x = min(panel.frame.maxX + 14, visibleFrame.maxX - 462)
        let y = min(max(panel.frame.maxY - rowCenter - 46, visibleFrame.minY + 12), visibleFrame.maxY - 104)
        hoverPanel.setFrame(NSRect(x: x, y: y, width: 450, height: 92), display: true)
#else
        guard (panel.contentView?.bounds.height ?? 0) <= 180 else {
            hoverPanel.orderOut(nil)
            return
        }
        guard let card = hoverPanel.contentView as? DoodleQuotaCard else {
            hoverPanel.orderOut(nil)
            return
        }
        card.configure(with: detail)
        let visibleFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let isExpanded = (panel.contentView?.bounds.height ?? 0) > 180
        let cardSize = DoodleMetrics.cardDisplaySize
        let x: CGFloat
        let y: CGFloat
        if isExpanded {
            let preferredRight = panel.frame.maxX + 12
            let preferredLeft = panel.frame.minX - cardSize.width - 12
            x = preferredRight <= visibleFrame.maxX - cardSize.width
                ? preferredRight
                : max(visibleFrame.minX + 12, preferredLeft)
            let iconCenterY = panel.frame.maxY - 86
            y = min(max(iconCenterY - cardSize.height / 2, visibleFrame.minY + 12), visibleFrame.maxY - cardSize.height - 12)
        } else {
            x = min(max(panel.frame.midX - cardSize.width / 2, visibleFrame.minX + 12), visibleFrame.maxX - cardSize.width - 12)
            let cardHeight = cardSize.height
            let aboveY = panel.frame.maxY + 14
            if aboveY + cardHeight <= visibleFrame.maxY - 12 {
                y = aboveY
            } else {
                y = max(visibleFrame.minY + 12, panel.frame.minY - cardHeight - 14)
            }
        }
        let frame = NSRect(origin: NSPoint(x: x, y: y), size: cardSize)
        hoverPanel.setFrame(frame, display: true)
#endif
        hoverPanel.orderFrontRegardless()
    }

    private func resizeMainPanel(contentHeight: CGFloat) {
        guard let panel else { return }
        let oldFrame = panel.frame
        let contentRect = NSRect(x: 0, y: 0, width: DoodleMetrics.compactDisplaySize.width, height: contentHeight)
        var newFrame = panel.frameRect(forContentRect: contentRect)
        newFrame.origin.x = oldFrame.origin.x
        newFrame.origin.y = oldFrame.maxY - newFrame.height
        panel.setFrame(newFrame, display: true, animate: true)
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent).then {
            $0.target = self
        }
    }
}

private extension NSMenuItem {
    func then(_ configure: (NSMenuItem) -> Void) -> NSMenuItem {
        configure(self)
        return self
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        appearance = NSAppearance(named: .aqua)
    }
}

final class UsageStore {
    var usedPercent: Int {
        didSet {
            usedPercent = min(max(usedPercent, 0), 100)
            UserDefaults.standard.set(usedPercent, forKey: "usedPercent")
            if !suppressesChangeNotification { onChange?() }
        }
    }

    var resetDate: Date {
        didSet {
            UserDefaults.standard.set(resetDate, forKey: "resetDate")
            if !suppressesChangeNotification { onChange?() }
        }
    }

    var secondaryUsedPercent: Int? {
        didSet {
            UserDefaults.standard.set(secondaryUsedPercent, forKey: "secondaryUsedPercent")
            if !suppressesChangeNotification { onChange?() }
        }
    }

    var secondaryResetDate: Date? {
        didSet {
            UserDefaults.standard.set(secondaryResetDate, forKey: "secondaryResetDate")
            if !suppressesChangeNotification { onChange?() }
        }
    }

    private(set) var automaticResetCredits: RateLimitResetCreditSnapshot? {
        didSet { onChange?() }
    }

    var manualResetCredits: Int {
        didSet {
            manualResetCredits = max(0, manualResetCredits)
            UserDefaults.standard.set(manualResetCredits, forKey: "manualResetCredits")
            onChange?()
        }
    }

    var manualResetExpirationDates: [Date] {
        didSet {
            UserDefaults.standard.set(manualResetExpirationDates, forKey: "manualResetExpirationDates")
            onChange?()
        }
    }

    var automaticallySyncs: Bool {
        didSet {
            UserDefaults.standard.set(automaticallySyncs, forKey: "automaticallySyncs")
            onChange?()
        }
    }

    var onChange: (() -> Void)?
    private let codexReader = CodexRateLimitReader()
    private let resetCreditReader = CodexRateLimitResetReader()
    private var isSyncingSessions = false
    private var queuedForcedSessionSync = false
    private var isSyncingResetCredits = false
    private var queuedForcedResetCreditSync = false
    private var lastResetCreditSyncAttempt = Date.distantPast
    private var lastAppliedCodexSnapshotDate: Date
    private var suppressesChangeNotification = false

    init() {
        let defaults = UserDefaults.standard
        usedPercent = defaults.object(forKey: "usedPercent") as? Int ?? 0
        resetDate = defaults.object(forKey: "resetDate") as? Date ?? Calendar.current.date(byAdding: .hour, value: 5, to: Date())!
        secondaryUsedPercent = defaults.object(forKey: "secondaryUsedPercent") as? Int
        secondaryResetDate = defaults.object(forKey: "secondaryResetDate") as? Date
        automaticResetCredits = nil
        manualResetCredits = defaults.object(forKey: "manualResetCredits") as? Int ?? 2
        manualResetExpirationDates = defaults.array(forKey: "manualResetExpirationDates") as? [Date] ?? UsageStore.defaultResetExpirationDates()
        automaticallySyncs = defaults.object(forKey: "automaticallySyncs") as? Bool ?? true
        lastAppliedCodexSnapshotDate = defaults.object(forKey: "lastAppliedCodexSnapshotDate") as? Date ?? .distantPast
    }

    func setUsedPercent(_ value: Int) {
        usedPercent = value
    }

    func changeUsage(by amount: Int) {
        setUsedPercent(usedPercent + amount)
    }

    @discardableResult
    func syncFromCodexSessions(force: Bool = false) -> Bool {
        syncResetCreditsIfNeeded(force: force)
        guard !isSyncingSessions else {
            if force { queuedForcedSessionSync = true }
            return false
        }
        isSyncingSessions = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let snapshot = self.codexReader.latestSnapshot()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isSyncingSessions = false
                if let snapshot {
                    self.applyCodexSnapshot(snapshot)
                }
                if self.queuedForcedSessionSync {
                    self.queuedForcedSessionSync = false
                    _ = self.syncFromCodexSessions(force: true)
                }
            }
        }
        return true
    }

    private func applyCodexSnapshot(_ snapshot: RateLimitSnapshot) {
        guard snapshot.observedAt > lastAppliedCodexSnapshotDate else { return }

        suppressesChangeNotification = true
        defer {
            suppressesChangeNotification = false
            lastAppliedCodexSnapshotDate = snapshot.observedAt
            UserDefaults.standard.set(snapshot.observedAt, forKey: "lastAppliedCodexSnapshotDate")
            onChange?()
        }

        let hasPreviousSnapshot = lastAppliedCodexSnapshotDate != .distantPast
        let primaryMovesBackward = hasPreviousSnapshot && snapshot.primaryResetDate < resetDate.addingTimeInterval(-60)
        if !primaryMovesBackward {
            let sameWindow = abs(snapshot.primaryResetDate.timeIntervalSince(resetDate)) < 60
            usedPercent = sameWindow ? max(usedPercent, snapshot.primaryUsedPercent) : snapshot.primaryUsedPercent
            resetDate = snapshot.primaryResetDate
        }

        if let incomingUsedPercent = snapshot.secondaryUsedPercent,
           let incomingResetDate = snapshot.secondaryResetDate {
            let secondaryMovesBackward = hasPreviousSnapshot && secondaryResetDate.map {
                incomingResetDate < $0.addingTimeInterval(-60)
            } ?? false
            if !secondaryMovesBackward {
                let sameWindow = secondaryResetDate.map {
                    abs(incomingResetDate.timeIntervalSince($0)) < 60
                } ?? false
                secondaryUsedPercent = sameWindow ? max(secondaryUsedPercent ?? 0, incomingUsedPercent) : incomingUsedPercent
                secondaryResetDate = incomingResetDate
            }
        }
    }

    var effectiveResetCreditCount: Int {
        if automaticallySyncs, let automaticResetCredits {
            return automaticResetCredits.availableCount
        }
        return manualResetCredits
    }

    var effectiveResetExpirationDates: [Date] {
        if automaticallySyncs, let automaticResetCredits {
            return automaticResetCredits.expirationDates
        }
        return manualResetExpirationDates
    }

    var hasAutomaticallySyncedResetCredits: Bool {
        automaticallySyncs && automaticResetCredits != nil
    }

    private func syncResetCreditsIfNeeded(force: Bool = false) {
        let now = Date()
        guard !isSyncingResetCredits else {
            if force { queuedForcedResetCreditSync = true }
            return
        }
        guard force || now.timeIntervalSince(lastResetCreditSyncAttempt) >= 60 else {
            return
        }

        isSyncingResetCredits = true
        lastResetCreditSyncAttempt = now
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let snapshot = self.resetCreditReader.latestSnapshot()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isSyncingResetCredits = false
                if let snapshot {
                    self.automaticResetCredits = snapshot
                }
                if self.queuedForcedResetCreditSync {
                    self.queuedForcedResetCreditSync = false
                    self.syncResetCreditsIfNeeded(force: true)
                }
            }
        }
    }

    private static func defaultResetExpirationDates() -> [Date] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return [
            calendar.date(from: DateComponents(year: year, month: 7, day: 27, hour: 23, minute: 59)),
            calendar.date(from: DateComponents(year: year, month: 8, day: 1, hour: 23, minute: 59))
        ].compactMap { $0 }
    }
}

private struct RateLimitSnapshot {
    let observedAt: Date
    let primaryUsedPercent: Int
    let primaryResetDate: Date
    let secondaryUsedPercent: Int?
    let secondaryResetDate: Date?
}

struct RateLimitResetCreditSnapshot {
    let availableCount: Int
    let expirationDates: [Date]
}

private final class CodexRateLimitReader {
    private let sessionDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/sessions", isDirectory: true)

    func latestSnapshot() -> RateLimitSnapshot? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: sessionDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        var candidates: [(url: URL, modifiedAt: Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]), values.isRegularFile == true else {
                continue
            }
            candidates.append((url, values.contentModificationDate ?? .distantPast))
        }

        return candidates
            .sorted(by: { $0.modifiedAt > $1.modifiedAt })
            .prefix(12)
            .compactMap { snapshot(from: $0.url, fallbackDate: $0.modifiedAt) }
            .max { lhs, rhs in
                if lhs.observedAt == rhs.observedAt {
                    return lhs.primaryUsedPercent < rhs.primaryUsedPercent
                }
                return lhs.observedAt < rhs.observedAt
            }
    }

    private func snapshot(from url: URL, fallbackDate: Date) -> RateLimitSnapshot? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        let startOffset = max(0, size.int64Value - 524_288)
        try? handle.seek(toOffset: UInt64(startOffset))
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        for line in text.split(separator: "\n").reversed() {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)),
                  let limits = findRateLimits(in: object),
                  let primary = limits["primary"] as? [String: Any],
                  let percent = integer(from: primary["used_percent"]),
                  let resetsAt = integer(from: primary["resets_at"]) else {
                continue
            }
            let secondary = limits["secondary"] as? [String: Any]
            return RateLimitSnapshot(
                observedAt: eventDate(from: object) ?? fallbackDate,
                primaryUsedPercent: percent,
                primaryResetDate: Date(timeIntervalSince1970: TimeInterval(resetsAt)),
                secondaryUsedPercent: integer(from: secondary?["used_percent"]),
                secondaryResetDate: integer(from: secondary?["resets_at"]).map { Date(timeIntervalSince1970: TimeInterval($0)) }
            )
        }
        return nil
    }

    private func eventDate(from value: Any) -> Date? {
        guard let dictionary = value as? [String: Any],
              let timestamp = dictionary["timestamp"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp)
    }

    private func findRateLimits(in value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            if let limits = dictionary["rate_limits"] as? [String: Any] {
                return limits
            }
            for child in dictionary.values {
                if let limits = findRateLimits(in: child) {
                    return limits
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let limits = findRateLimits(in: child) {
                    return limits
                }
            }
        }
        return nil
    }

    private func integer(from value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let number = value as? Int { return number }
        return nil
    }

}

private final class CodexRateLimitResetReader {
    func latestSnapshot() -> RateLimitResetCreditSnapshot? {
        guard let executableURL = codexExecutableURL(), let payload = requestPayload() else {
            return nil
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let collector = CodexRateLimitResponseCollector()

        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                collector.finishWithoutResult()
            } else {
                collector.consume(data)
            }
        }

        do {
            try process.run()
            inputPipe.fileHandleForWriting.write(payload)
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }

        _ = collector.completed.wait(timeout: .now() + 20)
        outputPipe.fileHandleForReading.readabilityHandler = nil
        try? inputPipe.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        return collector.result()
    }

    private func codexExecutableURL() -> URL? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        var candidates: [URL] = []

        if let chatGPTURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.chat") {
            candidates.append(chatGPTURL.appendingPathComponent("Contents/Resources/codex"))
        }
        candidates.append(URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"))
        candidates.append(home.appendingPathComponent("Applications/ChatGPT.app/Contents/Resources/codex"))
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/codex"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/codex"))

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                URL(fileURLWithPath: String($0)).appendingPathComponent("codex")
            })
        }

        return candidates.first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func requestPayload() -> Data? {
        let messages: [[String: Any]] = [
            [
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": ["name": "codex-quota-widget", "version": "1.0"],
                    "capabilities": ["experimentalApi": true]
                ]
            ],
            ["method": "initialized", "params": [:]],
            ["id": 2, "method": "account/rateLimits/read", "params": NSNull()]
        ]

        var payload = Data()
        for message in messages {
            guard let data = try? JSONSerialization.data(withJSONObject: message) else {
                return nil
            }
            payload.append(data)
            payload.append(0x0A)
        }
        return payload
    }
}

private final class CodexRateLimitResponseCollector {
    let completed = DispatchSemaphore(value: 0)

    private let lock = NSLock()
    private var buffer = Data()
    private var snapshot: RateLimitResetCreditSnapshot?
    private var isFinished = false

    func consume(_ data: Data) {
        var lines: [Data] = []
        lock.lock()
        buffer.append(data)
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            lines.append(Data(buffer[..<newlineIndex]))
            buffer.removeSubrange(...newlineIndex)
        }
        lock.unlock()

        for line in lines where !line.isEmpty {
            parse(line)
        }
    }

    func finishWithoutResult() {
        finish(with: nil)
    }

    func result() -> RateLimitResetCreditSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }

    private func parse(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["id"] as? NSNumber)?.intValue == 2 else {
            return
        }
        guard let result = object["result"] as? [String: Any],
              let summary = result["rateLimitResetCredits"] as? [String: Any],
              let availableCount = (summary["availableCount"] as? NSNumber)?.intValue else {
            finish(with: nil)
            return
        }

        let credits = summary["credits"] as? [[String: Any]] ?? []
        let expirationDates = credits.compactMap { credit -> Date? in
            guard credit["status"] as? String == "available",
                  let timestamp = credit["expiresAt"] as? NSNumber else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp.doubleValue)
        }.sorted()

        finish(with: RateLimitResetCreditSnapshot(
            availableCount: max(0, availableCount),
            expirationDates: expirationDates
        ))
    }

    private func finish(with snapshot: RateLimitResetCreditSnapshot?) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        self.snapshot = snapshot
        isFinished = true
        lock.unlock()
        completed.signal()
    }
}

final class WidgetContentView: NSView {
    private let store: UsageStore
    private let hideAction: () -> Void
    private let titleLabel = makeLabel(font: .systemFont(ofSize: 14, weight: .semibold), color: .white)
    private let detailLabel = makeLabel(font: .systemFont(ofSize: 11), color: NSColor.white.withAlphaComponent(0.62))
    private let percentageLabel = makeLabel(font: .monospacedDigitSystemFont(ofSize: 15, weight: .semibold), color: .white, alignment: .center)
    private var settingsController: SettingsWindowController?
    private var timer: Timer?
    private var syncTimer: Timer?
    private var reduceButton: NSButton!
    private var resetButton: NSButton!
    private var increaseButton: NSButton!
    private var refreshButton: NSButton!

    override var isFlipped: Bool { true }

    init(store: UsageStore, hideAction: @escaping () -> Void) {
        self.store = store
        self.hideAction = hideAction
        super.init(frame: NSRect(x: 0, y: 0, width: 282, height: 148))
        wantsLayer = true
        store.onChange = { [weak self] in self?.refresh() }
        buildControls()
        syncCodexUsage()
        refresh()
        timer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        syncTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(syncCodexUsage), userInfo: nil, repeats: true)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        timer?.invalidate()
        syncTimer?.invalidate()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        NSColor.black.withAlphaComponent(0.80).setFill()
        background.fill()
        NSColor.white.withAlphaComponent(0.16).setStroke()
        background.lineWidth = 1
        background.stroke()

        let accent = accentColor
        let ringRect = NSRect(x: 16, y: 17, width: 54, height: 54).insetBy(dx: 3, dy: 3)
        let backgroundRing = NSBezierPath(ovalIn: ringRect)
        NSColor.white.withAlphaComponent(0.14).setStroke()
        backgroundRing.lineWidth = 6
        backgroundRing.stroke()

        if store.usedPercent > 0 {
            let ring = NSBezierPath()
            let endAngle = -90 + (360 * CGFloat(store.usedPercent) / 100)
            ring.appendArc(withCenter: NSPoint(x: ringRect.midX, y: ringRect.midY), radius: ringRect.width / 2, startAngle: -90, endAngle: endAngle, clockwise: false)
            accent.setStroke()
            ring.lineWidth = 6
            ring.lineCapStyle = .round
            ring.stroke()
        }

        let barRect = NSRect(x: 16, y: 86, width: 250, height: 6)
        let barBackground = NSBezierPath(roundedRect: barRect, xRadius: 3, yRadius: 3)
        NSColor.white.withAlphaComponent(0.13).setFill()
        barBackground.fill()
        let width = max(6, barRect.width * CGFloat(store.usedPercent) / 100)
        let barForeground = NSBezierPath(roundedRect: NSRect(x: barRect.minX, y: barRect.minY, width: width, height: barRect.height), xRadius: 3, yRadius: 3)
        accent.setFill()
        barForeground.fill()
    }

    @objc private func refresh() {
        percentageLabel.stringValue = String(format: "%d%%", store.usedPercent)
        detailLabel.stringValue = store.automaticallySyncs ? automaticDescription() : resetDescription()
        updateControlVisibility()
        needsDisplay = true
    }

    @objc private func syncCodexUsage() {
        guard store.automaticallySyncs else { return }
        _ = store.syncFromCodexSessions()
    }

    @objc private func reduceUsage() {
        store.changeUsage(by: -5)
    }

    @objc private func resetUsage() {
        store.setUsedPercent(0)
    }

    @objc private func increaseUsage() {
        store.changeUsage(by: 5)
    }

    @objc private func showSettings() {
        let controller = SettingsWindowController(store: store)
        settingsController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func hideWidget() {
        hideAction()
    }

    private func buildControls() {
        titleLabel.stringValue = "额度使用"
        titleLabel.frame = NSRect(x: 83, y: 24, width: 140, height: 18)
        addSubview(titleLabel)

        detailLabel.frame = NSRect(x: 83, y: 49, width: 145, height: 16)
        addSubview(detailLabel)

        percentageLabel.frame = NSRect(x: 16, y: 35, width: 54, height: 20)
        addSubview(percentageLabel)

        let settingsButton = iconButton(symbol: "gearshape", toolTip: "设置额度和重置时间", action: #selector(showSettings))
        settingsButton.frame = NSRect(x: 238, y: 20, width: 28, height: 28)
        addSubview(settingsButton)

        reduceButton = iconButton(symbol: "minus", toolTip: "减少 5%", action: #selector(reduceUsage))
        reduceButton.frame = NSRect(x: 16, y: 106, width: 30, height: 26)
        addSubview(reduceButton)

        resetButton = iconButton(symbol: "arrow.counterclockwise", toolTip: "清零", action: #selector(resetUsage))
        resetButton.frame = NSRect(x: 50, y: 106, width: 30, height: 26)
        addSubview(resetButton)

        increaseButton = iconButton(symbol: "plus", toolTip: "增加 5%", action: #selector(increaseUsage))
        increaseButton.frame = NSRect(x: 204, y: 106, width: 30, height: 26)
        addSubview(increaseButton)

        refreshButton = iconButton(symbol: "arrow.clockwise", toolTip: "立即同步", action: #selector(syncCodexUsage))
        refreshButton.frame = NSRect(x: 16, y: 106, width: 30, height: 26)
        addSubview(refreshButton)

        let closeButton = iconButton(symbol: "xmark", toolTip: "隐藏小组件", action: #selector(hideWidget))
        closeButton.frame = NSRect(x: 238, y: 106, width: 28, height: 26)
        addSubview(closeButton)
    }

    private func resetDescription() -> String {
        let interval = store.resetDate.timeIntervalSinceNow
        guard interval > 0 else { return "等待更新" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3_600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        let duration = formatter.string(from: interval) ?? ""
        return String(format: "约 %@ 后重置", duration)
    }

    private func automaticDescription() -> String {
        let windowText = store.secondaryUsedPercent.map { String(format: "长期 %d%%", $0) } ?? "自动同步"
        return String(format: "%@ · %@", windowText, resetDescription())
    }

    private func updateControlVisibility() {
        let automaticallySyncs = store.automaticallySyncs
        reduceButton.isHidden = automaticallySyncs
        resetButton.isHidden = automaticallySyncs
        increaseButton.isHidden = automaticallySyncs
        refreshButton.isHidden = !automaticallySyncs
    }

    private var accentColor: NSColor {
        switch store.usedPercent {
        case 95...: .systemRed
        case 80...: .systemOrange
        default: .systemMint
        }
    }

    private func iconButton(symbol: String, toolTip: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip) ?? NSImage(), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        button.contentTintColor = .white
        button.toolTip = toolTip
        button.imageScaling = .scaleProportionallyDown
        return button
    }

    private static func makeLabel(font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = font
        label.textColor = color
        label.alignment = alignment
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}

final class SettingsWindowController: NSWindowController {
    private let store: UsageStore
    private let percentField = NSTextField(string: "")
    private let stepper = NSStepper()
    private let datePicker = NSDatePicker()
    private let autoSyncButton = NSButton(checkboxWithTitle: "自动同步", target: nil, action: nil)
    private let resetCreditField = NSTextField(string: "")
    private let resetCreditStepper = NSStepper()
    private let firstResetExpiryPicker = NSDatePicker()
    private let secondResetExpiryPicker = NSDatePicker()

    init(store: UsageStore) {
        self.store = store
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 282, height: 370),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "额度设置"
        panel.isReleasedWhenClosed = false
        super.init(window: panel)
        setupContent(in: panel)
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func stepperChanged() {
        percentField.integerValue = stepper.integerValue
    }

    @objc private func autoSyncChanged() {
        updateInputState()
    }

    @objc private func resetCreditChanged() {
        resetCreditField.integerValue = resetCreditStepper.integerValue
    }

    @objc private func save() {
        store.automaticallySyncs = autoSyncButton.state == .on
        if !store.hasAutomaticallySyncedResetCredits {
            store.manualResetCredits = resetCreditField.integerValue
            store.manualResetExpirationDates = [firstResetExpiryPicker.dateValue, secondResetExpiryPicker.dateValue]
        }
        if store.automaticallySyncs {
            _ = store.syncFromCodexSessions()
        } else {
            store.setUsedPercent(percentField.integerValue)
            store.resetDate = datePicker.dateValue
        }
        close()
    }

    private func setupContent(in panel: NSPanel) {
        let content = NSView(frame: panel.contentView?.bounds ?? .zero)
        panel.contentView = content

        let usageLabel = NSTextField(labelWithString: "已使用额度")
        usageLabel.frame = NSRect(x: 20, y: 315, width: 96, height: 20)
        content.addSubview(usageLabel)

        percentField.integerValue = store.usedPercent
        percentField.alignment = .right
        percentField.frame = NSRect(x: 142, y: 311, width: 52, height: 24)
        content.addSubview(percentField)

        let percentSuffix = NSTextField(labelWithString: "%")
        percentSuffix.frame = NSRect(x: 198, y: 315, width: 14, height: 20)
        content.addSubview(percentSuffix)

        stepper.minValue = 0
        stepper.maxValue = 100
        stepper.increment = 1
        stepper.integerValue = store.usedPercent
        stepper.target = self
        stepper.action = #selector(stepperChanged)
        stepper.frame = NSRect(x: 220, y: 311, width: 20, height: 24)
        content.addSubview(stepper)

        let resetLabel = NSTextField(labelWithString: "重置时间")
        resetLabel.frame = NSRect(x: 20, y: 265, width: 96, height: 20)
        content.addSubview(resetLabel)

        datePicker.dateValue = store.resetDate
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.frame = NSRect(x: 112, y: 261, width: 148, height: 24)
        content.addSubview(datePicker)

        autoSyncButton.state = store.automaticallySyncs ? .on : .off
        autoSyncButton.target = self
        autoSyncButton.action = #selector(autoSyncChanged)
        autoSyncButton.frame = NSRect(x: 20, y: 212, width: 110, height: 24)
        content.addSubview(autoSyncButton)

        let resetCreditLabel = NSTextField(labelWithString: "限额重置次数")
        resetCreditLabel.frame = NSRect(x: 20, y: 170, width: 112, height: 20)
        content.addSubview(resetCreditLabel)

        resetCreditField.integerValue = store.effectiveResetCreditCount
        resetCreditField.alignment = .right
        resetCreditField.frame = NSRect(x: 174, y: 166, width: 42, height: 24)
        content.addSubview(resetCreditField)

        resetCreditStepper.minValue = 0
        resetCreditStepper.maxValue = 99
        resetCreditStepper.increment = 1
        resetCreditStepper.integerValue = store.effectiveResetCreditCount
        resetCreditStepper.target = self
        resetCreditStepper.action = #selector(resetCreditChanged)
        resetCreditStepper.frame = NSRect(x: 224, y: 166, width: 20, height: 24)
        content.addSubview(resetCreditStepper)

        let firstResetExpiryLabel = NSTextField(labelWithString: "重置 1 到期")
        firstResetExpiryLabel.frame = NSRect(x: 20, y: 120, width: 96, height: 20)
        content.addSubview(firstResetExpiryLabel)

        firstResetExpiryPicker.dateValue = store.effectiveResetExpirationDates.first ?? store.manualResetExpirationDates.first ?? Date()
        firstResetExpiryPicker.datePickerElements = [.yearMonthDay]
        firstResetExpiryPicker.datePickerStyle = .textFieldAndStepper
        firstResetExpiryPicker.frame = NSRect(x: 132, y: 116, width: 128, height: 24)
        content.addSubview(firstResetExpiryPicker)

        let secondResetExpiryLabel = NSTextField(labelWithString: "重置 2 到期")
        secondResetExpiryLabel.frame = NSRect(x: 20, y: 75, width: 96, height: 20)
        content.addSubview(secondResetExpiryLabel)

        secondResetExpiryPicker.dateValue = store.effectiveResetExpirationDates.dropFirst().first ?? store.manualResetExpirationDates.dropFirst().first ?? Date()
        secondResetExpiryPicker.datePickerElements = [.yearMonthDay]
        secondResetExpiryPicker.datePickerStyle = .textFieldAndStepper
        secondResetExpiryPicker.frame = NSRect(x: 132, y: 71, width: 128, height: 24)
        content.addSubview(secondResetExpiryPicker)

        let saveButton = NSButton(title: "更新", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 190, y: 22, width: 70, height: 28)
        content.addSubview(saveButton)

        updateInputState()
    }

    private func updateInputState() {
        let allowsManualEntry = autoSyncButton.state != .on
        percentField.isEnabled = allowsManualEntry
        stepper.isEnabled = allowsManualEntry
        datePicker.isEnabled = allowsManualEntry
        let allowsManualResetEntry = autoSyncButton.state != .on || store.automaticResetCredits == nil
        resetCreditField.isEnabled = allowsManualResetEntry
        resetCreditStepper.isEnabled = allowsManualResetEntry
        firstResetExpiryPicker.isEnabled = allowsManualResetEntry
        secondResetExpiryPicker.isEnabled = allowsManualResetEntry
    }
}

private enum QuotaDetailKind {
    case hourly
    case weekly
    case reset

    var symbolName: String {
        switch self {
        case .hourly: "clock"
        case .weekly: "calendar"
        case .reset: "arrow.counterclockwise"
        }
    }
}

final class GlassIconWidgetView: NSView {
    private let store: UsageStore
    private let detailChanged: (HoverDetail?, QuotaDetailKind?) -> Void
    private var clockTimer: Timer?
    private var syncTimer: Timer?
    private var visibleDetail: QuotaDetailKind?

    override var isFlipped: Bool { true }

    fileprivate init(store: UsageStore, detailChanged: @escaping (HoverDetail?, QuotaDetailKind?) -> Void) {
        self.store = store
        self.detailChanged = detailChanged
        super.init(frame: NSRect(x: 0, y: 0, width: 108, height: 310))

        let stack = GlassStackBackground(frame: NSRect(x: 10, y: 8, width: 88, height: 294))
        addSubview(stack)

        let hourlyIcon = GlassQuotaIconView(
            kind: .hourly,
            hoverChanged: { [weak self] kind, isHovering in
                self?.updateHover(kind: kind, isHovering: isHovering)
            },
            clicked: { [weak self] in self?.requestManualRefresh() }
        )
        hourlyIcon.frame = NSRect(x: 6, y: 22, width: 96, height: 84)
        addSubview(hourlyIcon)

        let weeklyIcon = GlassQuotaIconView(
            kind: .weekly,
            hoverChanged: { [weak self] kind, isHovering in
                self?.updateHover(kind: kind, isHovering: isHovering)
            },
            clicked: { [weak self] in self?.requestManualRefresh() }
        )
        weeklyIcon.frame = NSRect(x: 6, y: 113, width: 96, height: 84)
        addSubview(weeklyIcon)

        let resetIcon = GlassQuotaIconView(
            kind: .reset,
            hoverChanged: { [weak self] kind, isHovering in
                self?.updateHover(kind: kind, isHovering: isHovering)
            },
            clicked: { [weak self] in self?.requestManualRefresh() }
        )
        resetIcon.frame = NSRect(x: 6, y: 204, width: 96, height: 84)
        addSubview(resetIcon)

        store.onChange = { [weak self] in self?.refresh() }
        syncCodexUsage()
        refresh()
        clockTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        syncTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(syncCodexUsage), userInfo: nil, repeats: true)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        clockTimer?.invalidate()
        syncTimer?.invalidate()
    }

    @objc private func refresh() {
        if let visibleDetail {
            detailChanged(detail(for: visibleDetail), visibleDetail)
        }
    }

    @objc private func syncCodexUsage() {
        guard store.automaticallySyncs else { return }
        _ = store.syncFromCodexSessions()
    }

    private func requestManualRefresh() {
        guard store.automaticallySyncs else { return }
        _ = store.syncFromCodexSessions(force: true)
    }

    private func updateHover(kind: QuotaDetailKind, isHovering: Bool) {
        if isHovering {
            visibleDetail = kind
            detailChanged(detail(for: kind), kind)
        } else if visibleDetail == kind {
            visibleDetail = nil
            detailChanged(nil, nil)
        }
    }

    private func detail(for kind: QuotaDetailKind) -> HoverDetail {
        switch kind {
        case .hourly:
            return HoverDetail(
                title: "5 小时使用限制",
                resetText: usageResetText(for: store.resetDate),
                usedPercent: store.usedPercent,
                trailingText: String(format: "剩余 %d%%", 100 - store.usedPercent)
            )
        case .weekly:
            let resetDate = store.secondaryResetDate ?? store.resetDate
            let usedPercent = store.secondaryUsedPercent
            return HoverDetail(
                title: "周使用限制",
                resetText: usageResetText(for: resetDate),
                usedPercent: usedPercent,
                trailingText: usedPercent.map { String(format: "剩余 %d%%", 100 - $0) } ?? "等待同步"
            )
        case .reset:
            return resetCreditDetail()
        }
    }

    private func resetDescription(for date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "等待更新" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3_600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        return String(format: "约 %@ 后重置", formatter.string(from: interval) ?? "")
    }

    private func timeDescription(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "今天 HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func usageResetText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "将于 HH:mm 重置" : "将于 M月d日 HH:mm 重置"
        return formatter.string(from: date)
    }

    private func resetCreditDetail() -> HoverDetail {
        let availableCount = store.effectiveResetCreditCount
        if availableCount > 0 {
            return HoverDetail(
                title: "使用限额重置",
                resetText: resetExpirationSummary(),
                usedPercent: nil,
                trailingText: String(format: "可用 %d 次", availableCount)
            )
        }
        return HoverDetail(title: "使用限额重置", resetText: "额度会按时间窗自动恢复", usedPercent: nil, trailingText: "暂无可用")
    }

    private func resetExpirationSummary() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        let dates = store.effectiveResetExpirationDates.prefix(store.effectiveResetCreditCount).map(formatter.string)
        if dates.isEmpty, store.hasAutomaticallySyncedResetCredits {
            return "已自动同步 · 到期时间未提供"
        }
        return dates.isEmpty ? "Full reset（周 + 5 小时）" : "到期：" + dates.joined(separator: " · ")
    }
}

private final class GlassStackBackground: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 16, yRadius: 16)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.set()
        let gradient = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.92),
            NSColor(srgbRed: 0.92, green: 0.92, blue: 0.91, alpha: 0.70)
        ])
        gradient?.draw(in: shape, angle: -90)
        NSColor.white.withAlphaComponent(0.92).setStroke()
        shape.lineWidth = 1
        shape.stroke()

        let inner = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 12, yRadius: 12)
        NSColor.white.withAlphaComponent(0.72).setStroke()
        inner.lineWidth = 1
        inner.stroke()
    }
}

private final class GlassQuotaIconView: NSView {
    private let kind: QuotaDetailKind
    private let hoverChanged: (QuotaDetailKind, Bool) -> Void
    private let clicked: () -> Void
    private let imageView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovering = false {
        didSet { updateHoverAppearance() }
    }
    private var isPressed = false {
        didSet { updateHoverAppearance() }
    }

    override var isFlipped: Bool { true }

    init(
        kind: QuotaDetailKind,
        hoverChanged: @escaping (QuotaDetailKind, Bool) -> Void,
        clicked: @escaping () -> Void
    ) {
        self.kind = kind
        self.hoverChanged = hoverChanged
        self.clicked = clicked
        super.init(frame: .zero)
        wantsLayer = true
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 25, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.14, alpha: 1)))
        imageView.image = NSImage(systemSymbolName: kind.symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(symbolConfiguration)
        imageView.image?.isTemplate = false
        imageView.contentTintColor = NSColor(srgbRed: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        imageView.imageScaling = .scaleProportionallyDown
        imageView.frame = symbolFrame(hovering: false)
        imageView.wantsLayer = true
        addSubview(imageView)
        toolTip = accessibilityTitle + "，点击立即刷新"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(accessibilityTitle + "，点击立即刷新")
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let newTrackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        hoverChanged(kind, true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        hoverChanged(kind, false)
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
    }

    override func mouseUp(with event: NSEvent) {
        let isInside = bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        guard isInside else { return }
        performRefreshAnimation()
        clicked()
    }

    override func accessibilityPerformPress() -> Bool {
        performRefreshAnimation()
        clicked()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let isActive = isHovering || isPressed
        let base = orbFrame(hovering: isActive)
        if isActive {
            for index in stride(from: 3, through: 1, by: -1) {
                let ripple = base.offsetBy(dx: CGFloat(-index * 4), dy: CGFloat(index * 4))
                NSColor.white.withAlphaComponent(0.30 + CGFloat(index) * 0.12).setFill()
                NSBezierPath(ovalIn: ripple).fill()
            }
        }

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
        shadow.shadowBlurRadius = 7
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.set()
        let orb = NSBezierPath(ovalIn: base)
        let gradient = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.98),
            NSColor.white.withAlphaComponent(0.76),
            NSColor(srgbRed: 0.90, green: 0.90, blue: 0.88, alpha: 0.84)
        ])
        gradient?.draw(in: orb, relativeCenterPosition: NSPoint(x: -0.2, y: 0.25))
        NSColor.white.withAlphaComponent(0.98).setStroke()
        orb.lineWidth = 1
        orb.stroke()
    }

    private func updateHoverAppearance() {
        let isActive = isHovering || isPressed
        needsDisplay = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            imageView.animator().frame = symbolFrame(hovering: isActive)
        }
    }

    private func performRefreshAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1, 0.78, 1.14, 1]
        animation.keyTimes = [0, 0.22, 0.62, 1]
        animation.duration = 0.42
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer?.add(animation, forKey: "manualRefreshPulse")
    }

    private func orbFrame(hovering: Bool) -> NSRect {
        NSRect(x: hovering ? 28 : 18, y: hovering ? 2 : 13, width: 60, height: 60)
    }

    private func symbolFrame(hovering: Bool) -> NSRect {
        NSRect(x: hovering ? 46 : 36, y: hovering ? 20 : 31, width: 24, height: 24)
    }

    private var accessibilityTitle: String {
        switch kind {
        case .hourly: "小时额度"
        case .weekly: "周额度"
        case .reset: "重置时间"
        }
    }
}

private struct HoverDetail {
    let title: String
    let resetText: String
    let usedPercent: Int?
    let trailingText: String
}

private final class HoverDetailCard: NSView {
    private let titleLabel = HoverDetailCard.label(font: .systemFont(ofSize: 19, weight: .semibold), color: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 1))
    private let resetLabel = HoverDetailCard.label(font: .systemFont(ofSize: 16, weight: .medium), color: NSColor(srgbRed: 0.37, green: 0.37, blue: 0.40, alpha: 1))
    private let trailingLabel = HoverDetailCard.label(font: .systemFont(ofSize: 15, weight: .medium), color: NSColor(srgbRed: 0.35, green: 0.35, blue: 0.38, alpha: 1))
    private var detail: HoverDetail?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true

        titleLabel.frame = NSRect(x: 20, y: 15, width: 208, height: 26)
        resetLabel.frame = NSRect(x: 20, y: 47, width: 208, height: 23)
        trailingLabel.alignment = .right
        addSubview(titleLabel)
        addSubview(resetLabel)
        addSubview(trailingLabel)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 18, yRadius: 18)
        let gradient = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.96),
            NSColor.white.withAlphaComponent(0.73)
        ])
        gradient?.draw(in: shape, angle: -90)
        NSColor.black.withAlphaComponent(0.10).setStroke()
        shape.lineWidth = 1
        shape.stroke()

        let inner = NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 5), xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.06).setStroke()
        inner.lineWidth = 1
        inner.stroke()

        guard let detail else { return }
        if let usedPercent = detail.usedPercent {
            let track = NSRect(x: 225, y: 43, width: 130, height: 16)
            NSColor(srgbRed: 0.82, green: 0.82, blue: 0.84, alpha: 1).setFill()
            NSBezierPath(roundedRect: track, xRadius: 8, yRadius: 8).fill()
            let remainingWidth = max(8, track.width * CGFloat(100 - usedPercent) / 100)
            NSColor(srgbRed: 0.66, green: 0.91, blue: 0.72, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY, width: remainingWidth, height: track.height), xRadius: 8, yRadius: 8).fill()
        } else {
            let pill = NSRect(x: 342, y: 27, width: 94, height: 34)
            NSColor(srgbRed: 0.85, green: 0.95, blue: 0.88, alpha: 0.92).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 17, yRadius: 17).fill()
        }
    }

    func configure(with detail: HoverDetail) {
        self.detail = detail
        titleLabel.stringValue = detail.title
        resetLabel.stringValue = detail.resetText
        trailingLabel.stringValue = detail.trailingText
        if detail.usedPercent == nil {
            trailingLabel.textColor = NSColor(srgbRed: 0.08, green: 0.39, blue: 0.20, alpha: 1)
            trailingLabel.frame = NSRect(x: 346, y: 34, width: 84, height: 20)
        } else {
            trailingLabel.textColor = NSColor(srgbRed: 0.35, green: 0.35, blue: 0.38, alpha: 1)
            trailingLabel.frame = NSRect(x: 365, y: 39, width: 75, height: 24)
        }
        needsDisplay = true
    }

    private static func label(font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}

private enum DoodlePalette {
    static let paper = NSColor(srgbRed: 0.99, green: 0.98, blue: 0.95, alpha: 1)
    static let ink = NSColor(srgbRed: 0.17, green: 0.17, blue: 0.17, alpha: 1)
    static let line = NSColor(srgbRed: 0.90, green: 0.88, blue: 0.83, alpha: 1)
    static let tape = NSColor(srgbRed: 1, green: 0.87, blue: 0.63, alpha: 0.85)
    static let mint = NSColor(srgbRed: 0.78, green: 0.89, blue: 0.47, alpha: 1)
    static let coral = NSColor(srgbRed: 1, green: 0.55, blue: 0.66, alpha: 1)
    static let lavender = NSColor(srgbRed: 0.75, green: 0.73, blue: 0.99, alpha: 1)
    static let yellow = NSColor(srgbRed: 1, green: 0.87, blue: 0.42, alpha: 1)
}

private enum DoodleDrawing {
    static func paperPath(in rect: NSRect) -> NSBezierPath {
        let scale = DoodleMetrics.scale
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + 13 * scale, y: rect.minY + 12 * scale))
        path.curve(to: NSPoint(x: rect.maxX - 14 * scale, y: rect.minY + 9 * scale), controlPoint1: NSPoint(x: rect.midX - 44 * scale, y: rect.minY + 5 * scale), controlPoint2: NSPoint(x: rect.maxX - 52 * scale, y: rect.minY + 7 * scale))
        path.curve(to: NSPoint(x: rect.maxX - 10 * scale, y: rect.maxY - 15 * scale), controlPoint1: NSPoint(x: rect.maxX - 5 * scale, y: rect.minY + 24 * scale), controlPoint2: NSPoint(x: rect.maxX - 8 * scale, y: rect.maxY - 50 * scale))
        path.curve(to: NSPoint(x: rect.minX + 16 * scale, y: rect.maxY - 10 * scale), controlPoint1: NSPoint(x: rect.maxX - 76 * scale, y: rect.maxY - 5 * scale), controlPoint2: NSPoint(x: rect.midX - 58 * scale, y: rect.maxY - 5 * scale))
        path.curve(to: NSPoint(x: rect.minX + 9 * scale, y: rect.minY + 19 * scale), controlPoint1: NSPoint(x: rect.minX + 6 * scale, y: rect.maxY - 34 * scale), controlPoint2: NSPoint(x: rect.minX + 6 * scale, y: rect.minY + 53 * scale))
        path.close()
        return path
    }

    static func drawTape(in rect: NSRect) {
        let scale = DoodleMetrics.scale
        let tape = NSBezierPath()
        tape.move(to: NSPoint(x: rect.minX + 2 * scale, y: rect.minY + 3 * scale))
        tape.line(to: NSPoint(x: rect.maxX - 3 * scale, y: rect.minY))
        tape.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 3 * scale))
        tape.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        tape.close()
        DoodlePalette.tape.setFill()
        tape.fill()
        NSColor.black.withAlphaComponent(0.10).setStroke()
        tape.lineWidth = scale
        tape.stroke()
    }

    static func drawStar(center: NSPoint, radius: CGFloat, fill: NSColor) {
        let star = NSBezierPath()
        for index in 0..<10 {
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            let currentRadius = index.isMultiple(of: 2) ? radius : radius * 0.44
            let point = NSPoint(x: center.x + cos(angle) * currentRadius, y: center.y + sin(angle) * currentRadius)
            index == 0 ? star.move(to: point) : star.line(to: point)
        }
        star.close()
        fill.setFill()
        star.fill()
        DoodlePalette.ink.setStroke()
        star.lineWidth = 2.4 * DoodleMetrics.scale
        star.lineJoinStyle = .round
        star.stroke()
    }

    static func drawSparkle(center: NSPoint, radius: CGFloat, fill: NSColor) {
        let sparkle = NSBezierPath()
        sparkle.move(to: NSPoint(x: center.x, y: center.y - radius))
        sparkle.line(to: NSPoint(x: center.x + radius * 0.38, y: center.y - radius * 0.38))
        sparkle.line(to: NSPoint(x: center.x + radius, y: center.y))
        sparkle.line(to: NSPoint(x: center.x + radius * 0.38, y: center.y + radius * 0.38))
        sparkle.line(to: NSPoint(x: center.x, y: center.y + radius))
        sparkle.line(to: NSPoint(x: center.x - radius * 0.38, y: center.y + radius * 0.38))
        sparkle.line(to: NSPoint(x: center.x - radius, y: center.y))
        sparkle.line(to: NSPoint(x: center.x - radius * 0.38, y: center.y - radius * 0.38))
        sparkle.close()
        fill.setFill()
        sparkle.fill()
        DoodlePalette.ink.setStroke()
        sparkle.lineWidth = 2.2 * DoodleMetrics.scale
        sparkle.stroke()
    }
}

private final class DoodlePaperView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let scale = DoodleMetrics.scale
        let paper = DoodleDrawing.paperPath(in: bounds.insetBy(dx: 2 * scale, dy: 2 * scale))
        let shadow = paper.copy() as! NSBezierPath
        let transform = AffineTransform(translationByX: 6 * scale, byY: 7 * scale)
        shadow.transform(using: transform)
        DoodlePalette.ink.setFill()
        shadow.fill()

        DoodlePalette.paper.setFill()
        paper.fill()
        DoodlePalette.ink.setStroke()
        paper.lineWidth = 3.1 * scale
        paper.lineJoinStyle = .round
        paper.stroke()

        NSGraphicsContext.saveGraphicsState()
        paper.addClip()
        DoodlePalette.line.setStroke()
        for y in stride(from: CGFloat(30) * scale, through: bounds.maxY - 12 * scale, by: 17 * scale) {
            let line = NSBezierPath()
            line.move(to: NSPoint(x: 9 * scale, y: y))
            line.line(to: NSPoint(x: bounds.maxX - 8 * scale, y: y))
            line.lineWidth = scale
            line.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()

        DoodleDrawing.drawTape(in: NSRect(x: bounds.midX - 35 * scale, y: 0, width: 70 * scale, height: 17 * scale))
        DoodleDrawing.drawSparkle(center: NSPoint(x: 28 * scale, y: 37 * scale), radius: 9 * scale, fill: DoodlePalette.mint)
        DoodleDrawing.drawStar(center: NSPoint(x: bounds.maxX - 28 * scale, y: 36 * scale), radius: 10 * scale, fill: DoodlePalette.yellow)
    }
}

private final class DoodleIconButton: NSView {
    private let kind: QuotaDetailKind
    private let accent: NSColor
    private let hoverChanged: (QuotaDetailKind, Bool) -> Void
    private let clicked: () -> Void
    private let imageView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovering = false {
        didSet { updateHoverAppearance() }
    }
    private var isPressed = false {
        didSet { updateHoverAppearance() }
    }

    override var isFlipped: Bool { true }

    init(
        kind: QuotaDetailKind,
        accent: NSColor,
        hoverChanged: @escaping (QuotaDetailKind, Bool) -> Void,
        clicked: @escaping () -> Void
    ) {
        self.kind = kind
        self.accent = accent
        self.hoverChanged = hoverChanged
        self.clicked = clicked
        super.init(frame: .zero)
        imageView.image = NSImage(systemSymbolName: kind.symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 19 * DoodleMetrics.scale, weight: .bold))
        imageView.contentTintColor = DoodlePalette.ink
        imageView.imageScaling = .scaleProportionallyDown
        imageView.frame = iconFrame(hovered: false)
        imageView.wantsLayer = true
        addSubview(imageView)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title + "，点击立即刷新")
        toolTip = title + "，点击立即刷新"
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        hoverChanged(kind, true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        hoverChanged(kind, false)
    }

    override func mouseMoved(with event: NSEvent) {
        guard !isHovering else { return }
        isHovering = true
        hoverChanged(kind, true)
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
    }

    override func mouseUp(with event: NSEvent) {
        let isInside = bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        guard isInside else { return }
        performRefreshAnimation()
        clicked()
    }

    override func accessibilityPerformPress() -> Bool {
        performRefreshAnimation()
        clicked()
        return true
    }

    func refreshHoverTracking() {
        updateTrackingAreas()
    }

    override func draw(_ dirtyRect: NSRect) {
        let isActive = isHovering || isPressed
        let rect = buttonFrame(hovered: isActive)
        let shadow = NSShadow()
        shadow.shadowColor = DoodlePalette.ink
        shadow.shadowBlurRadius = 0
        shadow.shadowOffset = NSSize(width: 2.5 * DoodleMetrics.scale, height: -2.5 * DoodleMetrics.scale)
        shadow.set()
        let path = NSBezierPath(ovalIn: rect)
        (isActive ? accent : .white).setFill()
        path.fill()
        DoodlePalette.ink.setStroke()
        path.lineWidth = 2.5 * DoodleMetrics.scale
        path.stroke()
    }

    private func updateHoverAppearance() {
        let isActive = isHovering || isPressed
        needsDisplay = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            imageView.animator().frame = iconFrame(hovered: isActive)
        }
    }

    private func performRefreshAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1, 0.76, 1.16, 1]
        animation.keyTimes = [0, 0.22, 0.62, 1]
        animation.duration = 0.42
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer?.add(animation, forKey: "manualRefreshPulse")
    }

    private func buttonFrame(hovered: Bool) -> NSRect {
        let scale = DoodleMetrics.scale
        return NSRect(x: (hovered ? 4 : 6) * scale, y: (hovered ? 2 : 5) * scale, width: 46 * scale, height: 46 * scale)
    }

    private func iconFrame(hovered: Bool) -> NSRect {
        let scale = DoodleMetrics.scale
        return NSRect(x: (hovered ? 17 : 18) * scale, y: (hovered ? 15 : 18) * scale, width: 20 * scale, height: 20 * scale)
    }

    private var title: String {
        switch kind {
        case .hourly: "小时额度"
        case .weekly: "周额度"
        case .reset: "使用限额重置"
        }
    }
}

private final class DoodleExpandButton: NSView {
    private let toggled: () -> Void
    private var trackingArea: NSTrackingArea?
    private var isHovering = false {
        didSet { needsDisplay = true }
    }

    var isExpanded = false {
        didSet {
            setAccessibilityLabel(isExpanded ? "收起额度卡片" : "展开额度卡片")
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    init(toggled: @escaping () -> Void) {
        self.toggled = toggled
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("展开额度卡片")
        toolTip = "展开额度卡片"
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
    }

    override func mouseUp(with event: NSEvent) {
        toggled()
    }

    override func draw(_ dirtyRect: NSRect) {
        let scale = DoodleMetrics.scale
        let tape = NSBezierPath()
        tape.move(to: NSPoint(x: 2 * scale, y: 3 * scale))
        tape.line(to: NSPoint(x: bounds.maxX - 3 * scale, y: scale))
        tape.line(to: NSPoint(x: bounds.maxX - scale, y: bounds.maxY - 3 * scale))
        tape.line(to: NSPoint(x: scale, y: bounds.maxY - scale))
        tape.close()
        DoodlePalette.tape.withAlphaComponent(isHovering ? 1 : 0.9).setFill()
        tape.fill()
        NSColor.black.withAlphaComponent(isHovering ? 0.22 : 0.12).setStroke()
        tape.lineWidth = scale
        tape.stroke()

        let centerX = bounds.midX
        let centerY = bounds.midY + (isHovering ? -0.6 * scale : 0)
        let chevron = NSBezierPath()
        if isExpanded {
            chevron.move(to: NSPoint(x: centerX - 5 * scale, y: centerY + 2 * scale))
            chevron.line(to: NSPoint(x: centerX, y: centerY - 3 * scale))
            chevron.line(to: NSPoint(x: centerX + 5 * scale, y: centerY + 2 * scale))
        } else {
            chevron.move(to: NSPoint(x: centerX - 5 * scale, y: centerY - 2 * scale))
            chevron.line(to: NSPoint(x: centerX, y: centerY + 3 * scale))
            chevron.line(to: NSPoint(x: centerX + 5 * scale, y: centerY - 2 * scale))
        }
        DoodlePalette.ink.setStroke()
        chevron.lineWidth = 2.1 * scale
        chevron.lineCapStyle = .round
        chevron.lineJoinStyle = .round
        chevron.stroke()
    }
}

private final class DoodleSummaryBadge: NSView {
    private let label = NSTextField(labelWithString: "")

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let scale = DoodleMetrics.scale
        label.font = NSFont(name: "ChalkboardSE-Bold", size: 11.5 * scale) ?? .systemFont(ofSize: 11.5 * scale, weight: .semibold)
        label.textColor = DoodlePalette.ink
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        label.cell?.wraps = false
        label.frame = NSRect(x: 13 * scale, y: 5 * scale, width: max(0, bounds.width - 26 * scale), height: 28 * scale)
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let scale = DoodleMetrics.scale
        label.frame = NSRect(x: 13 * scale, y: 5 * scale, width: max(0, bounds.width - 26 * scale), height: 28 * scale)
    }

    func configure(title: String, subtitle: String) {
        let titleText = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont(name: "ChalkboardSE-Bold", size: 11.5 * DoodleMetrics.scale) ?? .systemFont(ofSize: 11.5 * DoodleMetrics.scale, weight: .semibold),
                .foregroundColor: DoodlePalette.ink
            ]
        )
        let subtitleText = NSAttributedString(
            string: "\n" + subtitle,
            attributes: [
                .font: NSFont(name: "ChalkboardSE", size: 10 * DoodleMetrics.scale) ?? .systemFont(ofSize: 10 * DoodleMetrics.scale, weight: .medium),
                .foregroundColor: DoodlePalette.ink.withAlphaComponent(0.76)
            ]
        )
        let combined = NSMutableAttributedString(attributedString: titleText)
        combined.append(subtitleText)
        label.attributedStringValue = combined
    }

    override func draw(_ dirtyRect: NSRect) {
        let scale = DoodleMetrics.scale
        let badge = NSBezierPath()
        badge.move(to: NSPoint(x: 2 * scale, y: 3 * scale))
        badge.line(to: NSPoint(x: bounds.maxX - 3 * scale, y: scale))
        badge.line(to: NSPoint(x: bounds.maxX - scale, y: bounds.maxY - 4 * scale))
        badge.line(to: NSPoint(x: 3 * scale, y: bounds.maxY - scale))
        badge.close()

        let shadow = badge.copy() as! NSBezierPath
        shadow.transform(using: AffineTransform(translationByX: 2 * scale, byY: 2 * scale))
        DoodlePalette.ink.setFill()
        shadow.fill()
        DoodlePalette.mint.setFill()
        badge.fill()
        DoodlePalette.ink.setStroke()
        badge.lineWidth = 1.8 * scale
        badge.lineJoinStyle = .round
        badge.stroke()
    }
}

private final class DoodleWidgetView: NSView {
    private let store: UsageStore
    private let detailChanged: (HoverDetail?, QuotaDetailKind?) -> Void
    private let contentHeightChanged: (CGFloat) -> Void
    private var paper: DoodlePaperView!
    private var expandButton: DoodleExpandButton!
    private let hourlySummary = DoodleSummaryBadge(frame: .zero)
    private let weeklySummary = DoodleSummaryBadge(frame: .zero)
    private let resetSummary = DoodleSummaryBadge(frame: .zero)
    private var clockTimer: Timer?
    private var syncTimer: Timer?
    private var visibleDetail: QuotaDetailKind?
    private var isExpanded = false
    private var iconButtons: [DoodleIconButton] = []

    override var isFlipped: Bool { true }

    fileprivate init(
        store: UsageStore,
        detailChanged: @escaping (HoverDetail?, QuotaDetailKind?) -> Void,
        contentHeightChanged: @escaping (CGFloat) -> Void
    ) {
        self.store = store
        self.detailChanged = detailChanged
        self.contentHeightChanged = contentHeightChanged
        super.init(frame: NSRect(origin: .zero, size: DoodleMetrics.compactDisplaySize))
        autoresizingMask = [.width, .height]

        paper = DoodlePaperView(frame: bounds)
        paper.autoresizingMask = [.width, .height]
        addSubview(paper)

        for summary in [hourlySummary, weeklySummary, resetSummary] {
            summary.isHidden = true
            summary.alphaValue = 0
            addSubview(summary)
        }

        expandButton = DoodleExpandButton { [weak self] in
            self?.toggleExpansion()
        }
        expandButton.frame = NSRect(x: 105 * DoodleMetrics.scale, y: 0, width: 70 * DoodleMetrics.scale, height: 18 * DoodleMetrics.scale)
        addSubview(expandButton)

        let hourly = DoodleIconButton(
            kind: .hourly,
            accent: DoodlePalette.lavender,
            hoverChanged: { [weak self] kind, hovering in
                self?.updateHover(kind: kind, isHovering: hovering)
            },
            clicked: { [weak self] in self?.requestManualRefresh() }
        )
        hourly.frame = NSRect(x: 42 * DoodleMetrics.scale, y: 48 * DoodleMetrics.scale, width: 58 * DoodleMetrics.scale, height: 54 * DoodleMetrics.scale)
        addSubview(hourly)

        let weekly = DoodleIconButton(
            kind: .weekly,
            accent: DoodlePalette.coral,
            hoverChanged: { [weak self] kind, hovering in
                self?.updateHover(kind: kind, isHovering: hovering)
            },
            clicked: { [weak self] in self?.requestManualRefresh() }
        )
        weekly.frame = NSRect(x: 111 * DoodleMetrics.scale, y: 48 * DoodleMetrics.scale, width: 58 * DoodleMetrics.scale, height: 54 * DoodleMetrics.scale)
        addSubview(weekly)

        let reset = DoodleIconButton(
            kind: .reset,
            accent: DoodlePalette.mint,
            hoverChanged: { [weak self] kind, hovering in
                self?.updateHover(kind: kind, isHovering: hovering)
            },
            clicked: { [weak self] in self?.requestManualRefresh() }
        )
        reset.frame = NSRect(x: 180 * DoodleMetrics.scale, y: 48 * DoodleMetrics.scale, width: 58 * DoodleMetrics.scale, height: 54 * DoodleMetrics.scale)
        addSubview(reset)
        iconButtons = [hourly, weekly, reset]

        store.onChange = { [weak self] in self?.refresh() }
        syncCodexUsage()
        clockTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        syncTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(syncCodexUsage), userInfo: nil, repeats: true)
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        clockTimer?.invalidate()
        syncTimer?.invalidate()
    }

    override func layout() {
        super.layout()
        paper?.frame = bounds
        let scale = DoodleMetrics.scale
        hourlySummary.frame = NSRect(x: 20 * scale, y: 127 * scale, width: bounds.width - 40 * scale, height: 36 * scale)
        weeklySummary.frame = NSRect(x: 20 * scale, y: 171 * scale, width: bounds.width - 40 * scale, height: 36 * scale)
        resetSummary.frame = NSRect(x: 20 * scale, y: 215 * scale, width: bounds.width - 40 * scale, height: 36 * scale)
        expandButton?.frame = NSRect(x: bounds.midX - 35 * scale, y: 0, width: 70 * scale, height: 18 * scale)
        iconButtons.forEach { $0.refreshHoverTracking() }
    }

    @objc private func refresh() {
        if isExpanded {
            refreshSummaries()
        }
        if let visibleDetail {
            detailChanged(detail(for: visibleDetail), visibleDetail)
        }
    }

    @objc private func syncCodexUsage() {
        guard store.automaticallySyncs else { return }
        _ = store.syncFromCodexSessions()
    }

    private func requestManualRefresh() {
        guard store.automaticallySyncs else { return }
        _ = store.syncFromCodexSessions(force: true)
    }

    private func updateHover(kind: QuotaDetailKind, isHovering: Bool) {
        guard !isExpanded else {
            visibleDetail = nil
            detailChanged(nil, nil)
            return
        }
        if isHovering {
            visibleDetail = kind
            detailChanged(detail(for: kind), kind)
        } else if visibleDetail == kind {
            visibleDetail = nil
            detailChanged(nil, nil)
        }
    }

    private func toggleExpansion() {
        isExpanded.toggle()
        expandButton.isExpanded = isExpanded
        expandButton.toolTip = isExpanded ? "收起额度卡片" : "展开额度卡片"

        if isExpanded {
            visibleDetail = nil
            detailChanged(nil, nil)
            refreshSummaries()
            for summary in [hourlySummary, weeklySummary, resetSummary] {
                summary.isHidden = false
                summary.alphaValue = 0
            }
        }

        let logicalHeight: CGFloat = isExpanded ? 270 : DoodleMetrics.compactLogicalHeight
        contentHeightChanged(DoodleMetrics.displaySize(logicalHeight: logicalHeight).height)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            if isExpanded {
                for summary in [hourlySummary, weeklySummary, resetSummary] {
                    summary.animator().alphaValue = 1
                }
            } else {
                for summary in [hourlySummary, weeklySummary, resetSummary] {
                    summary.animator().alphaValue = 0
                }
            }
        } completionHandler: { [weak self] in
            guard let self, !self.isExpanded else { return }
            for summary in [self.hourlySummary, self.weeklySummary, self.resetSummary] {
                summary.isHidden = true
            }
        }
    }

    private func refreshSummaries() {
        configure(hourlySummary, with: detail(for: .hourly))
        configure(weeklySummary, with: detail(for: .weekly))
        configure(resetSummary, with: detail(for: .reset))
    }

    private func configure(_ summary: DoodleSummaryBadge, with detail: HoverDetail) {
        summary.configure(title: detail.title + " · " + detail.trailingText, subtitle: detail.resetText)
    }

    private func detail(for kind: QuotaDetailKind) -> HoverDetail {
        switch kind {
        case .hourly:
            return HoverDetail(title: "5 小时使用限制", resetText: usageResetText(for: store.resetDate), usedPercent: store.usedPercent, trailingText: String(format: "剩余 %d%%", 100 - store.usedPercent))
        case .weekly:
            let resetDate = store.secondaryResetDate ?? store.resetDate
            let usedPercent = store.secondaryUsedPercent
            return HoverDetail(title: "周使用限制", resetText: usageResetText(for: resetDate), usedPercent: usedPercent, trailingText: usedPercent.map { String(format: "剩余 %d%%", 100 - $0) } ?? "等待同步")
        case .reset:
            return resetDetail()
        }
    }

    private func usageResetText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "将于 HH:mm 重置" : "将于 M月d日 HH:mm 重置"
        return formatter.string(from: date)
    }

    private func resetDetail() -> HoverDetail {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        let availableCount = store.effectiveResetCreditCount
        let dates = store.effectiveResetExpirationDates.prefix(availableCount).map(formatter.string)
        let expiry: String
        if dates.isEmpty, store.hasAutomaticallySyncedResetCredits {
            expiry = "已自动同步 · 到期时间未提供"
        } else {
            expiry = dates.isEmpty ? "到期时间待设置" : "到期：" + dates.joined(separator: " · ")
        }
        return HoverDetail(title: "使用限额重置", resetText: expiry, usedPercent: nil, trailingText: availableCount > 0 ? String(format: "可用 %d 次", availableCount) : "暂无可用")
    }
}

private final class DoodleQuotaCard: NSView {
    private let textLabel = NSTextField(labelWithString: "")

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let scale = DoodleMetrics.scale
        textLabel.font = NSFont(name: "ChalkboardSE-Bold", size: 15 * scale) ?? .systemFont(ofSize: 15 * scale, weight: .bold)
        textLabel.textColor = DoodlePalette.ink
        textLabel.alignment = .center
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 2
        textLabel.cell?.wraps = true
        textLabel.frame = NSRect(x: 30 * scale, y: 39 * scale, width: 300 * scale, height: 44 * scale)
        addSubview(textLabel)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let scale = DoodleMetrics.scale
        let paper = DoodleDrawing.paperPath(in: bounds.insetBy(dx: 2 * scale, dy: 4 * scale))
        let shadow = paper.copy() as! NSBezierPath
        var transform = AffineTransform(translationByX: 6 * scale, byY: 7 * scale)
        shadow.transform(using: transform)
        DoodlePalette.ink.setFill()
        shadow.fill()
        DoodlePalette.paper.setFill()
        paper.fill()
        DoodlePalette.ink.setStroke()
        paper.lineWidth = 3 * scale
        paper.stroke()

        let badge = NSBezierPath()
        badge.move(to: NSPoint(x: 22 * scale, y: 31 * scale))
        badge.line(to: NSPoint(x: 339 * scale, y: 26 * scale))
        badge.line(to: NSPoint(x: 336 * scale, y: 88 * scale))
        badge.line(to: NSPoint(x: 24 * scale, y: 92 * scale))
        badge.close()
        let badgeShadow = badge.copy() as! NSBezierPath
        transform = AffineTransform(translationByX: 3 * scale, byY: 3 * scale)
        badgeShadow.transform(using: transform)
        DoodlePalette.ink.setFill()
        badgeShadow.fill()
        DoodlePalette.mint.setFill()
        badge.fill()
        DoodlePalette.ink.setStroke()
        badge.lineWidth = 2.2 * scale
        badge.stroke()

        DoodleDrawing.drawTape(in: NSRect(x: bounds.midX - 31 * scale, y: 2 * scale, width: 62 * scale, height: 14 * scale))
    }

    func configure(with detail: HoverDetail) {
        textLabel.stringValue = detail.title + " · " + detail.trailingText + "\n" + detail.resetText
    }
}

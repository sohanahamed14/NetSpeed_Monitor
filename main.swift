import Cocoa
import Darwin

struct DayUsage: Codable {
    var rx: UInt64
    var tx: UInt64
}

struct HistoryData: Codable {
    var days: [String: DayUsage] = [:]
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?

    private var prevInterfaceBytes: [String: (ibytes: UInt32, obytes: UInt32)] = [:]
    private var isFirstRun = true
    private var lastTimestamp: TimeInterval = 0
    private var lastSaveTimestamp: TimeInterval = 0

    private var totalSessionIn: UInt64 = 0
    private var totalSessionOut: UInt64 = 0

    // History tracking
    private var history = HistoryData()
    private let historyFileURL: URL = {
        let appDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".netspeed")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("history.json")
    }()
    private let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    // Static menu item references
    private var rateMenuItem: NSMenuItem!
    private var sessionMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadHistory()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageLeading

        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        rebuildMenu()

        lastTimestamp = Date().timeIntervalSinceReferenceDate
        lastSaveTimestamp = lastTimestamp
        updateSpeed()

        // High-frequency 0.2s (200ms) timer for zero-delay real-time responsiveness
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updateSpeed()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveHistory()
    }

    @objc private func quit() {
        saveHistory()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Menu Construction

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        // 1. Current rates
        rateMenuItem = NSMenuItem(title: "Download: 0.0 MB/s  |  Upload: 0.0 MB/s", action: nil, keyEquivalent: "")
        rateMenuItem.isEnabled = false
        menu.addItem(rateMenuItem)

        // 2. Session totals
        sessionMenuItem = NSMenuItem(title: "Session: ↓ \(formatDataSize(totalSessionIn))  ↑ \(formatDataSize(totalSessionOut))", action: nil, keyEquivalent: "")
        sessionMenuItem.isEnabled = false
        menu.addItem(sessionMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Last 7 Days History (sorted chronologically)
        let sortedKeys = history.days.keys.sorted()
        let last7Keys = sortedKeys.suffix(7)

        for key in last7Keys {
            guard let usage = history.days[key] else { continue }
            let date = keyFormatter.date(from: key) ?? Date()
            let dateStr = displayDateFormatter.string(from: date).uppercased()
            let rxStr = formatDataSize(usage.rx)
            let txStr = formatDataSize(usage.tx)

            let item = NSMenuItem(title: "\(dateStr)\t↓ \(rxStr)  ↑ \(txStr)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // 4. Summaries: Last 7 days and Last 30 days
        let calendar = Calendar.current
        let now = Date()
        let cutoff7 = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now
        let cutoff30 = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now)) ?? now

        var sum7Rx: UInt64 = 0
        var sum7Tx: UInt64 = 0
        var sum30Rx: UInt64 = 0
        var sum30Tx: UInt64 = 0

        for (k, usage) in history.days {
            if let d = keyFormatter.date(from: k) {
                if d >= cutoff7 {
                    sum7Rx += usage.rx
                    sum7Tx += usage.tx
                }
                if d >= cutoff30 {
                    sum30Rx += usage.rx
                    sum30Tx += usage.tx
                }
            }
        }

        let item7 = NSMenuItem(title: "Last 7 days\t↓ \(formatDataSize(sum7Rx))  ↑ \(formatDataSize(sum7Tx))", action: nil, keyEquivalent: "")
        item7.isEnabled = false
        menu.addItem(item7)

        let item30 = NSMenuItem(title: "Last 30 days\t↓ \(formatDataSize(sum30Rx))  ↑ \(formatDataSize(sum30Tx))", action: nil, keyEquivalent: "")
        item30.isEnabled = false
        menu.addItem(item30)

        menu.addItem(NSMenuItem.separator())

        // 5. Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - History Persistence

    private func loadHistory() {
        if let data = try? Data(contentsOf: historyFileURL),
           let loaded = try? JSONDecoder().decode(HistoryData.self, from: data) {
            history = loaded
        }
        let todayKey = keyFormatter.string(from: Date())
        if history.days[todayKey] == nil {
            history.days[todayKey] = DayUsage(rx: 0, tx: 0)
        }
    }

    private func saveHistory() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(history) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }

    private func recordUsage(rx: UInt64, tx: UInt64, now: TimeInterval) {
        let todayKey = keyFormatter.string(from: Date())
        var current = history.days[todayKey] ?? DayUsage(rx: 0, tx: 0)
        current.rx += rx
        current.tx += tx
        history.days[todayKey] = current

        if now - lastSaveTimestamp >= 10.0 { // Autosave to disk every 10 seconds
            lastSaveTimestamp = now
            saveHistory()
        }
    }

    // MARK: - Speed and Network Stats

    private func getInterfaceStats() -> [String: (ibytes: UInt32, obytes: UInt32)] {
        var stats: [String: (ibytes: UInt32, obytes: UInt32)] = [:]
        var ifap: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifap) == 0, let first = ifap else { return stats }
        defer { freeifaddrs(ifap) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }

            if let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK), let data = ptr.pointee.ifa_data {
                let name = String(cString: ptr.pointee.ifa_name)
                let networkData = data.assumingMemoryBound(to: if_data.self)
                stats[name] = (networkData.pointee.ifi_ibytes, networkData.pointee.ifi_obytes)
            }
        }
        return stats
    }

    private func delta(current: UInt32, previous: UInt32) -> UInt64 {
        if current >= previous {
            return UInt64(current - previous)
        } else {
            return UInt64(UInt64(UInt32.max) - UInt64(previous) + UInt64(current) + 1)
        }
    }

    private func drawSpeedometer(speedMB: Double, size: NSSize = NSSize(width: 18, height: 18)) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY - 1.5)
            let radius: CGFloat = 6.8

            let startAngle = CGFloat(215.0 * .pi / 180.0)
            let endAngle = CGFloat(-35.0 * .pi / 180.0)
            let totalSweep = CGFloat(250.0 * .pi / 180.0)

            // Outer bezel arc
            ctx.setLineWidth(1.4)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.35).cgColor)
            ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            ctx.strokePath()

            // Tick marks
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.6).cgColor)
            ctx.setLineWidth(1.0)
            for i in 0...4 {
                let fraction = CGFloat(i) / 4.0
                let tickAngle = startAngle - (fraction * totalSweep)
                let innerR: CGFloat = radius - 1.5
                let outerR: CGFloat = radius
                let p1 = CGPoint(x: center.x + innerR * cos(tickAngle), y: center.y + innerR * sin(tickAngle))
                let p2 = CGPoint(x: center.x + outerR * cos(tickAngle), y: center.y + outerR * sin(tickAngle))
                ctx.move(to: p1)
                ctx.addLine(to: p2)
            }
            ctx.strokePath()

            // Dynamic needle angle based on instantaneous speed
            let clampedSpeed = min(max(speedMB, 0.0), 30.0)
            let progress = CGFloat(sqrt(clampedSpeed / 30.0))
            let needleAngle = startAngle - (progress * totalSweep)

            // Center pivot hub
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - 1.8, y: center.y - 1.8, width: 3.6, height: 3.6))

            // Needle
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            let needleLength: CGFloat = 5.6
            let needleEnd = CGPoint(
                x: center.x + needleLength * cos(needleAngle),
                y: center.y + needleLength * sin(needleAngle)
            )
            ctx.move(to: center)
            ctx.addLine(to: needleEnd)
            ctx.strokePath()

            return true
        }
        img.isTemplate = true
        return img
    }

    private func formatDataSize(_ bytes: UInt64) -> String {
        let tb = Double(bytes) / (1024.0 * 1024.0 * 1024.0 * 1024.0)
        let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        let mb = Double(bytes) / (1024.0 * 1024.0)
        let kb = Double(bytes) / 1024.0

        if tb >= 1.0 {
            return String(format: "%.1f TB", tb)
        } else if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.0f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }

    private func updateSpeed() {
        let now = Date().timeIntervalSinceReferenceDate
        let dt = now - lastTimestamp
        guard dt > 0.05 else { return }

        let currentStats = getInterfaceStats()

        if isFirstRun {
            prevInterfaceBytes = currentStats
            lastTimestamp = now
            isFirstRun = false
            updateDisplay(downloadMB: 0.0)
            return
        }

        lastTimestamp = now

        var deltaIn: UInt64 = 0
        var deltaOut: UInt64 = 0

        for (name, current) in currentStats {
            if let prev = prevInterfaceBytes[name] {
                deltaIn += delta(current: current.ibytes, previous: prev.ibytes)
                deltaOut += delta(current: current.obytes, previous: prev.obytes)
            }
        }

        prevInterfaceBytes = currentStats
        totalSessionIn += deltaIn
        totalSessionOut += deltaOut
        recordUsage(rx: deltaIn, tx: deltaOut, now: now)

        // Exact real-time rate: (bytes / dt) converted to MB/s
        let downloadSpeedMB = (Double(deltaIn) / dt) / (1024.0 * 1024.0)
        let uploadSpeedMB = (Double(deltaOut) / dt) / (1024.0 * 1024.0)

        updateDisplay(downloadMB: downloadSpeedMB)

        rateMenuItem?.title = String(format: "Download: %.1f MB/s  |  Upload: %.1f MB/s", downloadSpeedMB, uploadSpeedMB)
        sessionMenuItem?.title = "Session: ↓ \(formatDataSize(totalSessionIn))  ↑ \(formatDataSize(totalSessionOut))"
    }

    private func updateDisplay(downloadMB: Double) {
        guard let button = statusItem?.button else { return }

        // Dynamic speedometer gauge icon to the left of the speed
        button.image = drawSpeedometer(speedMB: downloadMB)
        button.imagePosition = .imageLeading

        // Real-time instantaneous speed in MB/s
        let text = String(format: "%.1f MB/s", downloadMB)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        button.attributedTitle = NSAttributedString(string: text, attributes: [.font: font])
    }
}

if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") || CommandLine.arguments.contains("--version") {
    print("NetSpeed Menu Bar Monitor v1.0")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

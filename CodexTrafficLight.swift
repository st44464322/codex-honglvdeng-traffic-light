import Cocoa
import Foundation

let appDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let supportDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/CodexTrafficLight")
let stateFile = supportDir.appendingPathComponent("state.json")
let preferencesFile = supportDir.appendingPathComponent("preferences.json")

let labels: [String: String] = [
    "working": "正在干活",
    "done": "可以验收",
    "waiting": "等你回复",
    "idle": "空闲"
]

let order = ["working", "done", "waiting", "idle"]
let designWidth: CGFloat = 198
let designHeight: CGFloat = 522
let uiScale: CGFloat = 7.0 / 12.0
let scaledWidth = designWidth * uiScale
let scaledHeight = designHeight * uiScale

final class SoundController {
    private let sounds: [String: NSSound?] = [
        "working": NSSound(named: NSSound.Name("Tink")),
        "done": NSSound(named: NSSound.Name("Glass")),
        "waiting": NSSound(named: NSSound.Name("Basso"))
    ]
    private var redTimer: Timer?
    private var greenStopTimer: Timer?
    private(set) var muted = readMutedPreference()

    func apply(state: String, playPrompt: Bool) {
        if muted {
            stopGreenSound()
            stopRedLoop()
            return
        }
        if state != "done" {
            stopGreenSound()
        }
        if state == "waiting" {
            startRedAlert(playImmediately: playPrompt)
            return
        }

        stopRedLoop()
        if playPrompt {
            if state == "done" {
                playGreenForThreeSeconds()
            } else {
                playOnce(state)
            }
        }
    }

    func setMuted(_ nextMuted: Bool) {
        muted = nextMuted
        writeMutedPreference(nextMuted)
        if nextMuted {
            stopGreenSound()
            stopRedLoop()
        }
    }

    private func playOnce(_ state: String) {
        if muted { return }
        guard let sound = sounds[state] ?? nil else { return }
        if sound.isPlaying {
            sound.stop()
            sound.currentTime = 0
        }
        sound.play()
    }

    private func playGreenForThreeSeconds() {
        guard let sound = sounds["done"] ?? nil else { return }
        greenStopTimer?.invalidate()
        if sound.isPlaying {
            sound.stop()
            sound.currentTime = 0
        }
        sound.loops = true
        sound.play()
        greenStopTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.stopGreenSound()
        }
    }

    private func stopGreenSound() {
        greenStopTimer?.invalidate()
        greenStopTimer = nil
        if let greenSound = sounds["done"] ?? nil {
            greenSound.loops = false
            if greenSound.isPlaying {
                greenSound.stop()
                greenSound.currentTime = 0
            }
        }
    }

    private func startRedAlert(playImmediately: Bool) {
        redTimer?.invalidate()
        redTimer = nil
        if playImmediately {
            playOnce("waiting")
        }
        redTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.stopRedLoop()
        }
    }

    func stopRedLoop() {
        redTimer?.invalidate()
        redTimer = nil
        if let redSound = sounds["waiting"] ?? nil, redSound.isPlaying {
            redSound.stop()
            redSound.currentTime = 0
        }
    }
}

func ensureRuntime() {
    try? FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
}

func writeState(_ state: String) {
    ensureRuntime()
    let body: [String: Any] = ["state": state, "updated_at": Date().timeIntervalSince1970]
    if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]) {
        try? data.write(to: stateFile)
    }
}

func readMutedPreference() -> Bool {
    guard let data = try? Data(contentsOf: preferencesFile),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let muted = object["muted"] as? Bool else {
        return false
    }
    return muted
}

func writeMutedPreference(_ muted: Bool) {
    ensureRuntime()
    let body: [String: Any] = ["muted": muted, "updated_at": Date().timeIntervalSince1970]
    if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]) {
        try? data.write(to: preferencesFile)
    }
}

func readState() -> String {
    guard let data = try? Data(contentsOf: stateFile),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let state = object["state"] as? String else {
        return "idle"
    }
    return labels.keys.contains(state) || state == "quit" ? state : "idle"
}

final class TrafficLightView: NSView {
    var state = readState()
    var blinkOn = true
    var waitingAlertActive = false
    var isMuted = readMutedPreference()
    var dragStart: NSPoint?
    var onStateCommand: ((String) -> Void)?
    var onMuteToggle: (() -> Void)?
    weak var ownerWindow: NSWindow?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.clear.setFill()
        dirtyRect.fill()

        NSGraphicsContext.saveGraphicsState()
        let scale = NSAffineTransform()
        scale.scale(by: uiScale)
        scale.concat()

        let body = NSRect(x: 22, y: 18, width: 154, height: 486)
        drawRoundedGradient(
            body,
            radius: 28,
            top: NSColor(hex: "#343433"),
            bottom: NSColor(hex: "#1e1f1e"),
            stroke: NSColor.white.withAlphaComponent(0.16),
            width: 1
        )

        drawRounded(
            body.insetBy(dx: 5, dy: 5),
            radius: 24,
            fill: NSColor.clear,
            stroke: NSColor.black.withAlphaComponent(0.34),
            width: 2
        )

        NSColor.white.withAlphaComponent(0.07).setStroke()
        let topHighlight = NSBezierPath()
        topHighlight.move(to: NSPoint(x: body.minX + 24, y: body.maxY - 2))
        topHighlight.line(to: NSPoint(x: body.maxX - 24, y: body.maxY - 2))
        topHighlight.lineWidth = 1
        topHighlight.stroke()

        drawTopText("Codex", rect: NSRect(x: 0, y: 459, width: designWidth, height: 32), size: 20, weight: .medium)
        drawCloseButton()

        NSColor.white.withAlphaComponent(0.09).setStroke()
        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: body.minX + 18, y: 86))
        separator.line(to: NSPoint(x: body.maxX - 18, y: 86))
        separator.lineWidth = 1
        separator.stroke()

        drawLens(center: NSPoint(x: 99, y: 405), light: "red", isActive: isLightVisible("red"))
        drawLens(center: NSPoint(x: 99, y: 292), light: "yellow", isActive: isLightVisible("yellow"))
        drawLens(center: NSPoint(x: 99, y: 179), light: "green", isActive: isLightVisible("green"))

        let label = labels[state] ?? "空闲"
        drawBottomText(label, rect: NSRect(x: 18, y: 38, width: designWidth - 36, height: 36))
        drawMuteButton()

        NSGraphicsContext.restoreGraphicsState()
    }

    func activeLight() -> String {
        switch state {
        case "working": return "yellow"
        case "done": return "green"
        case "waiting": return "red"
        default: return ""
        }
    }

    func isBlinkingState() -> Bool {
        return state == "waiting" && waitingAlertActive
    }

    func isLightVisible(_ light: String) -> Bool {
        guard activeLight() == light else { return false }
        return isBlinkingState() ? blinkOn : true
    }

    func baseColorFor(_ light: String) -> NSColor {
        switch light {
        case "red": return NSColor(hex: "#f3423b")
        case "yellow": return NSColor(hex: "#ffd441")
        case "green": return NSColor(hex: "#55d34d")
        default: return NSColor(hex: "#ffffff")
        }
    }

    func drawRounded(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor, width: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        fill.setFill()
        path.fill()
        stroke.setStroke()
        path.lineWidth = width
        path.stroke()
    }

    func drawRoundedGradient(_ rect: NSRect, radius: CGFloat, top: NSColor, bottom: NSColor, stroke: NSColor, width: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSGradient(starting: bottom, ending: top)?.draw(in: rect, angle: 90)
        NSGraphicsContext.restoreGraphicsState()
        stroke.setStroke()
        path.lineWidth = width
        path.stroke()
    }

    func drawLens(center: NSPoint, light: String, isActive: Bool) {
        let color = baseColorFor(light)
        let isIdle = state == "idle"
        let glowAlpha: CGFloat = isIdle ? 0.03 : (isActive ? 0.34 : 0.11)
        let haloAlpha: CGFloat = isIdle ? 0.02 : (isActive ? 0.15 : 0.04)
        let fillAlpha: CGFloat = isIdle ? 0.26 : (isActive ? 1.0 : 0.52)
        let rimAlpha: CGFloat = isIdle ? 0.08 : (isActive ? 0.38 : 0.16)

        color.withAlphaComponent(glowAlpha).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 52, y: center.y - 52, width: 104, height: 104)).fill()
        color.withAlphaComponent(haloAlpha).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 59, y: center.y - 59, width: 118, height: 118)).fill()

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = NSSize(width: 0, height: -3)

        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        color.withAlphaComponent(fillAlpha).setFill()
        let bulb = NSBezierPath(ovalIn: NSRect(x: center.x - 38, y: center.y - 38, width: 76, height: 76))
        bulb.fill()
        NSGraphicsContext.restoreGraphicsState()

        let rim = NSBezierPath(ovalIn: NSRect(x: center.x - 43, y: center.y - 43, width: 86, height: 86))
        color.withAlphaComponent(rimAlpha).setStroke()
        rim.lineWidth = 7
        rim.stroke()

        NSColor.black.withAlphaComponent(0.22).setStroke()
        bulb.lineWidth = 2
        bulb.stroke()

        NSColor.black.withAlphaComponent(isActive ? 0.13 : 0.18).setStroke()
        let inner = NSBezierPath(ovalIn: NSRect(x: center.x - 31, y: center.y - 31, width: 62, height: 62))
        inner.lineWidth = 1
        inner.stroke()

        NSColor.white.withAlphaComponent(isIdle ? 0.04 : (isActive ? 0.24 : 0.10)).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 17, y: center.y + 15, width: 28, height: 11)).fill()
    }

    func closeButtonRect() -> NSRect {
        return NSRect(x: designWidth - 45, y: designHeight - 47, width: 20, height: 20)
    }

    func muteButtonRect() -> NSRect {
        return NSRect(x: 39, y: 46, width: 15, height: 15)
    }

    func drawMuteButton() {
        let rect = muteButtonRect()
        let circle = NSBezierPath(ovalIn: rect)
        NSColor.white.withAlphaComponent(isMuted ? 0.20 : 0.08).setFill()
        circle.fill()

        NSColor.white.withAlphaComponent(isMuted ? 0.34 : 0.13).setStroke()
        circle.lineWidth = 1
        circle.stroke()

        if isMuted {
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: rect.minX + 4, y: rect.minY + 4))
            slash.line(to: NSPoint(x: rect.maxX - 4, y: rect.maxY - 4))
            slash.lineWidth = 1.4
            slash.lineCapStyle = .round
            slash.stroke()
        }
    }

    func drawCloseButton() {
        let rect = closeButtonRect()
        let circle = NSBezierPath(ovalIn: rect)
        NSColor.white.withAlphaComponent(0.12).setFill()
        circle.fill()
        NSColor.white.withAlphaComponent(0.16).setStroke()
        circle.lineWidth = 1
        circle.stroke()

        NSColor.white.withAlphaComponent(0.34).setStroke()
        let xPath = NSBezierPath()
        xPath.move(to: NSPoint(x: rect.minX + 8, y: rect.minY + 8))
        xPath.line(to: NSPoint(x: rect.maxX - 8, y: rect.maxY - 8))
        xPath.move(to: NSPoint(x: rect.maxX - 8, y: rect.minY + 8))
        xPath.line(to: NSPoint(x: rect.minX + 8, y: rect.maxY - 8))
        xPath.lineWidth = 2
        xPath.lineCapStyle = .round
        xPath.stroke()
    }

    func drawTopText(_ text: String, rect: NSRect, size: CGFloat, weight: NSFont.Weight) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.44),
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .paragraphStyle: style
        ]
        text.draw(in: rect, withAttributes: attrs)
    }

    func drawBottomText(_ text: String, rect: NSRect) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.60),
            .font: NSFont.systemFont(ofSize: 22, weight: .regular),
            .paragraphStyle: style
        ]
        text.draw(in: rect, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        let point = designPoint(from: event.locationInWindow)
        if muteButtonRect().contains(point) {
            onMuteToggle?()
            return
        }
        if closeButtonRect().contains(point) {
            writeState("quit")
            NSApp.terminate(nil)
            return
        }
        if event.clickCount == 2 {
            cycleState()
            return
        }
        dragStart = event.locationInWindow
    }

    func designPoint(from point: NSPoint) -> NSPoint {
        return NSPoint(x: point.x / uiScale, y: point.y / uiScale)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = ownerWindow, let start = dragStart else { return }
        let current = event.locationInWindow
        let dx = current.x - start.x
        let dy = current.y - start.y
        var frame = window.frame
        frame.origin.x += dx
        frame.origin.y += dy
        window.setFrameOrigin(frame.origin)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: "黄灯：正在干活", action: #selector(AppDelegate.setWorking), keyEquivalent: "")
        menu.addItem(withTitle: "绿灯：完成验收", action: #selector(AppDelegate.setDone), keyEquivalent: "")
        menu.addItem(withTitle: "红灯：等你回复", action: #selector(AppDelegate.setWaiting), keyEquivalent: "")
        menu.addItem(withTitle: "空闲：都变暗", action: #selector(AppDelegate.setIdle), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(AppDelegate.quit), keyEquivalent: "")
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    func cycleState() {
        let index = order.firstIndex(of: state) ?? 0
        let next = order[(index + 1) % order.count]
        onStateCommand?(next)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var view: TrafficLightView!
    var lastModified = Date.distantPast
    var waitingBlinkStopTimer: Timer?
    let soundController = SoundController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureRuntime()
        if !FileManager.default.fileExists(atPath: stateFile.path) {
            writeState("idle")
        }
        if readState() == "quit" {
            writeState("idle")
        }

        view = TrafficLightView(frame: NSRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        window = NSWindow(contentRect: NSRect(x: 1280, y: 540, width: scaledWidth, height: scaledHeight), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .floating
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = view
        view.ownerWindow = window
        view.onStateCommand = { [weak self] state in
            self?.setState(state)
        }
        view.onMuteToggle = { [weak self] in
            self?.toggleMute()
        }
        window.makeKeyAndOrderFront(nil)
        soundController.apply(state: view.state, playPrompt: false)

        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.pollState() }
        Timer.scheduledTimer(withTimeInterval: 0.52, repeats: true) { [weak self] _ in self?.blink() }
    }

    func pollState() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: stateFile.path)
        let modified = attrs?[.modificationDate] as? Date ?? Date.distantPast
        guard modified != lastModified else { return }
        lastModified = modified
        let next = readState()
        if next == "quit" {
            soundController.stopRedLoop()
            NSApp.terminate(nil)
            return
        }
        if next != view.state || next == "waiting" {
            applyState(next, playPrompt: true, writeFile: false)
        }
    }

    func blink() {
        guard view.state == "waiting" && view.waitingAlertActive else {
            if !view.blinkOn {
                view.blinkOn = true
                view.needsDisplay = true
            }
            return
        }
        view.blinkOn.toggle()
        view.needsDisplay = true
    }

    @objc func setWorking() { setState("working") }
    @objc func setDone() { setState("done") }
    @objc func setWaiting() { setState("waiting") }
    @objc func setIdle() { setState("idle") }
    @objc func quit() { soundController.stopRedLoop(); writeState("quit"); NSApp.terminate(nil) }

    func setState(_ state: String) {
        applyState(state, playPrompt: true, writeFile: true)
    }

    func applyState(_ state: String, playPrompt: Bool, writeFile: Bool) {
        if writeFile {
            writeState(state)
        }
        view.state = state
        view.blinkOn = true
        if state == "waiting" {
            startWaitingBlinkTimer()
        } else {
            stopWaitingBlinkTimer()
        }
        view.needsDisplay = true
        soundController.apply(state: state, playPrompt: playPrompt)
    }

    func startWaitingBlinkTimer() {
        waitingBlinkStopTimer?.invalidate()
        view.waitingAlertActive = true
        waitingBlinkStopTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.view.waitingAlertActive = false
            self.view.blinkOn = true
            self.view.needsDisplay = true
        }
    }

    func stopWaitingBlinkTimer() {
        waitingBlinkStopTimer?.invalidate()
        waitingBlinkStopTimer = nil
        view.waitingAlertActive = false
    }

    func toggleMute() {
        let nextMuted = !soundController.muted
        soundController.setMuted(nextMuted)
        view.isMuted = nextMuted
        view.needsDisplay = true
        if !nextMuted {
            soundController.apply(state: view.state, playPrompt: false)
        }
    }
}

extension NSColor {
    convenience init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let red = CGFloat((value >> 16) & 0xff) / 255
        let green = CGFloat((value >> 8) & 0xff) / 255
        let blue = CGFloat(value & 0xff) / 255
        self.init(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

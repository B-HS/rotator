import AppKit
import CoreGraphics
import RotatorCore

private final class RotationRequest: NSObject {
    let displayID: CGDirectDisplayID
    let displayName: String
    let angle: RotationAngle

    init(displayID: CGDirectDisplayID, displayName: String, angle: RotationAngle) {
        self.displayID = displayID
        self.displayName = displayName
        self.angle = angle
    }
}

private func displayReconfigurationCallback(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo else { return }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async {
        delegate.rebuildMenu()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let displayManager = DisplayManager()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var rotationInProgress = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "rectangle.landscape.rotate", accessibilityDescription: "화면 회전") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "↻"
            }
            button.toolTip = "Rotator — 화면 회전"
        }

        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()

        CGDisplayRegisterReconfigurationCallback(
            displayReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        CGDisplayRemoveReconfigurationCallback(
            displayReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    func rebuildMenu() {
        menu.removeAllItems()

        do {
            let displays = try displayManager.onlineDisplays()
            if displays.isEmpty {
                let item = NSMenuItem(title: "연결된 디스플레이 없음", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                for display in displays {
                    menu.addItem(displayMenuItem(for: display))
                }
            }
        } catch {
            let item = NSMenuItem(title: error.localizedDescription, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let displaySettings = NSMenuItem(
            title: "디스플레이 설정 열기…",
            action: #selector(openDisplaySettings),
            keyEquivalent: ","
        )
        displaySettings.target = self
        menu.addItem(displaySettings)

        let quit = NSMenuItem(title: "Rotator 종료", action: #selector(quitApplication), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func displayMenuItem(for display: DisplayInfo) -> NSMenuItem {
        let suffix = display.isBuiltIn ? " · 내장" : ""
        let item = NSMenuItem(
            title: "\(display.name)\(suffix) — \(display.rotation.rawValue)°",
            action: nil,
            keyEquivalent: ""
        )

        let submenu = NSMenu(title: display.name)
        for angle in RotationAngle.allCases {
            let rotationItem = NSMenuItem(
                title: angle.title,
                action: #selector(rotateDisplay(_:)),
                keyEquivalent: ""
            )
            rotationItem.target = self
            rotationItem.representedObject = RotationRequest(
                displayID: display.id,
                displayName: display.name,
                angle: angle
            )
            rotationItem.state = display.rotation == angle ? .on : .off
            rotationItem.isEnabled = !rotationInProgress
            submenu.addItem(rotationItem)
        }
        item.submenu = submenu
        return item
    }

    @objc private func rotateDisplay(_ sender: NSMenuItem) {
        guard !rotationInProgress, let request = sender.representedObject as? RotationRequest else { return }

        let previousAngle = displayManager.currentRotation(of: request.displayID)
        guard previousAngle != request.angle else { return }

        rotationInProgress = true
        defer {
            rotationInProgress = false
            rebuildMenu()
        }

        do {
            try displayManager.setRotation(request.angle, for: request.displayID)
            guard waitForRotation(request.angle, displayID: request.displayID) else {
                try? displayManager.setRotation(previousAngle, for: request.displayID)
                throw DisplayRotationError.changeNotObserved
            }

            let confirmation = RotationConfirmation()
            let shouldKeep = confirmation.ask(displayName: request.displayName, angle: request.angle)
            if !shouldKeep {
                try displayManager.setRotation(previousAngle, for: request.displayID)
                guard waitForRotation(previousAngle, displayID: request.displayID) else {
                    throw DisplayRotationError.changeNotObserved
                }
            }
        } catch {
            presentError(error, displayName: request.displayName)
        }
    }

    private func waitForRotation(
        _ expectedAngle: RotationAngle,
        displayID: CGDirectDisplayID,
        timeout: TimeInterval = 10
    ) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        repeat {
            if displayManager.currentRotation(of: displayID) == expectedAngle {
                return true
            }
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        } while Date() < deadline

        return displayManager.currentRotation(of: displayID) == expectedAngle
    }

    private func presentError(_ error: Error, displayName: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "\(displayName)을(를) 회전하지 못했습니다"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "확인")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func openDisplaySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}

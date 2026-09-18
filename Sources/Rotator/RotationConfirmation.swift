import AppKit
import RotatorCore

@MainActor
final class RotationConfirmation: NSObject {
    private var timer: Timer?
    private var remainingSeconds = 10
    private var didTimeOut = false
    private weak var alert: NSAlert?
    private var displayName = ""
    private var angle = RotationAngle.normal

    func ask(displayName: String, angle: RotationAngle) -> Bool {
        let alert = NSAlert()
        self.alert = alert
        self.displayName = displayName
        self.angle = angle
        alert.alertStyle = .warning
        alert.messageText = "이 화면 설정을 유지할까요?"
        alert.informativeText = message(displayName: displayName, angle: angle)
        alert.addButton(withTitle: "유지")
        alert.addButton(withTitle: "되돌리기")

        NSApp.activate(ignoringOtherApps: true)
        timer = Timer(
            timeInterval: 1,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)

        let response = alert.runModal()
        timer?.invalidate()
        timer = nil
        self.alert = nil
        return !didTimeOut && response == .alertFirstButtonReturn
    }

    @objc private func tick() {
        remainingSeconds -= 1
        alert?.informativeText = message(displayName: displayName, angle: angle)
        if remainingSeconds <= 0 {
            didTimeOut = true
            timer?.invalidate()
            alert?.window.orderOut(nil)
            NSApp.abortModal()
        }
    }

    private func message(displayName: String, angle: RotationAngle) -> String {
        "\(displayName)을(를) \(angle.rawValue)°로 설정했습니다.\n\(remainingSeconds)초 안에 선택하지 않으면 이전 설정으로 돌아갑니다."
    }
}

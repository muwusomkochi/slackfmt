import AppKit
import UserNotifications

final class Notifications: NSObject, UNUserNotificationCenterDelegate {
    private(set) var isAlerting = false
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    /// Asks once, then posts if he allowed it (R33).
    func askThenPost(_ body: String) {
        center.requestAuthorization(options: [.alert]) { [self] allowed, _ in
            if allowed { post(body) }
        }
    }

    /// A notification, or an alert when notifications are off (R21).
    func postOrAlert(_ body: String) {
        center.getNotificationSettings { [self] settings in
            if settings.authorizationStatus == .authorized, settings.alertSetting == .enabled {
                post(body)
            } else {
                DispatchQueue.main.async { self.alert(body) }
            }
        }
    }

    private func post(_ body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Slackfmt"
        content.body = body
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func alert(_ body: String) {
        let alert = NSAlert()
        alert.messageText = "Slackfmt"
        alert.informativeText = body
        alert.addButton(withTitle: "OK")
        isAlerting = true
        defer { isAlerting = false }
        NSApp.activate()
        alert.runModal()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}

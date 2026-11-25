import ServiceManagement

enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
    }
}

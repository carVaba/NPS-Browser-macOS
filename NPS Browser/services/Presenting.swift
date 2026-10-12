import Cocoa

@MainActor
protocol AlertPresenting {
    func showAlert(messageText: String, informativeText: String, alertStyle: NSAlert.Style)
}

struct AppKitAlertPresenter: AlertPresenting {
    func showAlert(messageText: String, informativeText: String, alertStyle: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = alertStyle
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

@MainActor
protocol NotificationSending {
    func showNotification(title: String, subtitle: String)
}

@MainActor
protocol LoadingPresenting: AnyObject {
    var isShowing: Bool { get }
    func show()
    func setLabel(text: String)
    func setProgress(amount: Double)
    func close()
}

// Shows the loading controller as a sheet of the host view controller.
@MainActor
final class LoadingSheetPresenter: LoadingPresenting {
    private let controller = LoadingViewController()
    weak var host: NSViewController?

    var isShowing: Bool {
        return controller.presentingViewController != nil
    }

    func show() {
        host?.presentAsSheet(controller)
    }

    func setLabel(text: String) {
        controller.setLabel(text: text)
    }

    func setProgress(amount: Double) {
        controller.setProgress(amount: amount)
    }

    func close() {
        controller.closeWindow()
    }
}

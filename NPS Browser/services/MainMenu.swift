import Cocoa

@MainActor
enum MainMenu {
    static func make(appDelegate: AppDelegate, windowController: WindowController) -> NSMenu {
        let main = NSMenu()
        let appName = "NPS Browser"

        let app = submenu(of: main, title: appName)
        app.addItem(withTitle: "About NPS Browser".localized, action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        let preferences = app.addItem(withTitle: "Preferences…".localized, action: #selector(AppDelegate.showPreferences(_:)), keyEquivalent: ",")
        preferences.target = appDelegate
        app.addItem(.separator())
        app.addItem(withTitle: "Hide NPS Browser".localized, action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = app.addItem(withTitle: "Hide Others".localized, action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Show All".localized, action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit NPS Browser".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let database = submenu(of: main, title: "Database".localized)
        let reload = database.addItem(withTitle: "Reload".localized, action: #selector(WindowController.reloadDatabase(_:)), keyEquivalent: "r")
        reload.target = windowController

        let edit = submenu(of: main, title: "Edit".localized)
        edit.addItem(withTitle: "Undo".localized, action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo".localized, action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut".localized, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy".localized, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste".localized, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let pasteAndMatch = edit.addItem(withTitle: "Paste and Match Style".localized, action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "v")
        pasteAndMatch.keyEquivalentModifierMask = [.command, .option, .shift]
        edit.addItem(withTitle: "Delete".localized, action: #selector(NSText.delete(_:)), keyEquivalent: "")
        edit.addItem(withTitle: "Select All".localized, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let view = submenu(of: main, title: "View".localized)
        let toolbar = view.addItem(withTitle: "Show Toolbar".localized, action: #selector(NSWindow.toggleToolbarShown(_:)), keyEquivalent: "t")
        toolbar.keyEquivalentModifierMask = [.command, .option]
        view.addItem(.separator())
        let sidebar = view.addItem(withTitle: "Hide Sidebar".localized, action: #selector(NSSplitViewController.toggleSidebar(_:)), keyEquivalent: "s")
        sidebar.keyEquivalentModifierMask = [.command, .control]
        let fullScreen = view.addItem(withTitle: "Enter Full Screen".localized, action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]

        let window = submenu(of: main, title: "Window".localized)
        window.addItem(withTitle: "Minimize".localized, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Zoom".localized, action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        window.addItem(.separator())
        window.addItem(withTitle: "Bring All to Front".localized, action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = window

        return main
    }

    private static func submenu(of menu: NSMenu, title: String) -> NSMenu {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        item.submenu = submenu
        menu.addItem(item)
        return submenu
    }
}

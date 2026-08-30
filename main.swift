import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if !AXWindow.hasPermission {
            AXWindow.requestPermission()
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "▦"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Tiler", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Çık",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item

        coordinator.start()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

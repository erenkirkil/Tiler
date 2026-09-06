import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let coordinator = AppCoordinator()
    private weak var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if !AXWindow.hasPermission {
            AXWindow.requestPermission()
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Tiler") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "▦"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Tiler", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Ayarlar...",
                                action: #selector(openSettings),
                                keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Çık",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item

        coordinator.start()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadSettings), name: .tilerSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(recordingStateChanged(_:)), name: .tilerRecordingStateChanged, object: nil)
    }
    
    @objc private func recordingStateChanged(_ notification: Notification) {
        guard let isRecording = notification.object as? Bool else { return }
        if isRecording {
            coordinator.suspendShortcuts()
        } else {
            coordinator.rebindShortcuts()
        }
    }
    
    @objc private func openSettings() {
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Tiler Ayarları"
        window.contentViewController = hostingController
        
        // RAM Optimizasyonu: Pencere kapatıldığında hafızadan silinsin (NSHostingController dealloke edilir)
        window.isReleasedWhenClosed = true
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func reloadSettings() {
        coordinator.rebindShortcuts()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    @Published var shortcuts: [WindowAction: Shortcut?] = [:]
    @Published var conflicts: [WindowAction: [ConflictOwner]] = [:]
    @Published var recordingAction: WindowAction? = nil {
        didSet {
            NotificationCenter.default.post(name: .tilerRecordingStateChanged, object: recordingAction != nil)
        }
    }
    @Published var isScanning = false
    
    private var oracleCache: [NormalizedShortcut: [ConflictOwner]] = [:]
    private var eventMonitor: Any?
    
    init() {
        refresh()
        scanConflicts()
        setupEventMonitor()
    }
    
    func refresh() {
        var currentShortcuts: [WindowAction: Shortcut?] = [:]
        for action in WindowAction.allCases {
            currentShortcuts[action] = Settings.shortcut(for: action)
        }
        self.shortcuts = currentShortcuts
        updateConflicts()
    }
    
    func scanConflicts() {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let oracle = ConflictOracle.scan()
            DispatchQueue.main.async {
                self.oracleCache = oracle
                self.isScanning = false
                self.updateConflicts()
            }
        }
    }
    
    private func updateConflicts() {
        var newConflicts: [WindowAction: [ConflictOwner]] = [:]
        for (action, optionalShortcut) in shortcuts {
            guard let shortcut = optionalShortcut else { continue }
            let normalized = shortcut.normalized
            if let owners = oracleCache[normalized] {
                newConflicts[action] = owners
            }
        }
        self.conflicts = newConflicts
    }
    
    func setShortcut(_ shortcut: Shortcut?, for action: WindowAction) {
        Settings.setShortcut(shortcut, for: action)
        shortcuts[action] = shortcut
        updateConflicts()
        
        // Notify the app coordinator / hotkey binder to reload
        NotificationCenter.default.post(name: .tilerSettingsChanged, object: nil)
    }
    
    func resetAll() {
        Settings.resetAll()
        refresh()
        NotificationCenter.default.post(name: .tilerSettingsChanged, object: nil)
    }
    
    private func setupEventMonitor() {
        // Intercept key down events locally
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, let action = self.recordingAction else { return event }
            
            let cocoaFlags = event.modifierFlags
            var carbonMods: UInt32 = 0
            if cocoaFlags.contains(.command) { carbonMods |= Shortcut.cmd }
            if cocoaFlags.contains(.shift) { carbonMods |= Shortcut.shift }
            if cocoaFlags.contains(.option) { carbonMods |= Shortcut.option }
            if cocoaFlags.contains(.control) { carbonMods |= Shortcut.control }
            
            let keyCode = UInt32(event.keyCode)
            
            // ESC to cancel
            if keyCode == 53 && carbonMods == 0 {
                self.recordingAction = nil
                return nil
            }
            
            // Delete / Backspace to clear
            if keyCode == 51 && carbonMods == 0 {
                self.setShortcut(nil, for: action)
                self.recordingAction = nil
                return nil
            }
            
            // We require at least one modifier OR function key for valid hotkeys usually,
            // but let's just record whatever they press.
            let shortcut = Shortcut(keyCode: keyCode, carbonModifiers: carbonMods)
            self.setShortcut(shortcut, for: action)
            self.recordingAction = nil
            
            return nil // swallow event
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

extension Notification.Name {
    static let tilerSettingsChanged = Notification.Name("tilerSettingsChanged")
    static let tilerRecordingStateChanged = Notification.Name("tilerRecordingStateChanged")
}

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Kısayol Ayarları")
                    .font(.headline)
                Text("Değiştirmek için kısayola tıklayın, iptal için Esc, silmek için Backspace basın.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 14) {
                ForEach(WindowAction.allCases, id: \.self) { action in
                    HStack(spacing: 16) {
                        Text(action.displayName)
                            .frame(width: 140, alignment: .leading)
                        
                        Button(action: {
                            vm.recordingAction = action
                        }) {
                            Text(buttonText(for: action))
                                .frame(width: 120)
                                .foregroundColor(vm.recordingAction == action ? .accentColor : .primary)
                        }
                        
                        if let conflictOwners = vm.conflicts[action], !conflictOwners.isEmpty {
                            let names = conflictOwners.map { $0.displayName }.joined(separator: ", ")
                            Text("⚠️ \(names) kullanıyor")
                                .font(.caption)
                                .foregroundColor(.red)
                                .lineLimit(2)
                        } else {
                            Spacer()
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            
            HStack {
                Button("Varsayılanlara Dön") {
                    vm.resetAll()
                }
                
                Spacer()
                
                if vm.isScanning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .padding(.trailing, 4)
                    Text("Çakışmalar taranıyor...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Text("Diğer uygulamaların kaydettiği global kısayollar (Raycast, Alfred vb.) macOS tarafından bildirilmez, çakışma olsa da burada görünmeyebilir.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 550, alignment: .topLeading)
    }
    
    private func buttonText(for action: WindowAction) -> String {
        if vm.recordingAction == action {
            return "Kayıt ediliyor..."
        }
        if let optionalShortcut = vm.shortcuts[action], let shortcut = optionalShortcut {
            return shortcut.displayString
        }
        return "Atanmadı"
    }
}

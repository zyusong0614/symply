import SwiftUI

@main
struct SymplyApp: App {
    @State private var appState: AppState
    @State private var volumeMonitor: VolumeMonitor
    @State private var linkManager: LinkManager
    
    init() {
        let state = AppState()
        _appState = State(wrappedValue: state)
        _volumeMonitor = State(wrappedValue: VolumeMonitor())
        _linkManager = State(wrappedValue: LinkManager(appState: state))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(linkManager)
                .environment(volumeMonitor)
                .frame(minWidth: 700, minHeight: 400)
        }
        
        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

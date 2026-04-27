import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @State private var isShowingPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Options")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 4)
            
            HStack(spacing: 12) {
                Text("Default SSD Target:")
                    .fontWeight(.medium)
                
                Spacer()
                
                if appState.defaultSSDTarget.isEmpty {
                    Text("Not set").foregroundColor(.red)
                } else {
                    Text(appState.defaultSSDTarget)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 260)
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .help(appState.defaultSSDTarget)
                }
                
                Button("Select...") {
                    selectDirectory()
                }
            }
            
            Text("When you drag a local folder into Symply, it will automatically be moved to this SSD target folder, and a local symlink will be created.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                
            Spacer()
        }
        .padding(32)
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Target Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.defaultSSDTarget = url.path
        }
    }
}

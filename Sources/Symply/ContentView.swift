import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppState.self) var appState
    @Environment(LinkManager.self) var linkManager
    @Environment(VolumeMonitor.self) var volumeMonitor
    
    @State private var isTargeted = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showSettings = false
    @State private var selectedMappingID: UUID?
    
    @State private var isProcessing = false
    @State private var processingMessage = ""
    
    @State private var showingLargeFolderConfirmation = false
    @State private var pendingLargeFileURL: URL?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedMappingID) {
                Section(header: Text("Mapped Folders")) {
                    if appState.mappings.isEmpty {
                        Text("No mappings yet.")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.top, 8)
                    } else {
                        ForEach(appState.mappings) { mapping in
                            NavigationLink(value: mapping.id) {
                                MappingRow(mapping: mapping)
                            }
                        }
                        .onDelete(perform: removeMappings)
                    }
                }
            }
            .navigationTitle("Symply")
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        selectedMappingID = nil
                    }) {
                        Label("Add New Mapping", systemImage: "plus")
                    }
                    .help("Return to Drop Zone to migrate more folders")
                }
            }
        } detail: {
            if appState.defaultSSDTarget.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.fill.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Welcome to Symply")
                        .font(.largeTitle)
                    Text("Before you start, please configure your default SSD target directory.")
                        .foregroundColor(.secondary)
                    
                    Button("Open Settings") {
                        showSettings = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let selectedID = selectedMappingID, let mapping = appState.mappings.first(where: { $0.id == selectedID }) {
                MappingDetailView(mapping: mapping, onRestore: {
                    do {
                        self.isProcessing = true
                        self.processingMessage = "Restoring \(mapping.name)..."
                        
                        let manager = linkManager
                        DispatchQueue.global(qos: .userInitiated).async {
                            do {
                                try manager.restore(mapping: mapping)
                                DispatchQueue.main.async {
                                    selectedMappingID = nil
                                    self.isProcessing = false
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    self.errorMessage = error.localizedDescription
                                    self.showingError = true
                                    self.isProcessing = false
                                }
                            }
                        }
                    } 
                })
                .id(mapping.id)
            } else {
                dropZoneView
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Large Folder Verification", isPresented: $showingLargeFolderConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingLargeFileURL = nil
            }
            Button("Proceed", role: .destructive) {
                if let url = pendingLargeFileURL {
                    performMove(url: url)
                }
                pendingLargeFileURL = nil
            }
        } message: {
            Text("This folder exceeds 1 GB and might take minutes to complete safely.\n\nPlease verify that its related App (e.g. WeChat) is COMPLETELY closed before proceeding, otherwise the transfer will hang indefinitely!")
        }
        .onAppear {
            linkManager.checkHealth()
            volumeMonitor.onMountStatusChanged = {
                linkManager.checkHealth()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(appState)
                .frame(width: 450, height: 250)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showSettings = false }
                    }
                }
        }
    }
    
    var dropZoneView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(isTargeted ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isTargeted ? Color.blue : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 4, dash: [10]))
                )
                .padding(40)
            
            
            VStack(spacing: 16) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(.bottom, 8)
                    Text(processingMessage)
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 64))
                        .foregroundColor(isTargeted ? .blue : .secondary)
                    Text("Drag & Drop")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("Drop local folders here to migrate them to SSD")
                        .foregroundColor(.secondary)
                    
                    Text(appState.defaultSSDTarget)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.top, 20)
                        .frame(maxWidth: 300)
                    
                    Button("Change Target SSD") {
                        showSettings = true
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard !isProcessing else { return false }
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    guard let url = url else { return }
                    DispatchQueue.main.async {
                        self.processDroppedURL(url)
                    }
                }
            }
            return true
        }
    }
    
    private func processDroppedURL(_ url: URL) {
        isProcessing = true
        processingMessage = "Analyzing \(url.lastPathComponent)..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            var size: Int64 = 0
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        size += Int64(fileSize)
                        if size > 1_000_000_000 { // 1 GB limit for verification
                            break
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                if size > 1_000_000_000 {
                    self.isProcessing = false
                    self.pendingLargeFileURL = url
                    self.showingLargeFolderConfirmation = true
                } else {
                    self.performMove(url: url)
                }
            }
        }
    }
    
    private func performMove(url: URL) {
        isProcessing = true
        processingMessage = "Moving \(url.lastPathComponent) to SSD..."
        
        let manager = linkManager
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try manager.moveAndLink(localURL: url)
                DispatchQueue.main.async {
                    manager.checkHealth()
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func removeMappings(at offsets: IndexSet) {
        for index in offsets {
            let mapping = appState.mappings[index]
            do {
                try linkManager.restore(mapping: mapping)
            } catch {
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }
}

struct MappingRow: View {
    var mapping: SymlinkMapping
    
    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(mapping.name)
                    .font(.headline)
                Text(mapping.localPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Show Original on SSD") {
                NSWorkspace.shared.selectFile(mapping.externalPath, inFileViewerRootedAtPath: "")
            }
            Button("Show Local Symlink") {
                NSWorkspace.shared.selectFile(mapping.localPath, inFileViewerRootedAtPath: "")
            }
        }
    }
    
    @ViewBuilder
    var statusIcon: some View {
        switch mapping.status {
        case .active:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .help("Active")
        case .offline:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
                .help("Disk Offline")
        case .broken:
            Image(systemName: "xmark.octagon.fill")
                .foregroundColor(.red)
                .help("Broken Link")
        }
    }
}

struct MappingDetailView: View {
    var mapping: SymlinkMapping
    var onRestore: () -> Void
    @State private var folderSize: String = "Calculating..."
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text(mapping.name)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                InfoBox(title: "Status", value: mapping.status.rawValue.capitalized, color: mapping.status == .active ? .green : .red)
                InfoBox(title: "Total Size on SSD", value: folderSize, color: .primary)
                InfoBox(title: "Original Local Path", value: mapping.localPath, color: .secondary)
                InfoBox(title: "Stored SSD Path", value: mapping.externalPath, color: .secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            HStack(spacing: 16) {
                Button(action: {
                    NSWorkspace.shared.selectFile(mapping.externalPath, inFileViewerRootedAtPath: "")
                }) {
                    Label("View in Finder", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                
                Button(action: onRestore) {
                    Label("Restore & Unlink", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            
            Spacer()
        }
        .padding(40)
        .onAppear(perform: calculateSize)
    }
    
    private func calculateSize() {
        DispatchQueue.global(qos: .background).async {
            let url = URL(fileURLWithPath: mapping.externalPath)
            var size: Int64 = 0
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        size += Int64(fileSize)
                    }
                }
            }
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            let formattedSize = formatter.string(fromByteCount: size)
            DispatchQueue.main.async {
                self.folderSize = formattedSize
            }
        }
    }
}

struct InfoBox: View {
    var title: String
    var value: String
    var color: Color
    
    var body: some View {
        HStack {
            Text(title + ":")
                .fontWeight(.semibold)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .foregroundColor(color)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }
}

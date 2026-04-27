import Foundation

@Observable
final class LinkManager: @unchecked Sendable {
    let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func checkHealth() {
        for index in appState.mappings.indices {
            let mapping = appState.mappings[index]
            let externalExists = FileManager.default.fileExists(atPath: mapping.externalPath)
            let localExists = FileManager.default.fileExists(atPath: mapping.localPath)
            
            if externalExists {
                if localExists {
                    do {
                        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: mapping.localPath)
                        // Note: destinationOfSymbolicLink might return a relative or absolute path.
                        // Standardizing URLs ensures they match.
                        
                        let destinationURL: URL
                        if destination.hasPrefix("/") {
                            destinationURL = URL(fileURLWithPath: destination)
                        } else {
                            let localDir = URL(fileURLWithPath: mapping.localPath).deletingLastPathComponent()
                            destinationURL = URL(fileURLWithPath: destination, relativeTo: localDir).standardizedFileURL
                        }
                        
                        if destinationURL.standardizedFileURL.path == URL(fileURLWithPath: mapping.externalPath).standardizedFileURL.path {
                            appState.mappings[index].status = .active
                        } else {
                            appState.mappings[index].status = .broken
                        }
                    } catch {
                        appState.mappings[index].status = .broken
                    }
                } else {
                    appState.mappings[index].status = .broken
                }
            } else {
                appState.mappings[index].status = .offline
            }
        }
        // AppState mappings are Observable so UI updates auto
        appState.saveMappings()
    }

    func moveAndLink(localURL: URL) throws {
        let defaultSSD = appState.defaultSSDTarget
        guard !defaultSSD.isEmpty else { return }
        
        if !FileManager.default.fileExists(atPath: defaultSSD) {
            try FileManager.default.createDirectory(atPath: defaultSSD, withIntermediateDirectories: true, attributes: nil)
        }
        
        var destinationURL = URL(fileURLWithPath: defaultSSD).appendingPathComponent(localURL.lastPathComponent)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let uniqueSuffix = UUID().uuidString.prefix(6)
            destinationURL = URL(fileURLWithPath: defaultSSD).appendingPathComponent("\(localURL.lastPathComponent)-\(uniqueSuffix)")
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                throw NSError(domain: "Symply", code: 1, userInfo: [NSLocalizedDescriptionKey: "Target already exists on SSD. Please try again."])
            }
        }
        
        try FileManager.default.moveItem(at: localURL, to: destinationURL)
        try FileManager.default.createSymbolicLink(at: localURL, withDestinationURL: destinationURL)
        
        let mapping = SymlinkMapping(localPath: localURL.path, externalPath: destinationURL.path, status: .active)
        DispatchQueue.main.async {
            self.appState.addMapping(mapping)
        }
    }
    
    func restore(mapping: SymlinkMapping) throws {
        try FileManager.default.removeItem(atPath: mapping.localPath)
        try FileManager.default.moveItem(atPath: mapping.externalPath, toPath: mapping.localPath)
        DispatchQueue.main.async {
            self.appState.removeMapping(id: mapping.id)
        }
    }
}

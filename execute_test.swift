import Foundation
import SwiftUI // for @Observable

// --- Models ---
enum MappingStatus: String, Codable {
    case active, offline, broken
}

struct SymlinkMapping: Codable, Identifiable {
    var id: UUID = UUID()
    var localPath: String
    var externalPath: String
    var status: MappingStatus = .active
    var dateCreated: Date = Date()
    var name: String { URL(fileURLWithPath: localPath).lastPathComponent }
}

@Observable
class AppState {
    var mappings: [SymlinkMapping] = []
    
    var defaultSSDTarget: String {
        get { UserDefaults.standard.string(forKey: "DefaultSSDTarget") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "DefaultSSDTarget") }
    }
    
    private let saveURL: URL
    
    init() {
        let appDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SymplyTest")
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        self.saveURL = appDirectory.appendingPathComponent("mappings.json")
    }
    
    func saveMappings() {}
    func addMapping(_ mapping: SymlinkMapping) { mappings.append(mapping) }
    func removeMapping(id: UUID) { mappings.removeAll { $0.id == id } }
}

@Observable
class LinkManager {
    let appState: AppState
    init(appState: AppState) { self.appState = appState }
    
    func moveAndLink(localURL: URL) throws {
        let defaultSSD = appState.defaultSSDTarget
        guard !defaultSSD.isEmpty else { return }
        
        if !FileManager.default.fileExists(atPath: defaultSSD) {
            try FileManager.default.createDirectory(atPath: defaultSSD, withIntermediateDirectories: true, attributes: nil)
        }
        
        let destinationURL = URL(fileURLWithPath: defaultSSD).appendingPathComponent(localURL.lastPathComponent)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            throw NSError(domain: "Symply", code: 1, userInfo: [NSLocalizedDescriptionKey: "Target already exists on SSD."])
        }
        
        try FileManager.default.moveItem(at: localURL, to: destinationURL)
        try FileManager.default.createSymbolicLink(at: localURL, withDestinationURL: destinationURL)
        let mapping = SymlinkMapping(localPath: localURL.path, externalPath: destinationURL.path, status: .active)
        appState.addMapping(mapping)
    }
}

// --- Test Execution ---
func runTest() {
    print("Starting integration test...")
    let appState = AppState()
    
    let targetDir = "/Users/zhengyu/Documents/workspace/symply_test/SSD_Target"
    appState.defaultSSDTarget = targetDir
    
    let linkManager = LinkManager(appState: appState)
    
    let fm = FileManager.default
    let localDir = "/Users/zhengyu/Documents/workspace/symply_test/LocalFolder"
    let localURL = URL(fileURLWithPath: localDir)
    
    do {
        // Setup original folder
        if fm.fileExists(atPath: localDir) { try? fm.removeItem(atPath: localDir) }
        let targetFullPath = "/Users/zhengyu/Documents/workspace/symply_test/SSD_Target/LocalFolder"
        if fm.fileExists(atPath: targetFullPath) { try? fm.removeItem(atPath: targetFullPath) }
        
        try fm.createDirectory(atPath: localDir, withIntermediateDirectories: true)
        fm.createFile(atPath: localDir + "/dummy.txt", contents: "Hello Test".data(using: .utf8), attributes: nil)
        print("Created dummy LocalFolder with file.")
        
        // Execute move and link
        try linkManager.moveAndLink(localURL: localURL)
        print("Executed moveAndLink.")
        
        // Assertions
        let localExists = fm.fileExists(atPath: localDir)
        if !localExists { print("❌ FAILURE: Local symlink missing"); return }
        
        let attrs = try fm.attributesOfItem(atPath: localDir)
        if attrs[.type] as? FileAttributeType != .typeSymbolicLink {
            print("❌ FAILURE: Local item is NOT a symlink")
            return
        }
        
        let dest = try fm.destinationOfSymbolicLink(atPath: localDir)
        print("Symlink correctly created, pointing to: \(dest)")
        
        if fm.fileExists(atPath: targetFullPath) {
            let data = try String(contentsOfFile: targetFullPath + "/dummy.txt")
            print("✅ SUCCESS: Target folder exists and contents intact: \(data)")
        } else {
            print("❌ FAILURE: Target folder missing on SSD side")
        }
        
    } catch {
        print("❌ ERROR: \(error)")
    }
}

runTest()

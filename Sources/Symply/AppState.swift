import Foundation
import SwiftUI

@Observable
class AppState {
    var mappings: [SymlinkMapping] = []
    
    var defaultSSDTarget: String = UserDefaults.standard.string(forKey: "DefaultSSDTarget") ?? "" {
        didSet {
            UserDefaults.standard.set(defaultSSDTarget, forKey: "DefaultSSDTarget")
        }
    }
    
    private let saveURL: URL
    
    init() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("Symply")
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        
        self.saveURL = appDirectory.appendingPathComponent("mappings.json")
        loadMappings()
    }
    
    func saveMappings() {
        do {
            let data = try JSONEncoder().encode(mappings)
            try data.write(to: saveURL)
        } catch {
            print("Failed to save mappings: \(error)")
        }
    }
    
    func loadMappings() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        do {
            self.mappings = try JSONDecoder().decode([SymlinkMapping].self, from: data)
        } catch {
            print("Failed to load mappings: \(error)")
        }
    }
    
    func addMapping(_ mapping: SymlinkMapping) {
        mappings.append(mapping)
        saveMappings()
    }
    
    func removeMapping(id: UUID) {
        mappings.removeAll { $0.id == id }
        saveMappings()
    }
}

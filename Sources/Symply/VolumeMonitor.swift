import Foundation
import AppKit

@Observable
class VolumeMonitor {
    var mountedVolumes: [URL] = []
    var onMountStatusChanged: (() -> Void)?
    
    init() {
        refreshVolumes()
        setupListeners()
    }
    
    private func setupListeners() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshVolumes()
            self?.onMountStatusChanged?()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshVolumes()
            self?.onMountStatusChanged?()
        }
    }
    
    func refreshVolumes() {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey]
        if let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) {
            self.mountedVolumes = paths
        }
    }
}

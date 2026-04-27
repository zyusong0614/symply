import Foundation

enum MappingStatus: String, Codable {
    case active
    case offline
    case broken
}

struct SymlinkMapping: Codable, Identifiable {
    var id: UUID = UUID()
    var localPath: String
    var externalPath: String
    var status: MappingStatus = .active
    var dateCreated: Date = Date()
    
    var name: String {
        URL(fileURLWithPath: localPath).lastPathComponent
    }
}

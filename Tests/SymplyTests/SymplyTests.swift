import XCTest
import Foundation
@testable import Symply

final class SymplyTests: XCTestCase {
    func testMoveAndLink() throws {
        let appState = AppState()
        
        // Setup target
        let targetDir = "/Users/zhengyu/Documents/workspace/symply_test/SSD_Target"
        appState.defaultSSDTarget = targetDir
        
        let linkManager = LinkManager(appState: appState)
        
        // Create new local folder for testing
        let fm = FileManager.default
        let localDir = "/Users/zhengyu/Documents/workspace/symply_test/LocalFolder"
        let localURL = URL(fileURLWithPath: localDir)
        
        // Clean up if it exists
        if fm.fileExists(atPath: localDir) { try? fm.removeItem(atPath: localDir) }
        let targetFullPath = "/Users/zhengyu/Documents/workspace/symply_test/SSD_Target/LocalFolder"
        if fm.fileExists(atPath: targetFullPath) { try? fm.removeItem(atPath: targetFullPath) }
        
        // Re-create
        try fm.createDirectory(atPath: localDir, withIntermediateDirectories: true)
        fm.createFile(atPath: localDir + "/dummy.txt", contents: "Hello".data(using: .utf8), attributes: nil)
        
        // Move & Link
        try linkManager.moveAndLink(localURL: localURL)
        
        // Verify symlink exists at localUrl
        let localExists = fm.fileExists(atPath: localDir)
        XCTAssertTrue(localExists)
        
        // Verify it's a symlink
        let attrs = try fm.attributesOfItem(atPath: localDir)
        XCTAssertEqual(attrs[.type] as? FileAttributeType, .typeSymbolicLink)
        
        // Verify destination
        let dest = try fm.destinationOfSymbolicLink(atPath: localDir)
        XCTAssertTrue(fm.fileExists(atPath: targetFullPath))
    }
}

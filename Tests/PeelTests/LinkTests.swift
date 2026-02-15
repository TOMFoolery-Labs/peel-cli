import Testing
import Foundation
@testable import peel

@Suite("Link command helpers")
struct LinkTests {

    @Test("symlinkDirectory returns parent directory of binary path")
    func symlinkDirectory() {
        #expect(Link.symlinkDirectory(forBinary: "/usr/local/bin/peel") == "/usr/local/bin")
        #expect(Link.symlinkDirectory(forBinary: "/opt/homebrew/bin/peel") == "/opt/homebrew/bin")
    }

    @Test("dockerSymlinkPath appends 'docker' to binary's directory")
    func dockerSymlinkPath() {
        let path = Link.dockerSymlinkPath(forBinary: "/usr/local/bin/peel")
        #expect(path == "/usr/local/bin/docker")
    }

    @Test("checkExisting returns .noFile when nothing exists")
    func checkExistingNoFile() {
        let status = Link.checkExisting(
            at: "/tmp/peel-test-nonexistent-\(UUID().uuidString)",
            peelPath: "/usr/local/bin/peel"
        )
        guard case .noFile = status else {
            Issue.record("Expected .noFile, got \(status)")
            return
        }
    }

    @Test("checkExisting returns .regularFile for a non-symlink file")
    func checkExistingRegularFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peel-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let filePath = tmpDir.appendingPathComponent("docker").path
        FileManager.default.createFile(atPath: filePath, contents: Data())

        let status = Link.checkExisting(at: filePath, peelPath: "/usr/local/bin/peel")
        guard case .regularFile = status else {
            Issue.record("Expected .regularFile, got \(status)")
            return
        }
    }

    @Test("checkExisting returns .symlinkToPeel when symlink points to peel")
    func checkExistingSymlinkToPeel() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peel-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let peelPath = tmpDir.appendingPathComponent("peel").path
        let dockerPath = tmpDir.appendingPathComponent("docker").path

        // Create a fake peel binary
        FileManager.default.createFile(atPath: peelPath, contents: Data())
        // Create symlink docker -> peel
        try FileManager.default.createSymbolicLink(atPath: dockerPath, withDestinationPath: peelPath)

        let status = Link.checkExisting(at: dockerPath, peelPath: peelPath)
        guard case .symlinkToPeel = status else {
            Issue.record("Expected .symlinkToPeel, got \(status)")
            return
        }
    }

    @Test("checkExisting returns .symlinkToOther when symlink points elsewhere")
    func checkExistingSymlinkToOther() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peel-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let otherPath = tmpDir.appendingPathComponent("other-binary").path
        let dockerPath = tmpDir.appendingPathComponent("docker").path

        FileManager.default.createFile(atPath: otherPath, contents: Data())
        try FileManager.default.createSymbolicLink(atPath: dockerPath, withDestinationPath: otherPath)

        let status = Link.checkExisting(at: dockerPath, peelPath: "/usr/local/bin/peel")
        guard case .symlinkToOther = status else {
            Issue.record("Expected .symlinkToOther, got \(status)")
            return
        }
    }
}

import Testing
import Foundation
@testable import peel

// MARK: - ImageRefResolver Tests

@Test func resolveBareImageName() {
    #expect(ImageRefResolver.resolve("nginx") == "docker.io/library/nginx:latest")
}

@Test func resolveBareImageWithTag() {
    #expect(ImageRefResolver.resolve("nginx:alpine") == "docker.io/library/nginx:alpine")
}

@Test func resolveNamespacedImage() {
    #expect(ImageRefResolver.resolve("myuser/myapp") == "docker.io/myuser/myapp:latest")
}

@Test func resolveNamespacedImageWithTag() {
    #expect(ImageRefResolver.resolve("myuser/myapp:v1") == "docker.io/myuser/myapp:v1")
}

@Test func resolveFullyQualifiedImage() {
    #expect(ImageRefResolver.resolve("ghcr.io/org/app:v2") == "ghcr.io/org/app:v2")
}

@Test func resolveFullyQualifiedWithoutTag() {
    #expect(ImageRefResolver.resolve("ghcr.io/org/app") == "ghcr.io/org/app:latest")
}

@Test func resolveAlpine() {
    #expect(ImageRefResolver.resolve("alpine") == "docker.io/library/alpine:latest")
}

// MARK: - FlagMapper Volume Translation Tests

@Test func translateBindMount() {
    #expect(FlagMapper.translateVolume("/host/path:/container/path") == ["--mount", "source=/host/path,target=/container/path"])
}

@Test func translateBindMountReadOnly() {
    #expect(FlagMapper.translateVolume("/host/path:/container/path:ro") == ["--mount", "source=/host/path,target=/container/path,readonly"])
}

@Test func translateNamedVolume() {
    #expect(FlagMapper.translateVolume("myvolume:/container/path") == ["--volume", "myvolume:/container/path"])
}

@Test func translateRelativeBindMount() {
    #expect(FlagMapper.translateVolume("./local:/container/path") == ["--mount", "source=./local,target=/container/path"])
}

@Test func translateSinglePath() {
    #expect(FlagMapper.translateVolume("/just/a/path") == ["--volume", "/just/a/path"])
}

@Test func translateNamedVolumeWithOptions() {
    #expect(FlagMapper.translateVolume("myvolume:/container/path:ro") == ["--volume", "myvolume:/container/path:ro"])
}

@Test func translateHomeDirBindMount() {
    #expect(FlagMapper.translateVolume("~/data:/container/data") == ["--mount", "source=~/data,target=/container/data"])
}

@Test func translateFileMountSkipped() throws {
    // Create a temp file to trigger file mount detection
    let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("peel-test-\(UUID().uuidString).txt")
    FileManager.default.createFile(atPath: tmpFile, contents: nil)
    defer { try? FileManager.default.removeItem(atPath: tmpFile) }

    let result = FlagMapper.translateVolume("\(tmpFile):/app/config.txt:ro")
    // File mounts should be skipped (empty args) with a warning
    #expect(result == [])
}

@Test func translateNonexistentPathPassesThrough() {
    // Paths that don't exist on disk should pass through unchanged
    let result = FlagMapper.translateVolume("/nonexistent/path:/container/path")
    #expect(result == ["--mount", "source=/nonexistent/path,target=/container/path"])
}

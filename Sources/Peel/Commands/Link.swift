import ArgumentParser
import Foundation

struct Link: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "link",
        abstract: "Create a docker → peel symlink so 'docker' invocations use peel",
        subcommands: [LinkCreate.self, LinkRemove.self],
        defaultSubcommand: LinkCreate.self
    )
}

// MARK: - Symlink path helpers

extension Link {
    /// Resolves the absolute path of the running peel binary.
    static func resolvePeelBinaryPath() -> String {
        let raw = CommandLine.arguments[0]
        let url = URL(fileURLWithPath: raw).standardized
        // Resolve symlinks to get the real peel binary
        let resolved = url.resolvingSymlinksInPath()
        return resolved.path
    }

    /// Returns the directory containing the peel binary.
    static func symlinkDirectory(forBinary binaryPath: String) -> String {
        return URL(fileURLWithPath: binaryPath).deletingLastPathComponent().path
    }

    /// The target path where the `docker` symlink will be placed.
    static func dockerSymlinkPath(forBinary binaryPath: String) -> String {
        let dir = symlinkDirectory(forBinary: binaryPath)
        return (dir as NSString).appendingPathComponent("docker")
    }

    /// Checks the status of an existing file at the given path.
    enum ExistingFileStatus {
        case noFile
        case symlinkToPeel
        case symlinkToOther(String)
        case regularFile
    }

    static func checkExisting(at path: String, peelPath: String) -> ExistingFileStatus {
        let fm = FileManager.default

        // Check if anything exists at the path (don't follow symlinks)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            // Also check for broken symlinks
            let attrs = try? fm.attributesOfItem(atPath: path)
            if attrs != nil {
                // Broken symlink exists
                return .symlinkToOther("(broken)")
            }
            return .noFile
        }

        // Check if it's a symlink
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let fileType = attrs[.type] as? FileAttributeType,
           fileType == .typeSymbolicLink {
            // It's a symlink — check where it points
            if let destination = try? fm.destinationOfSymbolicLink(atPath: path) {
                let resolvedDest = URL(fileURLWithPath: destination, relativeTo: URL(fileURLWithPath: path).deletingLastPathComponent()).resolvingSymlinksInPath().path
                let resolvedPeel = URL(fileURLWithPath: peelPath).resolvingSymlinksInPath().path
                if resolvedDest == resolvedPeel {
                    return .symlinkToPeel
                }
                return .symlinkToOther(destination)
            }
            return .symlinkToOther("(unknown)")
        }

        return .regularFile
    }
}

// MARK: - link create

struct LinkCreate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a docker → peel symlink"
    )

    @Flag(name: .long, help: "Overwrite an existing docker binary or symlink")
    var force: Bool = false

    func run() throws {
        let peelPath = Link.resolvePeelBinaryPath()
        let dockerPath = Link.dockerSymlinkPath(forBinary: peelPath)

        switch Link.checkExisting(at: dockerPath, peelPath: peelPath) {
        case .noFile:
            break // Good to go

        case .symlinkToPeel:
            print("Already linked: \(dockerPath) -> \(peelPath)")
            return

        case .symlinkToOther(let dest):
            if !force {
                fputs("peel: existing symlink found at \(dockerPath) -> \(dest)\n", stderr)
                fputs("peel: use --force to overwrite\n", stderr)
                throw ExitCode(1)
            }
            try FileManager.default.removeItem(atPath: dockerPath)

        case .regularFile:
            if !force {
                fputs("peel: existing Docker installation found at \(dockerPath)\n", stderr)
                fputs("peel: use --force to overwrite\n", stderr)
                throw ExitCode(1)
            }
            try FileManager.default.removeItem(atPath: dockerPath)
        }

        do {
            try FileManager.default.createSymbolicLink(
                atPath: dockerPath,
                withDestinationPath: peelPath
            )
        } catch {
            fputs("peel: failed to create symlink: \(error.localizedDescription)\n", stderr)
            throw ExitCode(1)
        }

        print("Created symlink: \(dockerPath) -> \(peelPath)")
    }
}

// MARK: - link remove

struct LinkRemove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove the docker → peel symlink"
    )

    func run() throws {
        let peelPath = Link.resolvePeelBinaryPath()
        let dockerPath = Link.dockerSymlinkPath(forBinary: peelPath)

        switch Link.checkExisting(at: dockerPath, peelPath: peelPath) {
        case .noFile:
            fputs("peel: no docker symlink found at \(dockerPath)\n", stderr)
            throw ExitCode(1)

        case .symlinkToPeel:
            break // This is what we want to remove

        case .symlinkToOther(let dest):
            fputs("peel: \(dockerPath) is a symlink to \(dest), not peel — refusing to remove\n", stderr)
            throw ExitCode(1)

        case .regularFile:
            fputs("peel: \(dockerPath) is not a peel symlink — refusing to remove\n", stderr)
            throw ExitCode(1)
        }

        do {
            try FileManager.default.removeItem(atPath: dockerPath)
        } catch {
            fputs("peel: failed to remove symlink: \(error.localizedDescription)\n", stderr)
            throw ExitCode(1)
        }

        print("Removed symlink: \(dockerPath)")
    }
}

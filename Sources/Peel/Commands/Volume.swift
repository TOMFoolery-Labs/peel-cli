import ArgumentParser
import Foundation

struct Volume: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "volume",
        abstract: "Manage volumes (translates to: container volume)",
        subcommands: [VolumeList.self, VolumeCreate.self, VolumeRemove.self]
    )
}

// MARK: - volume ls

struct VolumeList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls",
        abstract: "List volumes (translates to: container volume list)"
    )

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    func run() throws {
        let args: [String] = ["volume", "list"]
        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
        throw ExitCode(exitCode)
    }
}

// MARK: - volume create

struct VolumeCreate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a volume (translates to: container volume create)"
    )

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    @Argument(help: "Volume name")
    var name: String

    func run() throws {
        let args: [String] = ["volume", "create", name]
        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
        throw ExitCode(exitCode)
    }
}

// MARK: - volume rm

struct VolumeRemove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Remove one or more volumes (translates to: container volume delete)"
    )

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    @Argument(help: "Volume name(s) to remove")
    var volumes: [String]

    func run() throws {
        var args: [String] = ["volume", "delete"]
        args.append(contentsOf: volumes)
        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
        throw ExitCode(exitCode)
    }
}

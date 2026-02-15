import ArgumentParser
import Foundation

struct Network: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "network",
        abstract: "Manage networks (translates to: container network)",
        subcommands: [NetworkList.self, NetworkCreate.self, NetworkRemove.self]
    )
}

// MARK: - network ls

struct NetworkList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls",
        abstract: "List networks (translates to: container network list)"
    )

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    func run() throws {
        let args: [String] = ["network", "list"]
        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
        throw ExitCode(exitCode)
    }
}

// MARK: - network create

struct NetworkCreate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a network (translates to: container network create)"
    )

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    @Argument(help: "Network name")
    var name: String

    func run() throws {
        let args: [String] = ["network", "create", name]
        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
        throw ExitCode(exitCode)
    }
}

// MARK: - network rm

struct NetworkRemove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Remove one or more networks (translates to: container network delete)"
    )

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    @Argument(help: "Network name(s) to remove")
    var networks: [String]

    func run() throws {
        var args: [String] = ["network", "delete"]
        args.append(contentsOf: networks)
        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
        throw ExitCode(exitCode)
    }
}

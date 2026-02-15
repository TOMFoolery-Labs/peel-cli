import ArgumentParser
import Foundation

struct PS: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ps",
        abstract: "List containers (translates to: container ls)"
    )

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    @Flag(name: .shortAndLong, help: "Show all containers (default shows just running)")
    var all: Bool = false

    @Flag(name: .shortAndLong, help: "Only display container IDs")
    var quiet: Bool = false

    func run() throws {
        var args: [String] = ["ls"]

        if all { args.append("--all") }
        if quiet { args.append("--quiet") }

        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
        throw ExitCode(exitCode)
    }
}

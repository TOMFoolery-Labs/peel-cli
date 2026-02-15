import ArgumentParser
import Foundation

struct PS: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ps",
        abstract: "List containers (translates to: container ls)"
    )

    @Flag(name: .shortAndLong, help: "Show all containers (default shows just running)")
    var all: Bool = false

    @Flag(name: .shortAndLong, help: "Only display container IDs")
    var quiet: Bool = false

    func run() throws {
        var args: [String] = ["ls"]

        if all { args.append("--all") }
        if quiet { args.append("--quiet") }

        let exitCode = ProcessRunner.exec(args)
        throw ExitCode(exitCode)
    }
}

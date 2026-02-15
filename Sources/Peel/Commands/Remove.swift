import ArgumentParser
import Foundation

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Remove one or more containers (translates to: container delete)"
    )

    @Flag(name: .shortAndLong, help: "Force the removal of a running container")
    var force: Bool = false

    @Argument(help: "Container ID(s) to remove")
    var containers: [String]

    func run() throws {
        var args: [String] = ["delete"]

        if force { args.append("--force") }
        args.append(contentsOf: containers)

        let exitCode = ProcessRunner.exec(args)
        throw ExitCode(exitCode)
    }
}

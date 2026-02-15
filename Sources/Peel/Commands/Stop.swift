import ArgumentParser
import Foundation

struct Stop: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stop one or more running containers (translates to: container stop)"
    )

    @Argument(help: "Container ID(s) to stop")
    var containers: [String]

    func run() throws {
        var args: [String] = ["stop"]
        args.append(contentsOf: containers)

        let exitCode = ProcessRunner.exec(args)
        throw ExitCode(exitCode)
    }
}

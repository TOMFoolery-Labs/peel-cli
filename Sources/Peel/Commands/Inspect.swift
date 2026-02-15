import ArgumentParser
import Foundation

struct Inspect: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Return low-level information on a container (translates to: container inspect)"
    )

    @Argument(help: "Container ID(s) to inspect")
    var containers: [String]

    func run() throws {
        var args: [String] = ["inspect"]
        args.append(contentsOf: containers)

        let exitCode = ProcessRunner.exec(args)
        throw ExitCode(exitCode)
    }
}

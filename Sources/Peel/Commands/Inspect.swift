import ArgumentParser
import Foundation

struct Inspect: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Return low-level information on a container (translates to: container inspect)"
    )

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    @Argument(help: "Container ID(s) to inspect")
    var containers: [String]

    func run() throws {
        var args: [String] = ["inspect"]
        args.append(contentsOf: containers)

        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
        throw ExitCode(exitCode)
    }
}

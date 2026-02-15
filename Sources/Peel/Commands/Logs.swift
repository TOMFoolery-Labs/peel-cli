import ArgumentParser
import Foundation

struct Logs: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Fetch the logs of a container (translates to: container logs)"
    )

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    @Flag(name: .shortAndLong, help: "Follow log output")
    var follow: Bool = false

    @Option(name: [.short, .long], help: "Number of lines to show from the end of the logs")
    var tail: Int?

    @Argument(help: "Container ID")
    var container: String

    func run() throws {
        var args: [String] = ["logs"]

        if follow { args.append("--follow") }

        if let tail = tail {
            args.append(contentsOf: ["--tail", String(tail)])
        }

        args.append(container)

        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
        throw ExitCode(exitCode)
    }
}

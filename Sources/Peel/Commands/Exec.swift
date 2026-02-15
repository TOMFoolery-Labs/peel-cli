import ArgumentParser
import Foundation

struct Exec: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Execute a command in a running container (translates to: container exec)"
    )

    @Flag(name: .shortAndLong, help: "Detached mode: run command in the background")
    var detach: Bool = false

    @Flag(name: .short, help: "Keep STDIN open even if not attached")
    var interactive: Bool = false

    @Flag(name: .short, help: "Allocate a pseudo-TTY")
    var tty: Bool = false

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Set environment variables")
    var env: [String] = []

    @Argument(help: "Container ID")
    var container: String

    @Argument(parsing: .captureForPassthrough, help: "Command to execute")
    var command: [String] = []

    func run() throws {
        var args: [String] = ["exec"]

        if detach { args.append("--detach") }
        if interactive { args.append("-i") }
        if tty { args.append("-t") }

        for envVar in env {
            args.append(contentsOf: ["--env", envVar])
        }

        args.append(container)
        args.append(contentsOf: command)

        let exitCode = ProcessRunner.exec(args)
        throw ExitCode(exitCode)
    }
}

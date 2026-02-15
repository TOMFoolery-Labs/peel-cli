import ArgumentParser
import Foundation

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build an image from a Dockerfile (translates to: container build)"
    )

    @Option(name: .shortAndLong, help: "Name and optionally a tag in the name:tag format")
    var tag: String?

    @Option(name: .shortAndLong, help: "Name of the Dockerfile")
    var file: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Set build-time variables")
    var buildArg: [String] = []

    @Flag(name: .long, help: "Do not use cache when building the image")
    var noCache: Bool = false

    @Option(name: .long, help: "Set the target build stage to build")
    var target: String?

    @Argument(help: "Build context directory")
    var context: String = "."

    func run() throws {
        var args: [String] = ["build"]

        if let tag = tag {
            args.append(contentsOf: ["--tag", tag])
        }

        if let file = file {
            args.append(contentsOf: ["--file", file])
        }

        for arg in buildArg {
            args.append(contentsOf: ["--build-arg", arg])
        }

        if noCache { args.append("--no-cache") }

        if let target = target {
            args.append(contentsOf: ["--target", target])
        }

        args.append(context)

        let exitCode = ProcessRunner.exec(args)
        throw ExitCode(exitCode)
    }
}

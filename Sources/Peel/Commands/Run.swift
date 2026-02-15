import ArgumentParser
import Foundation

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create and run a new container (translates to: container run)"
    )

    // --- Docker-compatible flags ---

    @Flag(name: .long, help: "Show the translated command without executing it")
    var dryRun: Bool = false

    @Flag(name: .shortAndLong, help: "Run container in background")
    var detach: Bool = false

    @Flag(name: .short, help: "Keep STDIN open even if not attached")
    var interactive: Bool = false

    @Flag(name: .short, help: "Allocate a pseudo-TTY")
    var tty: Bool = false

    @Flag(help: "Automatically remove the container when it exits")
    var rm: Bool = false

    @Option(name: .long, help: "Assign a name to the container")
    var name: String?

    @Option(name: .shortAndLong, parsing: .singleValue, help: "Publish a container's port(s) to the host")
    var publish: [String] = []

    @Option(name: .shortAndLong, parsing: .singleValue, help: "Bind mount a volume")
    var volume: [String] = []

    @Option(name: .shortAndLong, parsing: .singleValue, help: "Set environment variables")
    var env: [String] = []

    @Option(name: .long, help: "Connect a container to a network")
    var network: String?

    @Option(name: .long, help: "Number of CPUs")
    var cpus: String?

    @Option(name: .shortAndLong, help: "Memory limit")
    var memory: String?

    // --- Positional arguments ---

    @Argument(help: "Container image to run")
    var image: String

    @Argument(parsing: .captureForPassthrough, help: "Command to run in the container")
    var command: [String] = []

    func run() throws {
        var args: [String] = ["run"]

        if detach { args.append("--detach") }
        if interactive { args.append("-i") }
        if tty { args.append("-t") }
        if rm { args.append("--rm") }

        if let name = name {
            args.append(contentsOf: ["--name", name])
        }

        for port in publish {
            args.append(contentsOf: ["--publish", port])
        }

        for vol in volume {
            // Translate Docker -v syntax to container --mount syntax
            let translated = FlagMapper.translateVolume(vol)
            args.append(contentsOf: translated)
        }

        for envVar in env {
            args.append(contentsOf: ["--env", envVar])
        }

        if let network = network {
            args.append(contentsOf: ["--network", network])
        }

        if let cpus = cpus {
            args.append(contentsOf: ["--cpus", cpus])
        }

        if let memory = memory {
            args.append(contentsOf: ["--memory", memory])
        }

        // Resolve short image references
        let resolvedImage = ImageRefResolver.resolve(image)
        args.append(resolvedImage)

        // Append any trailing command
        args.append(contentsOf: command)

        let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun, interactive: interactive || tty)
        throw ExitCode(exitCode)
    }
}

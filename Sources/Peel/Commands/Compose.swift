import ArgumentParser
import Foundation

struct Compose: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "compose",
        abstract: "Manage multi-container applications (translates to: container run/stop/rm)",
        subcommands: [ComposeUp.self, ComposeDown.self]
    )
}

// MARK: - compose up

struct ComposeUp: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "up",
        abstract: "Create and start containers for all services"
    )

    @Flag(name: .long, help: "Show the translated commands without executing them")
    var dryRun: Bool = false

    @Flag(name: .shortAndLong, help: "Detached mode (containers run in background)")
    var detach: Bool = false

    @Option(name: .shortAndLong, help: "Compose file path")
    var file: String?

    @Option(name: .shortAndLong, help: "Project name")
    var projectName: String?

    func run() throws {
        let composeFile: ComposeFile
        do {
            composeFile = try ComposeFileLoader.load(from: file)
        } catch {
            fputs("\(error)\n", stderr)
            throw ExitCode(1)
        }

        let project = projectName ?? ComposeFileLoader.deriveProjectName()

        if !detach {
            fputs("peel: running in detached mode (foreground log-following not yet supported)\n", stderr)
        }

        var failed = false
        for (serviceName, service) in composeFile.services.sorted(by: { $0.key < $1.key }) {
            let args: [String]
            do {
                args = try ServiceTranslator.translate(
                    service: service,
                    serviceName: serviceName,
                    projectName: project
                )
            } catch {
                fputs("\(error)\n", stderr)
                failed = true
                continue
            }

            let containerName = ServiceTranslator.containerName(
                service: service,
                serviceName: serviceName,
                projectName: project
            )
            fputs("peel: starting \(containerName)\n", stderr)

            let exitCode = ProcessRunner.execOrDryRun(args, dryRun: dryRun)
            if exitCode != 0 {
                fputs("peel: failed to start service '\(serviceName)'\n", stderr)
                failed = true
            }
        }

        if failed {
            throw ExitCode(1)
        }
    }
}

// MARK: - compose down

struct ComposeDown: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "down",
        abstract: "Stop and remove containers for all services"
    )

    @Flag(name: .long, help: "Show the translated commands without executing them")
    var dryRun: Bool = false

    @Option(name: .shortAndLong, help: "Compose file path")
    var file: String?

    @Option(name: .shortAndLong, help: "Project name")
    var projectName: String?

    func run() throws {
        let composeFile: ComposeFile
        do {
            composeFile = try ComposeFileLoader.load(from: file)
        } catch {
            fputs("\(error)\n", stderr)
            throw ExitCode(1)
        }

        let project = projectName ?? ComposeFileLoader.deriveProjectName()

        var failed = false
        for (serviceName, service) in composeFile.services.sorted(by: { $0.key < $1.key }) {
            let containerName = ServiceTranslator.containerName(
                service: service,
                serviceName: serviceName,
                projectName: project
            )

            if dryRun {
                let stopCmd = ([ProcessRunner.containerBinary, "stop", containerName]).joined(separator: " ")
                let rmCmd = ([ProcessRunner.containerBinary, "rm", containerName]).joined(separator: " ")
                print(stopCmd)
                print(rmCmd)
                continue
            }

            fputs("peel: stopping \(containerName)\n", stderr)
            let stopCode = ProcessRunner.execSilent(["stop", containerName])
            if stopCode != 0 {
                fputs("peel: warning: failed to stop '\(containerName)' (may not be running)\n", stderr)
            }

            fputs("peel: removing \(containerName)\n", stderr)
            let rmCode = ProcessRunner.execSilent(["rm", containerName])
            if rmCode != 0 {
                fputs("peel: warning: failed to remove '\(containerName)'\n", stderr)
                failed = true
            }
        }

        if failed {
            throw ExitCode(1)
        }
    }
}

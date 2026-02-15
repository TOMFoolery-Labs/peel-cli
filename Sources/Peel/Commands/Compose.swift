import ArgumentParser
import Foundation

struct Compose: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "compose",
        abstract: "Manage multi-container applications (translates to: container run/stop/rm)",
        subcommands: [ComposeUp.self, ComposeDown.self]
    )
}

// MARK: - Topological Sort

/// Sort service names in dependency-first order using Kahn's algorithm.
/// Returns services with no dependencies first, dependents last.
/// Falls back to alphabetical order if a cycle is detected.
func topologicalSort(services: [String: ComposeService]) -> [String] {
    // Build in-degree map and adjacency list
    var inDegree: [String: Int] = [:]
    var dependents: [String: [String]] = [:]  // dependency -> [services that depend on it]

    for name in services.keys {
        inDegree[name] = 0
    }

    for (name, service) in services {
        let deps = service.dependsOn ?? []
        for dep in deps {
            guard services[dep] != nil else { continue }  // skip unknown deps
            inDegree[name, default: 0] += 1
            dependents[dep, default: []].append(name)
        }
    }

    // Seed queue with services that have no dependencies (sorted for determinism)
    var queue = inDegree.filter { $0.value == 0 }.map(\.key).sorted()
    var result: [String] = []

    while !queue.isEmpty {
        let current = queue.removeFirst()
        result.append(current)

        for dependent in (dependents[current] ?? []).sorted() {
            inDegree[dependent, default: 0] -= 1
            if inDegree[dependent] == 0 {
                queue.append(dependent)
                queue.sort()  // maintain deterministic order
            }
        }
    }

    if result.count != services.count {
        // Cycle detected — fall back to alphabetical
        fputs("peel: warning: circular dependency detected in depends_on, falling back to alphabetical order\n", stderr)
        return services.keys.sorted()
    }

    return result
}

// MARK: - Network Helpers

/// Collect the network names that need to be created for a compose project.
/// Returns scoped names (e.g., "project_default").
func collectNetworks(composeFile: ComposeFile, projectName: String) -> [String] {
    if let topLevel = composeFile.networks {
        // Use explicitly declared networks
        return topLevel.keys.sorted().map { "\(projectName)_\($0)" }
    }

    // Check if any service references networks
    let hasServiceNetworks = composeFile.services.values.contains { service in
        service.networks != nil && !(service.networks!.isEmpty)
    }

    if hasServiceNetworks {
        return ["\(projectName)_default"]
    }

    return []
}

/// Determine the network name to pass to a service's container run command.
func networkForService(
    service: ComposeService,
    composeFile: ComposeFile,
    projectName: String
) -> String? {
    let networks = collectNetworks(composeFile: composeFile, projectName: projectName)
    guard !networks.isEmpty else { return nil }

    // If the service specifies networks, use the first one (scoped)
    if let serviceNets = service.networks, let first = serviceNets.first {
        return "\(projectName)_\(first)"
    }

    // Otherwise, attach to the first network (usually "default")
    return networks.first
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
        let orderedNames = topologicalSort(services: composeFile.services)
        let networks = collectNetworks(composeFile: composeFile, projectName: project)

        // Warn about unsupported keys
        for name in orderedNames {
            guard let service = composeFile.services[name] else { continue }
            for key in service.unsupportedKeys {
                fputs("peel: warning: service '\(name)' uses unsupported option '\(key)' (ignored)\n", stderr)
            }
        }

        // Create networks before starting services
        for network in networks {
            if dryRun {
                print("\(ProcessRunner.containerBinary) network create \(network)")
            } else {
                fputs("peel: creating network \(network)\n", stderr)
                ProcessRunner.execSilent(["network", "create", network])
            }
        }

        // Start services in dependency order
        var failed = false
        var startedContainers: [(name: String, serviceName: String)] = []

        for serviceName in orderedNames {
            guard let service = composeFile.services[serviceName] else { continue }

            let network = networkForService(
                service: service,
                composeFile: composeFile,
                projectName: project
            )

            let args: [String]
            do {
                args = try ServiceTranslator.translate(
                    service: service,
                    serviceName: serviceName,
                    projectName: project,
                    networkName: network
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
            } else {
                startedContainers.append((name: containerName, serviceName: serviceName))
            }
        }

        if failed {
            throw ExitCode(1)
        }

        // Foreground log-following mode (when -d is not set)
        if !detach && !dryRun {
            followLogs(containers: startedContainers, composeFile: composeFile, project: project, networks: networks)
        }
    }

    /// Tail logs from all started containers, interleaved with service name prefixes.
    /// Blocks until SIGINT, then tears down containers and networks.
    private func followLogs(
        containers: [(name: String, serviceName: String)],
        composeFile: ComposeFile,
        project: String,
        networks: [String]
    ) {
        guard !containers.isEmpty else { return }

        fputs("peel: attaching to logs (press Ctrl+C to stop)...\n", stderr)

        var logProcesses: [Process] = []

        // Compute max service name length for aligned padding
        let maxLen = containers.map(\.serviceName.count).max() ?? 0

        for (containerName, serviceName) in containers {
            guard let process = ProcessRunner.execStream(["logs", "--follow", containerName]) else {
                fputs("peel: warning: could not attach to logs for '\(serviceName)'\n", stderr)
                continue
            }

            logProcesses.append(process)

            let padded = serviceName.padding(toLength: maxLen, withPad: " ", startingAt: 0)
            let pipe = process.standardOutput as! Pipe

            // Read log output asynchronously and prefix each line
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                if let text = String(data: data, encoding: .utf8) {
                    for line in text.components(separatedBy: "\n") where !line.isEmpty {
                        fputs("\(padded)  | \(line)\n", stdout)
                        fflush(stdout)
                    }
                }
            }
        }

        // Wait for SIGINT
        let sigintReceived = DispatchSemaphore(value: 0)
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        signal(SIGINT, SIG_IGN)
        sigintSource.setEventHandler {
            sigintReceived.signal()
        }
        sigintSource.resume()

        sigintReceived.wait()
        sigintSource.cancel()
        signal(SIGINT, SIG_DFL)

        fputs("\npeel: gracefully stopping...\n", stderr)

        // Stop log processes
        for process in logProcesses {
            if process.isRunning { process.terminate() }
        }

        // Tear down: stop and remove containers in reverse order, then delete networks
        let orderedNames = topologicalSort(services: composeFile.services)
        for serviceName in orderedNames.reversed() {
            guard let service = composeFile.services[serviceName] else { continue }
            let containerName = ServiceTranslator.containerName(
                service: service,
                serviceName: serviceName,
                projectName: project
            )
            fputs("peel: stopping \(containerName)\n", stderr)
            ProcessRunner.execSilent(["stop", containerName])
            fputs("peel: removing \(containerName)\n", stderr)
            ProcessRunner.execSilent(["rm", containerName])
        }

        for network in networks {
            fputs("peel: removing network \(network)\n", stderr)
            ProcessRunner.execSilent(["network", "delete", network])
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
        let orderedNames = topologicalSort(services: composeFile.services)
        let networks = collectNetworks(composeFile: composeFile, projectName: project)

        // Stop and remove containers in reverse dependency order (dependents first)
        var failed = false
        for serviceName in orderedNames.reversed() {
            guard let service = composeFile.services[serviceName] else { continue }
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

        // Delete networks
        for network in networks {
            if dryRun {
                print("\(ProcessRunner.containerBinary) network delete \(network)")
            } else {
                fputs("peel: removing network \(network)\n", stderr)
                ProcessRunner.execSilent(["network", "delete", network])
            }
        }

        if failed {
            throw ExitCode(1)
        }
    }
}

import Foundation

/// Translates a compose service definition into `container run` arguments.
enum ServiceTranslator {

    /// Translate a compose service into arguments for `container run`.
    ///
    /// - Parameters:
    ///   - service: The compose service definition
    ///   - serviceName: The service key from the compose file
    ///   - projectName: The project name (used for container naming)
    ///   - networkName: Optional network name to attach the container to
    /// - Returns: Array of arguments to pass to `container run`
    /// - Throws: `ComposeError.missingImage` if the service has no image field
    static func translate(
        service: ComposeService,
        serviceName: String,
        projectName: String,
        networkName: String? = nil
    ) throws -> [String] {
        guard let image = service.image else {
            throw ComposeError.missingImage(serviceName)
        }

        var args: [String] = ["run", "--detach"]

        // Container name: explicit or derived from project-service-1
        let containerName = service.containerName ?? "\(projectName)-\(serviceName)-1"
        args.append(contentsOf: ["--name", containerName])

        // Ports
        if let ports = service.ports {
            for port in ports {
                args.append(contentsOf: ["--publish", port.publishString])
            }
        }

        // Volumes — reuse FlagMapper.translateVolume()
        if let volumes = service.volumes {
            for vol in volumes {
                let translated = FlagMapper.translateVolume(vol)
                args.append(contentsOf: translated)
            }
        }

        // Environment
        if let environment = service.environment {
            for entry in environment.entries {
                args.append(contentsOf: ["--env", entry])
            }
        }

        // Network
        if let network = networkName {
            args.append(contentsOf: ["--network", network])
        }

        // Image — resolve short references
        let resolvedImage = ImageRefResolver.resolve(image)
        args.append(resolvedImage)

        // Command
        if let command = service.command {
            args.append(contentsOf: command.arguments)
        }

        return args
    }

    /// Derive the container name for a service.
    static func containerName(
        service: ComposeService,
        serviceName: String,
        projectName: String
    ) -> String {
        service.containerName ?? "\(projectName)-\(serviceName)-1"
    }
}

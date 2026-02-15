import Foundation

/// Translates Docker CLI flags to Apple container CLI equivalents.
/// Designed to be table-driven for easy extension.
enum FlagMapper {

    /// Translate a Docker `-v` / `--volume` argument to Apple container mount syntax.
    ///
    /// Docker syntax:
    ///   - Bind mount: `-v /host/path:/container/path[:ro]`
    ///   - Named volume: `-v myvolume:/container/path`
    ///
    /// Apple container syntax:
    ///   - Bind mount: `--mount source=/host/path,target=/container/path`
    ///   - Named volume: `--volume myvolume:/container/path`
    ///
    /// - Parameter dockerVolume: The Docker-style volume string
    /// - Returns: Array of translated arguments
    static func translateVolume(_ dockerVolume: String) -> [String] {
        let parts = dockerVolume.split(separator: ":", maxSplits: 2).map(String.init)

        guard parts.count >= 2 else {
            // Single path — pass through as-is, let container handle the error
            return ["--volume", dockerVolume]
        }

        let source = parts[0]
        let target = parts[1]
        let options = parts.count > 2 ? parts[2] : nil

        // Determine if this is a bind mount (source starts with / or ./) or a named volume
        let isBindMount = source.hasPrefix("/") || source.hasPrefix("./") || source.hasPrefix("~")

        if isBindMount {
            var mountSpec = "source=\(source),target=\(target)"
            if let options = options {
                // Translate Docker options like "ro" to mount options
                if options.contains("ro") {
                    mountSpec += ",readonly"
                }
            }
            return ["--mount", mountSpec]
        } else {
            // Named volume — use --volume syntax
            var volumeSpec = "\(source):\(target)"
            if let options = options {
                volumeSpec += ":\(options)"
            }
            return ["--volume", volumeSpec]
        }
    }

    /// Map of Docker flag names to Apple container flag names.
    /// Only includes flags where the name actually differs.
    static let flagNameMap: [String: String] = [
        "-d": "--detach",
        "--publish-all": "--publish-all",  // may not exist in container
        // Most flags like --name, --rm, --env, --publish are identical
    ]

    /// Docker commands that map to different Apple container commands
    static let commandMap: [String: [String]] = [
        "ps":       ["ls"],
        "images":   ["image", "list"],
        "pull":     ["image", "pull"],
        "push":     ["image", "push"],
        "rmi":      ["image", "delete"],
        "login":    ["registry", "login"],
        "logout":   ["registry", "logout"],
        "info":     ["system", "status"],
    ]
}

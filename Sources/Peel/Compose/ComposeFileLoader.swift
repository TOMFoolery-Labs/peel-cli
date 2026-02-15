import Foundation
import Yams

/// Errors that can occur when loading a compose file.
enum ComposeError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case parseFailure(String, Error)
    case missingImage(String)

    var description: String {
        switch self {
        case .fileNotFound(let path):
            return "peel: compose file not found: \(path)\nTried: compose.yml, compose.yaml, docker-compose.yml, docker-compose.yaml"
        case .parseFailure(let path, let error):
            return "peel: failed to parse \(path): \(error)"
        case .missingImage(let service):
            return "peel: service '\(service)' has no 'image' field (build: directive is not yet supported)"
        }
    }
}

/// Handles discovering and parsing compose files.
enum ComposeFileLoader {

    /// Well-known compose file names in priority order.
    static let defaultFileNames = [
        "compose.yml",
        "compose.yaml",
        "docker-compose.yml",
        "docker-compose.yaml",
    ]

    /// Load a compose file from an explicit path or by searching the current directory.
    ///
    /// - Parameter explicitPath: An explicit file path, or nil to auto-discover
    /// - Returns: The parsed ComposeFile
    static func load(from explicitPath: String?) throws -> ComposeFile {
        let path: String
        if let explicitPath = explicitPath {
            path = explicitPath
        } else {
            guard let found = discoverFile() else {
                throw ComposeError.fileNotFound(FileManager.default.currentDirectoryPath)
            }
            path = found
        }

        guard FileManager.default.fileExists(atPath: path) else {
            throw ComposeError.fileNotFound(path)
        }

        let contents: String
        do {
            contents = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw ComposeError.fileNotFound(path)
        }

        return try parse(contents, path: path)
    }

    /// Parse YAML string into a ComposeFile.
    /// Variable interpolation is applied before decoding.
    static func parse(
        _ yaml: String,
        path: String = "<string>",
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ComposeFile {
        let interpolated = interpolateVariables(in: yaml, environment: environment)
        let decoder = YAMLDecoder()
        do {
            return try decoder.decode(ComposeFile.self, from: interpolated)
        } catch {
            throw ComposeError.parseFailure(path, error)
        }
    }

    /// Expand Docker Compose-style variable references in a string.
    ///
    /// Supported forms:
    ///   - `$VAR`            — value of VAR, or empty string if unset
    ///   - `${VAR}`          — same as $VAR
    ///   - `${VAR:-default}` — value of VAR, or "default" if unset or empty
    ///   - `${VAR-default}`  — value of VAR, or "default" if unset
    static func interpolateVariables(
        in string: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        // Process ${...} forms first (greedy, handles nested colons in defaults)
        // Then bare $VAR forms
        var result = string

        // Pattern: ${VAR:-default}, ${VAR-default}, ${VAR}
        let bracedPattern = #/\$\{([A-Za-z_][A-Za-z0-9_]*)(:-|-)([^}]*)\}|\$\{([A-Za-z_][A-Za-z0-9_]*)\}/#
        result = result.replacing(bracedPattern) { match in
            if let varName = match.output.4 {
                // ${VAR} — simple substitution
                return environment[String(varName)] ?? ""
            }

            let varName = String(match.output.1!)
            let op = String(match.output.2!)
            let defaultValue = String(match.output.3!)
            let envValue = environment[varName]

            if op == ":-" {
                // Use default if unset OR empty
                if let val = envValue, !val.isEmpty { return val }
                return defaultValue
            } else {
                // op == "-": use default only if unset
                if let val = envValue { return val }
                return defaultValue
            }
        }

        // Pattern: $VAR (bare, not followed by {)
        let barePattern = #/\$([A-Za-z_][A-Za-z0-9_]*)/#
        result = result.replacing(barePattern) { match in
            let varName = String(match.output.1)
            return environment[varName] ?? ""
        }

        return result
    }

    /// Derive a project name from the current working directory.
    /// Lowercased and stripped to [a-z0-9_-].
    static func deriveProjectName(from directory: String? = nil) -> String {
        let dir = directory ?? FileManager.default.currentDirectoryPath
        let baseName = URL(fileURLWithPath: dir).lastPathComponent.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_-")
        return String(baseName.unicodeScalars.filter { allowed.contains($0) })
    }

    /// Search the current directory for a compose file.
    private static func discoverFile() -> String? {
        let cwd = FileManager.default.currentDirectoryPath
        for name in defaultFileNames {
            let path = (cwd as NSString).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}

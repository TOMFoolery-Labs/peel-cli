import Foundation

/// Top-level representation of a Docker Compose file.
struct ComposeFile: Decodable {
    let services: [String: ComposeService]
}

/// A single service definition within a compose file.
struct ComposeService: Decodable {
    let image: String?
    let command: ComposeCommand?
    let containerName: String?
    let ports: [ComposePort]?
    let volumes: [String]?
    let environment: ComposeEnvironment?
    let restart: String?  // Parsed but ignored

    enum CodingKeys: String, CodingKey {
        case image
        case command
        case containerName = "container_name"
        case ports
        case volumes
        case environment
        case restart
    }
}

/// Command that can be either a string ("cmd arg1 arg2") or an array (["cmd", "arg1"]).
enum ComposeCommand: Decodable, Equatable {
    case string(String)
    case array([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            throw DecodingError.typeMismatch(
                ComposeCommand.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "command must be a string or array of strings"
                )
            )
        }
    }

    /// Returns the command split into arguments.
    var arguments: [String] {
        switch self {
        case .string(let s):
            return s.split(separator: " ").map(String.init)
        case .array(let a):
            return a
        }
    }
}

/// Port mapping that can be a string ("8080:80") or an integer (80).
enum ComposePort: Decodable, Equatable {
    case string(String)
    case integer(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            self = .integer(int)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            throw DecodingError.typeMismatch(
                ComposePort.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "port must be a string or integer"
                )
            )
        }
    }

    /// Returns the port mapping as a string suitable for --publish.
    var publishString: String {
        switch self {
        case .string(let s): return s
        case .integer(let i): return "\(i):\(i)"
        }
    }
}

/// Environment variables that can be a map ({KEY: val}) or a list (["KEY=val"]).
enum ComposeEnvironment: Decodable, Equatable {
    case map([String: String?])
    case list([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let list = try? container.decode([String].self) {
            self = .list(list)
        } else if let map = try? container.decode([String: String?].self) {
            self = .map(map)
        } else {
            throw DecodingError.typeMismatch(
                ComposeEnvironment.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "environment must be a map or list of strings"
                )
            )
        }
    }

    /// Returns environment entries as "KEY=VALUE" strings.
    var entries: [String] {
        switch self {
        case .map(let m):
            return m.sorted(by: { $0.key < $1.key }).compactMap { key, value in
                if let value = value {
                    return "\(key)=\(value)"
                }
                return "\(key)="
            }
        case .list(let l):
            return l
        }
    }
}

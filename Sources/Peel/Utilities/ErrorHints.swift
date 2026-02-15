import Foundation

/// Provides Docker-familiar hints when Apple container commands fail.
enum ErrorHints {

    /// Returns an optional hint string based on the command that was run.
    /// Called after a non-zero exit code to help users with Docker-familiar guidance.
    static func hint(for arguments: [String]) -> String? {
        guard let command = arguments.first else { return nil }

        switch command {
        case "run":
            return "Hint: use 'peel ps -a' to check for name conflicts, or 'peel pull IMAGE' to ensure the image exists."
        case "image":
            if arguments.count > 1 && arguments[1] == "pull" {
                return "Hint: ensure the image reference is correct (e.g., 'nginx' or 'docker.io/library/nginx:latest')."
            }
            if arguments.count > 1 && arguments[1] == "delete" {
                return "Hint: use 'peel images' to list available images. The image may be in use by a container."
            }
            return nil
        case "stop":
            return "Hint: use 'peel ps' to list running containers."
        case "delete":
            return "Hint: use 'peel ps -a' to list all containers. Use 'peel rm -f' to force removal."
        case "exec":
            return "Hint: use 'peel ps' to check the container is running."
        case "build":
            return "Hint: ensure you are in the correct directory and a Dockerfile exists."
        case "network":
            return "Hint: use 'peel network ls' to list existing networks."
        case "volume":
            return "Hint: use 'peel volume ls' to list existing volumes."
        default:
            return nil
        }
    }
}

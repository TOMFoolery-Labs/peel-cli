import Foundation

/// Resolves short Docker-style image references to fully qualified OCI references.
///
/// Docker allows shorthand like `nginx` or `alpine:latest` which implicitly
/// means `docker.io/library/nginx:latest`. Apple's container CLI may need
/// the full reference depending on the configured default registry.
enum ImageRefResolver {

    /// The default registry when none is specified
    static let defaultRegistry = "docker.io"

    /// The default namespace for official images on Docker Hub
    static let defaultNamespace = "library"

    /// The default tag when none is specified
    static let defaultTag = "latest"

    /// Resolve a potentially short image reference to a fully qualified one.
    ///
    /// Examples:
    ///   - `nginx`                → `docker.io/library/nginx:latest`
    ///   - `nginx:alpine`         → `docker.io/library/nginx:alpine`
    ///   - `myuser/myapp`         → `docker.io/myuser/myapp:latest`
    ///   - `myuser/myapp:v1`      → `docker.io/myuser/myapp:v1`
    ///   - `ghcr.io/org/app:v2`   → `ghcr.io/org/app:v2` (already qualified)
    ///
    /// - Parameter ref: The Docker-style image reference
    /// - Returns: A fully qualified image reference
    static func resolve(_ ref: String) -> String {
        // If it already contains a registry domain (has a dot in the host part of the first segment), pass through
        let firstSegment = ref.split(separator: "/").first.map(String.init) ?? ref
        let hostPart = firstSegment.split(separator: ":").first.map(String.init) ?? firstSegment
        if hostPart.contains(".") {
            // Already fully qualified (e.g., ghcr.io/..., registry.example.com/...)
            return ensureTag(ref)
        }

        // Check if there's a namespace (contains a slash)
        if ref.contains("/") {
            // Has namespace but no registry: myuser/myapp → docker.io/myuser/myapp
            return ensureTag("\(defaultRegistry)/\(ref)")
        }

        // Bare image name: nginx → docker.io/library/nginx
        return ensureTag("\(defaultRegistry)/\(defaultNamespace)/\(ref)")
    }

    /// Ensure the reference has a tag. If no tag is specified, append :latest
    private static func ensureTag(_ ref: String) -> String {
        // Split off the last path component and check for a tag
        let components = ref.split(separator: "/")
        guard let last = components.last else { return ref }

        if last.contains(":") {
            return ref // Already has a tag
        }

        return "\(ref):\(defaultTag)"
    }
}

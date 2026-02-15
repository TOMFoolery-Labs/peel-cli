import Testing
@testable import peel

// MARK: - YAML Parsing Tests

@Test func parseMinimalComposeFile() throws {
    let yaml = """
    services:
      web:
        image: nginx
    """
    let compose = try ComposeFileLoader.parse(yaml)
    #expect(compose.services.count == 1)
    #expect(compose.services["web"]?.image == "nginx")
}

@Test func parseEnvironmentAsMap() throws {
    let yaml = """
    services:
      app:
        image: myapp
        environment:
          FOO: bar
          BAZ: qux
    """
    let compose = try ComposeFileLoader.parse(yaml)
    let env = compose.services["app"]?.environment
    #expect(env == .map(["FOO": "bar", "BAZ": "qux"]))
    #expect(env?.entries.contains("FOO=bar") == true)
    #expect(env?.entries.contains("BAZ=qux") == true)
}

@Test func parseEnvironmentAsList() throws {
    let yaml = """
    services:
      app:
        image: myapp
        environment:
          - FOO=bar
          - BAZ=qux
    """
    let compose = try ComposeFileLoader.parse(yaml)
    let env = compose.services["app"]?.environment
    #expect(env == .list(["FOO=bar", "BAZ=qux"]))
    #expect(env?.entries == ["FOO=bar", "BAZ=qux"])
}

@Test func parseCommandAsString() throws {
    let yaml = """
    services:
      app:
        image: myapp
        command: "python app.py --debug"
    """
    let compose = try ComposeFileLoader.parse(yaml)
    let cmd = compose.services["app"]?.command
    #expect(cmd == .string("python app.py --debug"))
    #expect(cmd?.arguments == ["python", "app.py", "--debug"])
}

@Test func parseCommandAsArray() throws {
    let yaml = """
    services:
      app:
        image: myapp
        command: ["python", "app.py", "--debug"]
    """
    let compose = try ComposeFileLoader.parse(yaml)
    let cmd = compose.services["app"]?.command
    #expect(cmd == .array(["python", "app.py", "--debug"]))
    #expect(cmd?.arguments == ["python", "app.py", "--debug"])
}

@Test func parsePortAsString() throws {
    let yaml = """
    services:
      web:
        image: nginx
        ports:
          - "8080:80"
    """
    let compose = try ComposeFileLoader.parse(yaml)
    let ports = compose.services["web"]?.ports
    #expect(ports == [.string("8080:80")])
    #expect(ports?.first?.publishString == "8080:80")
}

@Test func parsePortAsInteger() throws {
    let yaml = """
    services:
      web:
        image: nginx
        ports:
          - 80
    """
    let compose = try ComposeFileLoader.parse(yaml)
    let ports = compose.services["web"]?.ports
    #expect(ports == [.integer(80)])
    #expect(ports?.first?.publishString == "80:80")
}

@Test func parseContainerName() throws {
    let yaml = """
    services:
      db:
        image: postgres
        container_name: my-postgres
    """
    let compose = try ComposeFileLoader.parse(yaml)
    #expect(compose.services["db"]?.containerName == "my-postgres")
}

@Test func parseRestartIgnored() throws {
    let yaml = """
    services:
      web:
        image: nginx
        restart: always
    """
    let compose = try ComposeFileLoader.parse(yaml)
    #expect(compose.services["web"]?.restart == "always")
}

@Test func parseVolumes() throws {
    let yaml = """
    services:
      app:
        image: myapp
        volumes:
          - ./src:/app/src
          - data:/var/data
    """
    let compose = try ComposeFileLoader.parse(yaml)
    #expect(compose.services["app"]?.volumes == ["./src:/app/src", "data:/var/data"])
}

// MARK: - Variable Interpolation Tests

@Test func interpolateBracedVarWithDefault() {
    let input = "image: myapp:${TAG:-latest}"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: [:])
    #expect(result == "image: myapp:latest")
}

@Test func interpolateBracedVarWithDefaultOverriddenByEnv() {
    let input = "image: myapp:${TAG:-latest}"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: ["TAG": "v2"])
    #expect(result == "image: myapp:v2")
}

@Test func interpolateBracedVarEmptyUsesDefault() {
    // :- means use default if unset OR empty
    let input = "port: ${PORT:-3000}"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: ["PORT": ""])
    #expect(result == "port: 3000")
}

@Test func interpolateBracedVarDashOnlyEmptyKeepsEmpty() {
    // - (without colon) means use default only if unset, not if empty
    let input = "port: ${PORT-3000}"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: ["PORT": ""])
    #expect(result == "port: ")
}

@Test func interpolateBracedVarDashOnlyUnsetUsesDefault() {
    let input = "port: ${PORT-3000}"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: [:])
    #expect(result == "port: 3000")
}

@Test func interpolateSimpleBracedVar() {
    let input = "image: ${IMAGE}"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: ["IMAGE": "nginx"])
    #expect(result == "image: nginx")
}

@Test func interpolateSimpleBracedVarUnset() {
    let input = "image: ${IMAGE}"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: [:])
    #expect(result == "image: ")
}

@Test func interpolateBareVar() {
    let input = "image: $IMAGE"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: ["IMAGE": "nginx"])
    #expect(result == "image: nginx")
}

@Test func interpolateBareVarUnset() {
    let input = "image: $IMAGE"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: [:])
    #expect(result == "image: ")
}

@Test func interpolateMultipleVarsInOneLine() {
    let input = "${HOST:-localhost}:${PORT:-8080}"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: [:])
    #expect(result == "localhost:8080")
}

@Test func interpolateNoVarsUnchanged() {
    let input = "image: nginx:latest"
    let result = ComposeFileLoader.interpolateVariables(in: input, environment: [:])
    #expect(result == "image: nginx:latest")
}

@Test func parseComposeFileWithVariableInterpolation() throws {
    let yaml = """
    services:
      app:
        image: myapp:${TAG:-latest}
        ports:
          - "${PORT:-3000}:3000"
    """
    let compose = try ComposeFileLoader.parse(yaml, environment: [:])
    #expect(compose.services["app"]?.image == "myapp:latest")
    #expect(compose.services["app"]?.ports == [.string("3000:3000")])
}

@Test func parseComposeFileWithEnvOverrides() throws {
    let yaml = """
    services:
      app:
        image: myapp:${TAG:-latest}
        ports:
          - "${PORT:-3000}:3000"
    """
    let compose = try ComposeFileLoader.parse(
        yaml,
        environment: ["TAG": "v2", "PORT": "8080"]
    )
    #expect(compose.services["app"]?.image == "myapp:v2")
    #expect(compose.services["app"]?.ports == [.string("8080:3000")])
}

// MARK: - ServiceTranslator Tests

@Test func translateSimpleService() throws {
    let service = ComposeService(
        image: "nginx",
        command: nil,
        containerName: nil,
        ports: [.string("8080:80")],
        volumes: nil,
        environment: nil,
        restart: nil
    )
    let args = try ServiceTranslator.translate(
        service: service,
        serviceName: "web",
        projectName: "myproject"
    )
    #expect(args == [
        "run", "--detach",
        "--name", "myproject-web-1",
        "--publish", "8080:80",
        "docker.io/library/nginx:latest",
    ])
}

@Test func translateServiceWithVolumes() throws {
    let service = ComposeService(
        image: "myapp",
        command: nil,
        containerName: nil,
        ports: nil,
        volumes: ["./src:/app/src", "data:/var/data"],
        environment: nil,
        restart: nil
    )
    let args = try ServiceTranslator.translate(
        service: service,
        serviceName: "app",
        projectName: "proj"
    )
    #expect(args.contains("--mount"))
    #expect(args.contains("source=./src,target=/app/src"))
    #expect(args.contains("--volume"))
    #expect(args.contains("data:/var/data"))
}

@Test func translateServiceWithEnvironment() throws {
    let service = ComposeService(
        image: "myapp",
        command: nil,
        containerName: nil,
        ports: nil,
        volumes: nil,
        environment: .list(["FOO=bar", "BAZ=qux"]),
        restart: nil
    )
    let args = try ServiceTranslator.translate(
        service: service,
        serviceName: "app",
        projectName: "proj"
    )
    #expect(args.contains("--env"))
    #expect(args.contains("FOO=bar"))
    #expect(args.contains("BAZ=qux"))
}

@Test func translateServiceMissingImage() throws {
    let service = ComposeService(
        image: nil,
        command: nil,
        containerName: nil,
        ports: nil,
        volumes: nil,
        environment: nil,
        restart: nil
    )
    #expect(throws: (any Error).self) {
        _ = try ServiceTranslator.translate(
            service: service,
            serviceName: "broken",
            projectName: "proj"
        )
    }
}

@Test func translateServiceExplicitContainerName() throws {
    let service = ComposeService(
        image: "postgres",
        command: nil,
        containerName: "my-db",
        ports: nil,
        volumes: nil,
        environment: nil,
        restart: nil
    )
    let args = try ServiceTranslator.translate(
        service: service,
        serviceName: "db",
        projectName: "proj"
    )
    #expect(args.contains("my-db"))
    #expect(!args.contains("proj-db-1"))
}

@Test func translateServiceCommandOrdering() throws {
    let service = ComposeService(
        image: "python",
        command: .array(["python", "app.py"]),
        containerName: nil,
        ports: nil,
        volumes: nil,
        environment: nil,
        restart: nil
    )
    let args = try ServiceTranslator.translate(
        service: service,
        serviceName: "app",
        projectName: "proj"
    )
    // Image must come before command args
    let imageIndex = args.firstIndex(of: "docker.io/library/python:latest")!
    let cmdIndex = args.firstIndex(of: "python")!
    #expect(imageIndex < cmdIndex)
    #expect(args.last == "app.py")
}

// MARK: - Project Name Derivation

@Test func deriveProjectNameSimple() {
    let name = ComposeFileLoader.deriveProjectName(from: "/Users/dev/my-project")
    #expect(name == "my-project")
}

@Test func deriveProjectNameStripsInvalidChars() {
    let name = ComposeFileLoader.deriveProjectName(from: "/Users/dev/My Project (v2)")
    #expect(name == "myprojectv2")
}

// MARK: - Unsupported Key Detection Tests

@Test func detectUnsupportedKeys() throws {
    let yaml = """
    services:
      web:
        image: nginx
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost"]
          interval: 10s
        deploy:
          replicas: 3
    """
    let compose = try ComposeFileLoader.parse(yaml)
    #expect(compose.services["web"]?.unsupportedKeys == ["deploy", "healthcheck"])
}

@Test func noUnsupportedKeys() throws {
    let yaml = """
    services:
      web:
        image: nginx
        ports:
          - "8080:80"
        environment:
          - FOO=bar
    """
    let compose = try ComposeFileLoader.parse(yaml)
    #expect(compose.services["web"]?.unsupportedKeys == [])
}

// MARK: - depends_on Parsing Tests

@Test func parseDependsOnShortForm() throws {
    let yaml = """
    services:
      web:
        image: nginx
        depends_on:
          - db
          - redis
      db:
        image: postgres
      redis:
        image: redis
    """
    let compose = try ComposeFileLoader.parse(yaml)
    #expect(compose.services["web"]?.dependsOn == ["db", "redis"])
    #expect(compose.services["db"]?.dependsOn == nil)
}

@Test func parseDependsOnLongForm() throws {
    let yaml = """
    services:
      web:
        image: nginx
        depends_on:
          db:
            condition: service_started
          redis:
            condition: service_healthy
      db:
        image: postgres
      redis:
        image: redis
    """
    let compose = try ComposeFileLoader.parse(yaml)
    // Long form extracts just the service names, sorted
    #expect(compose.services["web"]?.dependsOn == ["db", "redis"])
}

// MARK: - Network Parsing Tests

@Test func parseNetworks() throws {
    let yaml = """
    services:
      web:
        image: nginx
        networks:
          - frontend
      api:
        image: myapi
        networks:
          - frontend
          - backend
    networks:
      frontend:
      backend:
        driver: bridge
    """
    let compose = try ComposeFileLoader.parse(yaml)
    #expect(compose.services["web"]?.networks == ["frontend"])
    #expect(compose.services["api"]?.networks == ["frontend", "backend"])
    #expect(compose.networks?.keys.sorted() == ["backend", "frontend"])
}

@Test func parseNoNetworks() throws {
    let yaml = """
    services:
      web:
        image: nginx
    """
    let compose = try ComposeFileLoader.parse(yaml)
    #expect(compose.networks == nil)
    #expect(compose.services["web"]?.networks == nil)
}

// MARK: - Topological Sort Tests

@Test func topologicalSortLinear() {
    // A depends on B, B depends on C → [C, B, A]
    let services: [String: ComposeService] = [
        "a": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil, dependsOn: ["b"]),
        "b": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil, dependsOn: ["c"]),
        "c": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil),
    ]
    let order = topologicalSort(services: services)
    #expect(order == ["c", "b", "a"])
}

@Test func topologicalSortDiamond() {
    // A depends on B and C; B and C both depend on D → D first, A last
    let services: [String: ComposeService] = [
        "a": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil, dependsOn: ["b", "c"]),
        "b": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil, dependsOn: ["d"]),
        "c": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil, dependsOn: ["d"]),
        "d": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil),
    ]
    let order = topologicalSort(services: services)
    #expect(order.first == "d")
    #expect(order.last == "a")
    // B and C can be in either order, but both must come after D and before A
    let bIdx = order.firstIndex(of: "b")!
    let cIdx = order.firstIndex(of: "c")!
    let dIdx = order.firstIndex(of: "d")!
    let aIdx = order.firstIndex(of: "a")!
    #expect(dIdx < bIdx)
    #expect(dIdx < cIdx)
    #expect(bIdx < aIdx)
    #expect(cIdx < aIdx)
}

@Test func topologicalSortCycleFallback() {
    // A depends on B, B depends on A → cycle → falls back to alphabetical
    let services: [String: ComposeService] = [
        "a": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil, dependsOn: ["b"]),
        "b": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil, dependsOn: ["a"]),
    ]
    let order = topologicalSort(services: services)
    #expect(order == ["a", "b"])
}

@Test func topologicalSortNoDependencies() {
    // No dependencies → alphabetical
    let services: [String: ComposeService] = [
        "z": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil),
        "a": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil),
        "m": ComposeService(image: "img", command: nil, containerName: nil, ports: nil,
                            volumes: nil, environment: nil, restart: nil),
    ]
    let order = topologicalSort(services: services)
    #expect(order == ["a", "m", "z"])
}

// MARK: - ServiceTranslator with Network

@Test func translateServiceWithNetwork() throws {
    let service = ComposeService(
        image: "nginx",
        command: nil,
        containerName: nil,
        ports: [.string("8080:80")],
        volumes: nil,
        environment: nil,
        restart: nil
    )
    let args = try ServiceTranslator.translate(
        service: service,
        serviceName: "web",
        projectName: "myproject",
        networkName: "myproject_default"
    )
    // --network should appear before the image
    let networkIdx = args.firstIndex(of: "--network")!
    let networkNameIdx = args.firstIndex(of: "myproject_default")!
    let imageIdx = args.firstIndex(of: "docker.io/library/nginx:latest")!
    #expect(networkIdx + 1 == networkNameIdx)
    #expect(networkNameIdx < imageIdx)
}

@Test func translateServiceWithoutNetwork() throws {
    let service = ComposeService(
        image: "nginx",
        command: nil,
        containerName: nil,
        ports: nil,
        volumes: nil,
        environment: nil,
        restart: nil
    )
    let args = try ServiceTranslator.translate(
        service: service,
        serviceName: "web",
        projectName: "proj"
    )
    #expect(!args.contains("--network"))
}

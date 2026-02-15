# CLAUDE.md — Project Instructions for Claude Code

## Project Overview

**Peel** is a Docker-compatible CLI shim for Apple's native `container` tool. It translates Docker CLI commands and flags into their Apple `container` equivalents, then executes them. The goal is to let developers use their existing Docker muscle memory, scripts, and Makefiles with Apple Containers without modification.

## Tech Stack

- **Language**: Swift 5.9+
- **CLI Framework**: [swift-argument-parser](https://github.com/apple/swift-argument-parser)
- **Target Platform**: macOS 26+ (Apple Silicon only)
- **Dependency**: Apple `container` CLI must be installed at `/usr/local/bin/container`

## Architecture Principles

1. **Peel is a thin translation layer, not a container runtime.** It should never manage containers, images, or state directly. It translates commands and delegates everything to Apple's `container` CLI.

2. **Stateless execution.** Every `peel` invocation is independent. No daemon, no background process, no database, no config files required (optional config is fine for preferences).

3. **Transparent passthrough.** Stdout, stderr, and exit codes from the underlying `container` command must pass through to the user unmodified. Peel should be invisible when things work.

4. **Fail helpfully.** When translation fails or an unsupported Docker feature is used, give a clear error message explaining what's not supported and suggest alternatives.

## Key Design Decisions

### Command Routing

Use swift-argument-parser to define subcommands that mirror Docker's CLI structure. Each subcommand (run, ps, build, etc.) is its own Swift file in `Sources/Peel/Commands/`.

The top-level `Peel` command should use `CommandConfiguration` with subcommands. Unknown/unrecognized commands should attempt passthrough to `container` directly as a fallback.

### Flag Translation

Docker and Apple's `container` CLI share many flags but with differences:
- `docker ps` → `container ls` (command name differs)
- `docker ps -a` → `container ls --all` (flag name differs)
- `-d` (docker) → `--detach` (container uses long form)
- `-p 8080:80` → `--publish 8080:80` (same semantics, different flag name in some contexts)
- `-v /host:/container` → `--mount source=/host,target=/container` (different volume syntax)
- `docker rmi` → `container image delete` (completely different command structure)

The `FlagMapper` in `Sources/Peel/Translate/` handles these translations. It should be table-driven so new mappings are easy to add.

### Image Reference Resolution

Docker allows short image references like `nginx` or `alpine:latest`. Apple's container CLI typically expects fully qualified references like `docker.io/library/nginx:latest`. The `ImageRefResolver` should expand short references when needed.

## Command Translation Reference

This is the core mapping that Peel implements:

```
# Container lifecycle
docker run [flags] IMAGE [CMD]     → container run [translated-flags] IMAGE [CMD]
docker ps                          → container ls (filtered to running)
docker ps -a                       → container ls --all
docker stop CONTAINER              → container stop CONTAINER
docker rm CONTAINER                → container rm CONTAINER
docker start CONTAINER             → container start CONTAINER

# Images
docker images                      → container image list
docker pull IMAGE                  → container image pull IMAGE
docker rmi IMAGE                   → container image delete IMAGE
docker push IMAGE                  → container image push IMAGE
docker build -t TAG .              → container build --tag TAG .

# Inspection & logs
docker logs CONTAINER              → container logs CONTAINER
docker inspect CONTAINER           → container inspect CONTAINER
docker stats                       → container stats
docker exec CONTAINER CMD          → container exec CONTAINER CMD

# Registry
docker login                       → container registry login

# Network
docker network ls                  → container network list
docker network create NAME         → container network create NAME
docker network rm NAME             → container network delete NAME

# Volumes
docker volume ls                   → container volume list
docker volume create NAME          → container volume create NAME
docker volume rm NAME              → container volume delete NAME

# System
docker system prune                → (no direct equivalent — implement as multi-step)
docker info                        → container system status
```

## Flag Translation Table

```
Docker Flag              → container Flag            Notes
-d, --detach            → --detach                  Same semantics
-it                     → -t -i                     Split interactive+tty
-p, --publish           → --publish                 Same format HOST:CONTAINER
-v, --volume            → --mount                   Syntax differs (see below)
--name                  → --name                    Same
--rm                    → --rm                      Same
-e, --env               → --env                     Same
--network               → --network                 Same
--cpus                  → --cpus                    Same
--memory                → --memory                  Same
-f, --file (build)      → --file                    Same
-t, --tag (build)       → --tag                     Same
```

### Volume Syntax Translation
```
Docker:    -v /host/path:/container/path
Container: --mount source=/host/path,target=/container/path

Docker:    -v myvolume:/container/path
Container: --volume myvolume:/container/path
```

## Process Execution

Use Swift's `Process` class to execute the translated command:

```swift
// ProcessRunner.swift should handle:
// 1. Building the argument array
// 2. Setting up stdout/stderr pipe passthrough
// 3. Launching the process
// 4. Waiting for completion
// 5. Returning the exit code
```

Important: Use `execvp` or similar for direct process replacement when possible, so that signal handling (Ctrl+C, etc.) passes through correctly to the container process. For interactive commands (`-it`), the TTY must be forwarded properly.

## Testing Strategy

- **Unit tests** for command translation: Given Docker args, assert correct container args
- **Unit tests** for flag mapping: Each flag translation should have test coverage
- **Unit tests** for image reference resolution: Short refs → fully qualified refs
- **Integration tests** (manual): Run actual Docker commands through peel and verify behavior

Example test:
```swift
func testRunTranslation() {
    let docker = ["run", "-d", "-p", "8080:80", "--name", "web", "nginx"]
    let expected = ["container", "run", "--detach", "--publish", "8080:80", "--name", "web", "docker.io/library/nginx:latest"]
    XCTAssertEqual(translate(docker), expected)
}
```

## `peel doctor` Command

Implement a `peel doctor` subcommand that checks:
1. Is Apple `container` CLI installed? (Check `/usr/local/bin/container`)
2. Is the container system running? (`container system status`)
3. Is this an Apple Silicon Mac?
4. Is macOS version sufficient? (26+)
5. Print a summary with ✅/❌ for each check

## Error Handling

When Apple's `container` returns an error, Peel should:
1. Pass through the original error message
2. If possible, add a hint about the Docker equivalent behavior
3. For unsupported features, clearly state: "This Docker feature is not yet supported by Apple Containers"

## Code Style

- Use Swift naming conventions (camelCase for functions/variables, PascalCase for types)
- Keep each command implementation focused and small
- Use protocols for testability (e.g., `ProcessRunning` protocol so tests can mock execution)
- Prefer value types (structs) over reference types (classes) where possible
- Add doc comments to all public interfaces

## Build & Run

```bash
# Build
swift build

# Build release
swift build -c release

# Run
swift run peel --help

# Test
swift test

# Install locally
cp .build/release/peel /usr/local/bin/peel
```

## MVP Scope (v0.1)

Focus on these commands first:
1. `peel run` (with -d, -p, --name, --rm, -e, -it flags)
2. `peel ps` / `peel ps -a`
3. `peel images`
4. `peel pull`
5. `peel build` (with -t, -f flags)
6. `peel stop`
7. `peel rm`
8. `peel doctor`

Everything else can be "not yet supported" with a helpful message.

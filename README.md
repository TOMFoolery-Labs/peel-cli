# 🍎 Peel

**Docker-compatible CLI for Apple Containers**

Peel is a drop-in shim that translates Docker CLI commands into Apple's native `container` CLI, letting you use your existing Docker muscle memory, scripts, Makefiles, and CI configs with Apple's high-performance container runtime on macOS.

> *The thin layer between you and the Apple core.*

## Why Peel?

Apple's [container](https://github.com/apple/container) tool runs OCI-compatible Linux containers natively on macOS using lightweight per-container VMs via Virtualization.framework. It's fast, secure, and optimized for Apple Silicon — but the CLI isn't Docker-compatible. Your existing workflows, scripts, and muscle memory break.

Peel bridges that gap:

- **Drop-in replacement**: Alias `docker` to `peel` and your existing commands just work
- **Zero overhead**: Thin translation layer — no daemon, no VM, just command mapping
- **Script-compatible**: Makefiles, shell scripts, and local dev configs work without modification
- **Native Swift**: Built in Swift, same as Apple's container tool itself
- **Compose support**: Parse `docker-compose.yml` and orchestrate via Apple Containers

## Requirements

- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 26 (Tahoe) or later
- [Apple container CLI](https://github.com/apple/container) installed and running (`container system start`)
- Swift 5.9+ (for building from source)

## Installation

```bash
# Homebrew (recommended)
brew install tomfoolery-labs/tap/peel

# From source
git clone https://github.com/tomfoolery-labs/peel-cli.git
cd peel-cli
swift build -c release
cp .build/release/peel /usr/local/bin/peel

# Optional: alias docker to peel
echo 'alias docker=peel' >> ~/.zshrc
```

## Quick Start

```bash
# All of these work exactly like Docker
peel pull alpine:latest
peel run -it alpine:latest sh
peel ps
peel images
peel build -t myapp .
peel stop my-container
peel rm my-container

# Preview translated commands without executing
peel run --dry-run -d -p 8080:80 nginx
# → /opt/homebrew/bin/container run --detach --publish 8080:80 docker.io/library/nginx:latest
```

## Command Mapping

Peel translates Docker CLI commands to their Apple `container` equivalents:

| Docker Command | Peel Translation | Notes |
|---|---|---|
| `docker run` | `container run` | Flag translation for `-d`, `-p`, `-v`, `-it`, etc. |
| `docker ps` | `container ls` | |
| `docker ps -a` | `container ls --all` | |
| `docker images` | `container image list` | |
| `docker pull` | `container image pull` | Auto-expands short refs (e.g. `nginx` → `docker.io/library/nginx:latest`) |
| `docker build` | `container build` | |
| `docker stop` | `container stop` | |
| `docker rm` | `container delete` | |
| `docker rmi` | `container image delete` | |
| `docker logs` | `container logs` | |
| `docker exec` | `container exec` | |
| `docker inspect` | `container inspect` | |
| `docker push` | `container image push` | |
| `docker login` | `container registry login` | |
| `docker stats` | `container stats` | |
| `docker network ls` | `container network list` | |
| `docker network create` | `container network create` | |
| `docker network rm` | `container network delete` | |
| `docker volume ls` | `container volume list` | |
| `docker volume create` | `container volume create` | |
| `docker volume rm` | `container volume delete` | |
| `docker compose up` | `container run` (per service) | Parses docker-compose.yml |
| `docker compose down` | `container stop` + `rm` (per service) | |

## How It Works

Peel operates as a simple translation layer:

1. **Parse** the incoming Docker CLI command and flags
2. **Translate** the command to the equivalent Apple `container` command
3. **Execute** the translated command — interactive commands (`-it`) use `execvp` for direct TTY passthrough, non-interactive use Swift's `Process`
4. **Pass through** stdout, stderr, and exit codes transparently

There is no daemon, no background process, and no state management. Peel is stateless and disposable.

## Differences from Docker

Apple Containers use lightweight per-container VMs via Virtualization.framework, not Linux namespaces/cgroups. This means some things behave differently than Docker:

### Volumes

- **Bind mounts work**, but the host directory must exist before running the container. Docker creates missing host directories automatically; Apple Containers does not.
  ```bash
  mkdir -p /tmp/mydata
  peel run -v /tmp/mydata:/data debian:testing ls /data   # works
  peel run -v /tmp/missing:/data debian:testing ls /data   # errors
  ```
- **File mounts are not supported** — Apple Containers can only mount directories, not individual files. Peel detects file mounts and automatically mounts the parent directory instead, with a warning. For example, `-v ./config/app.yml:/etc/app.yml` becomes a mount of `./config` at `/etc`.
- **Named volumes** can be created and listed (`peel volume create`, `peel volume ls`) but cannot currently be mounted into containers with `container run`. This is an upstream Apple Containers limitation.

### Container IDs

Apple Containers uses UUIDs as container IDs (e.g. `ad84b641-aa56-4537-a2df-712e2977751e`) rather than Docker's short hex IDs. Use `--name` to give containers human-readable names.

### Networking

Each container runs in its own lightweight VM. Container networking works differently than Docker's bridge networking — containers are isolated by default at the VM level.

### Image References

Peel automatically expands short image names for you (`nginx` becomes `docker.io/library/nginx:latest`), matching Docker's behavior. Apple's `container` CLI typically requires fully qualified references.

### No Daemon

There is no equivalent to the Docker daemon. Apple's `container` CLI is stateless. You do need to run `container system start` once after boot (check with `peel doctor`).

## Architecture

```
┌──────────────────────────────────────────────────┐
│  User types: peel run -d -p 8080:80 nginx        │
└──────────────┬───────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│  Peel CLI (Swift ArgumentParser)                 │
│  ┌────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │ Command    │  │ Flag         │  │ Config   │ │
│  │ Router     │──│ Translator   │──│ Manager  │ │
│  └────────────┘  └──────────────┘  └──────────┘ │
└──────────────┬───────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│  Executes: container run --detach               │
│            --publish 8080:80 docker.io/nginx     │
└──────────────┬───────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│  Apple container CLI → Virtualization.framework  │
│  → Lightweight Linux VM → OCI Container          │
└──────────────────────────────────────────────────┘
```

## Project Structure

```
peel/
├── Package.swift                 # Swift package manifest
├── Sources/Peel/
│   ├── Peel.swift               # Entry point & command registration
│   ├── Commands/                # Docker command implementations
│   │   ├── Run.swift
│   │   ├── PS.swift
│   │   ├── Images.swift
│   │   ├── Build.swift
│   │   ├── Pull.swift
│   │   ├── Stop.swift
│   │   ├── Remove.swift
│   │   ├── Logs.swift
│   │   ├── Exec.swift
│   │   ├── Inspect.swift
│   │   ├── Network.swift        # network ls/create/rm
│   │   ├── Volume.swift         # volume ls/create/rm
│   │   ├── Compose.swift        # compose up/down
│   │   ├── Link.swift           # link/unlink docker symlink
│   │   └── Doctor.swift
│   ├── Compose/                 # Compose file parsing
│   │   ├── ComposeFile.swift
│   │   ├── ComposeFileLoader.swift
│   │   └── ServiceTranslator.swift
│   ├── Translate/               # Command & flag translation logic
│   │   ├── FlagMapper.swift
│   │   └── ImageRefResolver.swift
│   └── Utilities/
│       ├── ProcessRunner.swift  # Process execution & TTY handling
│       └── ErrorHints.swift     # Docker-familiar error hints
├── Tests/PeelTests/
├── CLAUDE.md                    # Claude Code project instructions
└── README.md
```

## Roadmap

### v0.1 — Core CLI Shim ✅
- [x] Basic command routing (run, ps, images, pull, build, stop, rm)
- [x] Flag translation for common flags (-d, -p, -v, -it, --name, --rm)
- [x] Image reference handling (short names → docker.io/ prefix)
- [x] Transparent stdout/stderr/exit code passthrough
- [x] `peel doctor` command to verify Apple container is installed and running
- [x] `peel link` / `peel unlink` for managing `docker` → `peel` symlink
- [x] GitHub Actions CI and release workflow

### v0.2 — Expanded Commands ✅
- [x] exec, logs, inspect commands
- [x] push, rmi, login, stats via passthrough translation
- [x] Network and volume subcommands
- [x] `peel --dry-run` flag to show translated command without executing
- [x] Better error messages that map Apple container errors to Docker-familiar terms

### v0.3 — Compose Support ✅
- [x] Parse docker-compose.yml files (via Yams)
- [x] `peel compose up` — translate services to `container run` commands
- [x] `peel compose down` — stop and remove service containers
- [x] Support for ports, volumes, environment, and command fields
- [x] Basic service dependency ordering (topological sort via depends_on)
- [x] Network creation for inter-container communication
- [x] Foreground log-following mode (`compose up` without `-d`)
- [x] Warn on unsupported compose options (healthcheck, deploy, etc.)

### Future
- [x] Homebrew formula
- [ ] Docker API socket emulation (for IDE/tool compatibility)
- [ ] Plugin system for custom command mappings

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for details.

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built by [TOMfoolery Labs](https://github.com/tomfoolery-labs)*

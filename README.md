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
- **Compose support** (planned): Parse `docker-compose.yml` and orchestrate via Apple Containers

## Requirements

- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 26 (Tahoe) or later
- [Apple container CLI](https://github.com/apple/container) installed and running (`container system start`)
- Swift 5.9+ (for building from source)

## Installation

```bash
# From source
git clone https://github.com/tomfoolery-labs/peel.git
cd peel
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
```

## Command Mapping

Peel translates Docker CLI commands to their Apple `container` equivalents:

| Docker Command | Peel Translation | Notes |
|---|---|---|
| `docker run` | `container run` | Flag translation for `-d`, `-p`, `-v`, etc. |
| `docker ps` | `container ls` | Adds `--state running` filter |
| `docker ps -a` | `container ls --all` | |
| `docker images` | `container image list` | |
| `docker pull` | `container image pull` | |
| `docker build` | `container build` | |
| `docker stop` | `container stop` | |
| `docker rm` | `container rm` | |
| `docker rmi` | `container image delete` | |
| `docker logs` | `container logs` | |
| `docker exec` | `container exec` | |
| `docker inspect` | `container inspect` | |
| `docker push` | `container image push` | |
| `docker login` | `container registry login` | |
| `docker stats` | `container stats` | |
| `docker network ls` | `container network list` | |
| `docker volume ls` | `container volume list` | |
| `docker compose up` | *planned* | Via container-compose or native |

## How It Works

Peel operates as a simple translation layer:

1. **Parse** the incoming Docker CLI command and flags
2. **Translate** the command to the equivalent Apple `container` command
3. **Execute** the translated command via `Process` (Swift's process spawning)
4. **Pass through** stdout, stderr, and exit codes transparently

There is no daemon, no background process, and no state management. Peel is stateless and disposable.

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
│   ├── Peel.swift               # Entry point
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
│   │   └── Inspect.swift
│   ├── Translate/               # Command & flag translation logic
│   │   ├── CommandTranslator.swift
│   │   ├── FlagMapper.swift
│   │   └── ImageRefResolver.swift
│   └── Config/                  # Configuration & utilities
│       ├── Config.swift
│       ├── ProcessRunner.swift
│       └── Diagnostics.swift
├── Tests/PeelTests/
│   ├── TranslationTests.swift
│   └── FlagMapperTests.swift
├── docs/
│   ├── COMMAND_MAP.md
│   └── CONTRIBUTING.md
├── CLAUDE.md                    # Claude Code project instructions
└── README.md
```

## Roadmap

### v0.1 — Core CLI Shim
- [ ] Basic command routing (run, ps, images, pull, build, stop, rm)
- [ ] Flag translation for common flags (-d, -p, -v, -it, --name, --rm)
- [ ] Image reference handling (short names → docker.io/ prefix)
- [ ] Transparent stdout/stderr/exit code passthrough
- [ ] `peel doctor` command to verify Apple container is installed and running

### v0.2 — Expanded Commands
- [ ] exec, logs, inspect, push, login, stats
- [ ] Network and volume commands
- [ ] `peel --dry-run` flag to show translated command without executing
- [ ] Better error messages that map Apple container errors to Docker-familiar terms

### v0.3 — Compose Support
- [ ] Parse docker-compose.yml files
- [ ] Translate to sequential/parallel `container run` commands
- [ ] Basic service dependency ordering
- [ ] Network creation for inter-container communication

### Future
- [ ] Homebrew formula
- [ ] Docker API socket emulation (for IDE/tool compatibility)
- [ ] Plugin system for custom command mappings

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for details.

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built by [TOMfoolery Labs](https://github.com/tomfoolery-labs)*

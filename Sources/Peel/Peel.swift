import ArgumentParser

@main
struct Peel: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peel",
        abstract: "Docker-compatible CLI for Apple Containers",
        discussion: """
            Peel translates Docker CLI commands into Apple's native container CLI,
            letting you use your existing Docker muscle memory with Apple Containers.
            
            The thin layer between you and the Apple core.
            """,
        version: "0.1.0",
        subcommands: [
            Run.self,
            PS.self,
            Images.self,
            Pull.self,
            Build.self,
            Stop.self,
            Remove.self,
            Logs.self,
            Exec.self,
            Inspect.self,
            Doctor.self,
        ],
        defaultSubcommand: nil
    )
}

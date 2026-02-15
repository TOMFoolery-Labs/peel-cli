import ArgumentParser
import Foundation

struct Images: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List images (translates to: container image list)"
    )

    @Flag(name: .shortAndLong, help: "Only show image IDs")
    var quiet: Bool = false

    func run() throws {
        var args: [String] = ["image", "list"]

        if quiet { args.append("--quiet") }

        let exitCode = ProcessRunner.exec(args)
        throw ExitCode(exitCode)
    }
}

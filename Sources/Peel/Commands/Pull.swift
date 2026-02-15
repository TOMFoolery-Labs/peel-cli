import ArgumentParser
import Foundation

struct Pull: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Download an image (translates to: container image pull)"
    )

    @Argument(help: "Image to pull")
    var image: String

    func run() throws {
        let resolvedImage = ImageRefResolver.resolve(image)
        let args: [String] = ["image", "pull", resolvedImage]

        let exitCode = ProcessRunner.exec(args)
        throw ExitCode(exitCode)
    }
}

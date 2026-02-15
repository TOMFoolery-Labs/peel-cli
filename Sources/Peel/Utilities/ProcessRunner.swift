import Foundation

/// Handles executing Apple's `container` CLI commands with transparent passthrough
/// of stdout, stderr, and exit codes.
enum ProcessRunner {

    /// Path to the Apple container CLI binary
    static let containerBinary = "/usr/local/bin/container"

    /// Execute a container command with full stdio passthrough.
    /// Returns the exit code from the container process.
    ///
    /// - Parameter arguments: Arguments to pass to the `container` binary
    /// - Returns: The process exit code (0 = success)
    @discardableResult
    static func exec(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: containerBinary)
        process.arguments = arguments

        // Pass through stdin/stdout/stderr directly
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        // Forward interrupt signals to child process
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN) // Ignore in parent so we can forward
        sigintSource.setEventHandler {
            if process.isRunning {
                process.interrupt()
            }
        }
        sigintSource.resume()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            fputs("peel: failed to execute container command: \(error.localizedDescription)\n", stderr)
            fputs("peel: is Apple container CLI installed? Run 'peel doctor' to check.\n", stderr)
            return 1
        }

        sigintSource.cancel()
        return process.terminationStatus
    }

    /// Execute a container command silently, capturing output.
    /// Used for internal checks (like `peel doctor`).
    ///
    /// - Parameter arguments: Arguments to pass to the `container` binary
    /// - Returns: The process exit code (0 = success)
    @discardableResult
    static func execSilent(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: containerBinary)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return 1
        }

        return process.terminationStatus
    }

    /// Execute a container command and capture its stdout output as a string.
    ///
    /// - Parameter arguments: Arguments to pass to the `container` binary
    /// - Returns: Tuple of (exit code, stdout string)
    static func execCapture(_ arguments: [String]) -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: containerBinary)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (1, "")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }
}

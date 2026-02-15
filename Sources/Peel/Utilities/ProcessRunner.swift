import Foundation

/// Handles executing Apple's `container` CLI commands with transparent passthrough
/// of stdout, stderr, and exit codes.
enum ProcessRunner {

    /// Path to the Apple container CLI binary, resolved by searching known locations.
    static let containerBinary: String = {
        let candidates = [
            "/opt/homebrew/bin/container",
            "/usr/local/bin/container",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Fall back; will produce a clear error at exec time
        return "/usr/local/bin/container"
    }()

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

        let exitCode = process.terminationStatus
        if exitCode != 0, let hint = ErrorHints.hint(for: arguments) {
            fputs("peel: \(hint)\n", stderr)
        }
        return exitCode
    }

    /// Replace the current process with the container command via execvp.
    /// Used for interactive commands (-it) where the TTY must be forwarded directly.
    /// This function does not return on success — peel is replaced by the container process.
    ///
    /// - Parameter arguments: Arguments to pass to the `container` binary
    /// - Returns: Exit code (only returns if execvp fails)
    @discardableResult
    static func execReplace(_ arguments: [String]) -> Int32 {
        let allArgs = [containerBinary] + arguments
        let cArgs = allArgs.map { strdup($0) } + [nil]
        defer { cArgs.forEach { free($0) } }
        execvp(containerBinary, cArgs)
        // Only reached if execvp fails
        perror("peel")
        return 1
    }

    /// Either print the translated command (dry run) or execute it.
    ///
    /// - Parameters:
    ///   - arguments: Arguments to pass to the `container` binary
    ///   - dryRun: If true, print the command instead of executing it
    ///   - interactive: If true, use execvp for direct TTY passthrough
    /// - Returns: The process exit code (0 for dry run)
    @discardableResult
    static func execOrDryRun(_ arguments: [String], dryRun: Bool, interactive: Bool = false) -> Int32 {
        if dryRun {
            let cmd = ([containerBinary] + arguments).joined(separator: " ")
            print(cmd)
            return 0
        }
        if interactive {
            return execReplace(arguments)
        }
        return exec(arguments)
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

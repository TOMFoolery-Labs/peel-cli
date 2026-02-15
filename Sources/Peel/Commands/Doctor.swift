import ArgumentParser
import Foundation

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check system compatibility for running Apple Containers"
    )

    func run() throws {
        print("Peel Doctor")
        print("===========\n")

        var allPassed = true

        // Check 1: Apple container CLI installed
        let containerExists = FileManager.default.fileExists(atPath: ProcessRunner.containerBinary)
        printCheck("Apple container CLI installed", passed: containerExists,
                   detail: containerExists ? ProcessRunner.containerBinary : "Not found at \(ProcessRunner.containerBinary)")
        if !containerExists { allPassed = false }

        // Check 2: Container system status
        let systemOK = ProcessRunner.execSilent(["system", "status"]) == 0
        printCheck("Container system running", passed: systemOK,
                   detail: systemOK ? "System is ready" : "Run 'container system start' to start")
        if !systemOK { allPassed = false }

        // Check 3: Apple Silicon
        let arch = getArchitecture()
        let isAppleSilicon = arch == "arm64"
        printCheck("Apple Silicon detected", passed: isAppleSilicon,
                   detail: "Architecture: \(arch)")
        if !isAppleSilicon { allPassed = false }

        // Check 4: macOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let isSufficientVersion = version.majorVersion >= 26
        printCheck("macOS 26+ installed", passed: isSufficientVersion,
                   detail: "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        if !isSufficientVersion { allPassed = false }

        print("")
        if allPassed {
            print("All checks passed. Peel is ready to use!")
        } else {
            print("Some checks failed. Please resolve the issues above.")
        }
    }

    private func printCheck(_ name: String, passed: Bool, detail: String) {
        let icon = passed ? "OK" : "FAIL"
        print("  [\(icon)] \(name)")
        print("       \(detail)")
    }

    private func getArchitecture() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}

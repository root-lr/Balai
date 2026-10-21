import Foundation

/// Outils en ligne de commande (docker, xcrun, brew, ollama…).
/// Une app lancée depuis le Finder n'hérite pas du PATH du terminal : on cherche dans les emplacements habituels.
enum ExternalTool {
    private static let searchDirectories: [String] = [
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin",
        Paths.inHome(".orbstack", "bin").path,
        Paths.inHome(".docker", "bin").path,
        Paths.inHome(".local", "bin").path,
        Paths.inHome("go", "bin").path,
        "/usr/local/go/bin",
        "/Applications/Docker.app/Contents/Resources/bin",
        "/Applications/OrbStack.app/Contents/MacOS/xbin",
        "/Applications/Ollama.app/Contents/Resources",
    ]

    struct Output {
        let status: Int32
        let stdout: String
        let stderr: String

        var succeeded: Bool { status == 0 }

        /// Première ligne utile de l'erreur, pour l'afficher dans un bilan.
        var errorSummary: String {
            let line = (stderr.isEmpty ? stdout : stderr)
                .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
            return line ?? L("Code de sortie \(status)", "Exit code \(status)")
        }
    }

    static func find(_ name: String) -> URL? {
        searchDirectories.lazy
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Lance l'outil et attend sa fin ; `nil` s'il est introuvable ou n'a pas pu démarrer.
    static func run(_ name: String, _ arguments: [String], timeout: TimeInterval = 120) async -> Output? {
        guard let executable = find(name) else { return nil }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runSync(executable, arguments, timeout: timeout))
            }
        }
    }

    private static func runSync(_ executable: URL, _ arguments: [String], timeout: TimeInterval) -> Output? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = searchDirectories.joined(separator: ":")
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        environment["NO_COLOR"] = "1"
        process.environment = environment

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)

        // Les deux flux sont lus en parallèle : un tuyau plein bloquerait l'outil.
        var errorData = Data()
        let reading = DispatchGroup()
        reading.enter()
        DispatchQueue.global().async {
            errorData = error.fileHandleForReading.readDataToEndOfFile()
            reading.leave()
        }
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        reading.wait()
        process.waitUntilExit()
        watchdog.cancel()

        return Output(status: process.terminationStatus,
                      stdout: String(decoding: outputData, as: UTF8.self),
                      stderr: String(decoding: errorData, as: UTF8.self))
    }
}

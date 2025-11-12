import Foundation

final class LogManager: @unchecked Sendable {
    static let shared = LogManager()
    private let logFileURL: URL

    private init() {
        let fileManager = FileManager.default
        let tempDir = URL(fileURLWithPath: "/Users/andreseloyasanchezva/.gemini/tmp/eb1a6b55be044a82000f3a4589ebdb9b1574312f91068e99fd44a3252fdc671b")
        logFileURL = tempDir.appendingPathComponent("fixtext.log")
    }

    func log (_ message: String) {
        do {
            let data = (message + "\n").data(using: .utf8)!
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try data.write(to: logFileURL)
            }
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }

    func deleteLogFile() {
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                try FileManager.default.removeItem(at: logFileURL)
            }
        } catch {
            print("Failed to delete log file: \(error)")
        }
    }
}

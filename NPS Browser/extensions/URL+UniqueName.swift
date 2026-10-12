import Foundation

extension URL {
    // Adds " 2", " 3" and so on before the extension while a file with that name exists, like Safari does.
    var uniqueFileURL: URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            return self
        }

        let base = deletingPathExtension().lastPathComponent
        let folder = deletingLastPathComponent()
        var number = 2
        while true {
            let name = pathExtension.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(pathExtension)"
            let candidate = folder.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            number += 1
        }
    }
}

import Foundation

extension FileManager {
    // Creates the folder when it does not exist. The parent folder must exist.
    func createFolderIfNeeded(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        do {
            try createDirectory(at: url, withIntermediateDirectories: false)
            return true
        } catch {
            return false
        }
    }
}

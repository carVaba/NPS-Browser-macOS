import Foundation

// Smooths the transfer speed, so the remaining time does not jump with every packet.
final class TransferRateEstimator {
    private let minimumInterval: TimeInterval = 0.5
    private let smoothing = 0.3
    private var lastSample: (date: Date, bytes: Int64)?
    private(set) var bytesPerSecond: Double = 0

    func update(bytesWritten: Int64, at date: Date = Date()) {
        guard let last = lastSample else {
            lastSample = (date, bytesWritten)
            return
        }

        let elapsed = date.timeIntervalSince(last.date)
        guard elapsed >= minimumInterval else {
            return
        }

        let instant = Double(bytesWritten - last.bytes) / elapsed
        bytesPerSecond = bytesPerSecond == 0 ? instant : smoothing * instant + (1 - smoothing) * bytesPerSecond
        lastSample = (date, bytesWritten)
    }

    func remainingSeconds(bytesWritten: Int64, bytesExpected: Int64) -> TimeInterval? {
        guard bytesPerSecond > 0, bytesExpected > bytesWritten else {
            return nil
        }
        return Double(bytesExpected - bytesWritten) / bytesPerSecond
    }
}

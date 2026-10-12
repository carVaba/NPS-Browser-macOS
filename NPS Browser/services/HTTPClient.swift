//
//  HTTPClient.swift
//  NPS Browser
//

import Foundation

struct DownloadFailure: Error {
    let underlying: Error
    let resumeData: Data?

    var isCancelled: Bool {
        (underlying as? URLError)?.code == .cancelled
    }
}

struct HTTPStatusError: Error {
    let statusCode: Int
}

struct DownloadProgress: Sendable {
    let fraction: Double
    let bytesWritten: Int64
    let bytesExpected: Int64
}

enum DownloadEvent: Sendable {
    case progress(DownloadProgress)
    case waitingForConnectivity
    case finished(URL)
}

// One file download. It starts when `run` is called and can be stopped with `stop`.
actor FileDownload {
    typealias Destination = @Sendable (_ suggestedFilename: String?) -> URL

    private enum Source {
        case url(URL)
        case resumeData(Data)
    }

    private let source: Source
    private let destination: Destination
    private let waitsForConnectivity: Bool
    private var task: URLSessionDownloadTask?
    private var isStopped = false

    nonisolated let usesResumeData: Bool

    // With `waitsForConnectivity` the task waits for the network instead of failing at once.
    init(url: URL, waitsForConnectivity: Bool = false, destination: @escaping Destination) {
        self.source = .url(url)
        self.usesResumeData = false
        self.waitsForConnectivity = waitsForConnectivity
        self.destination = destination
    }

    init(resumeData: Data, waitsForConnectivity: Bool = false, destination: @escaping Destination) {
        self.source = .resumeData(resumeData)
        self.usesResumeData = true
        self.waitsForConnectivity = waitsForConnectivity
        self.destination = destination
    }

    func run(onProgress: @MainActor @Sendable (DownloadProgress) -> Void = { _ in },
             onWaiting: @MainActor @Sendable () -> Void = {}) async throws -> URL {
        guard !isStopped else {
            throw DownloadFailure(underlying: URLError(.cancelled), resumeData: nil)
        }

        for try await event in makeEvents() {
            switch event {
            case .progress(let progress):
                await onProgress(progress)
            case .waitingForConnectivity:
                await onWaiting()
            case .finished(let fileURL):
                return fileURL
            }
        }
        throw DownloadFailure(underlying: URLError(.cancelled), resumeData: nil)
    }

    // Returns the data that `FileDownload(resumeData:destination:)` needs to continue the file later.
    func stop() async -> Data? {
        isStopped = true
        return await task?.cancelByProducingResumeData()
    }

    private func makeEvents() -> AsyncThrowingStream<DownloadEvent, Error> {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = waitsForConnectivity

        let delegate = DownloadDelegate(destination: destination)
        let session = URLSession(configuration: configuration,
                                 delegate: delegate,
                                 delegateQueue: nil)
        let downloadTask: URLSessionDownloadTask
        switch source {
        case .url(let url):
            downloadTask = session.downloadTask(with: url)
        case .resumeData(let data):
            downloadTask = session.downloadTask(withResumeData: data)
        }
        task = downloadTask

        // The closure runs at once, so the delegate has its continuation before the task starts.
        let events = AsyncThrowingStream<DownloadEvent, Error> { continuation in
            delegate.continuation = continuation
            continuation.onTermination = { _ in downloadTask.cancel() }
            downloadTask.resume()
        }
        // Lets the session release its delegate when the task ends.
        session.finishTasksAndInvalidate()

        return events
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: FileDownload.Destination
    var continuation: AsyncThrowingStream<DownloadEvent, Error>.Continuation?
    private var movedURL: URL?
    private var failure: Error?

    init(destination: @escaping FileDownload.Destination) {
        self.destination = destination
    }

    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        continuation?.yield(.waitingForConnectivity)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        continuation?.yield(.progress(DownloadProgress(fraction: Double(totalBytesWritten) / Double(totalBytesExpectedToWrite),
                                                      bytesWritten: totalBytesWritten,
                                                      bytesExpected: totalBytesExpectedToWrite)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            failure = HTTPStatusError(statusCode: http.statusCode)
            return
        }

        // The temporary file is deleted when this method returns, so the move must happen here.
        let target = destination(downloadTask.response?.suggestedFilename)
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.moveItem(at: location, to: target)
            movedURL = target
        } catch {
            failure = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            continuation?.finish(throwing: DownloadFailure(underlying: error, resumeData: resumeData))
        } else if let failure = failure {
            continuation?.finish(throwing: DownloadFailure(underlying: failure, resumeData: nil))
        } else if let movedURL = movedURL {
            continuation?.yield(.finished(movedURL))
            continuation?.finish()
        } else {
            continuation?.finish()
        }
    }
}

enum HTTPClient {
    static func data(from url: URL, onProgress: @MainActor @Sendable (Double) -> Void = { _ in }) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }

        let temporaryFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporaryFile) }

        do {
            let file = try await FileDownload(url: url) { _ in temporaryFile }.run(onProgress: { onProgress($0.fraction) })
            return try Data(contentsOf: file)
        } catch let failure as DownloadFailure {
            throw failure.underlying
        }
    }

    static func string(from url: URL, onProgress: @MainActor @Sendable (Double) -> Void = { _ in }) async throws -> String {
        let data = try await data(from: url, onProgress: onProgress)
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}

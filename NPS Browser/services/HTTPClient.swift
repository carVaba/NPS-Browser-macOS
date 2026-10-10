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

enum DownloadEvent: Sendable {
    case progress(Double)
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
    private var task: URLSessionDownloadTask?
    private var isStopped = false

    init(url: URL, destination: @escaping Destination) {
        self.source = .url(url)
        self.destination = destination
    }

    init(resumeData: Data, destination: @escaping Destination) {
        self.source = .resumeData(resumeData)
        self.destination = destination
    }

    func run(onProgress: @MainActor @Sendable (Double) -> Void = { _ in }) async throws -> URL {
        guard !isStopped else {
            throw DownloadFailure(underlying: URLError(.cancelled), resumeData: nil)
        }

        for try await event in makeEvents() {
            switch event {
            case .progress(let fraction):
                await onProgress(fraction)
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
        var continuation: AsyncThrowingStream<DownloadEvent, Error>.Continuation!
        let events = AsyncThrowingStream<DownloadEvent, Error> { continuation = $0 }

        let session = URLSession(configuration: .default,
                                 delegate: DownloadDelegate(destination: destination, continuation: continuation),
                                 delegateQueue: nil)
        let downloadTask: URLSessionDownloadTask
        switch source {
        case .url(let url):
            downloadTask = session.downloadTask(with: url)
        case .resumeData(let data):
            downloadTask = session.downloadTask(withResumeData: data)
        }
        task = downloadTask

        continuation.onTermination = { _ in downloadTask.cancel() }
        downloadTask.resume()
        // Lets the session release its delegate when the task ends.
        session.finishTasksAndInvalidate()

        return events
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: FileDownload.Destination
    private let continuation: AsyncThrowingStream<DownloadEvent, Error>.Continuation
    private var movedURL: URL?
    private var failure: Error?

    init(destination: @escaping FileDownload.Destination, continuation: AsyncThrowingStream<DownloadEvent, Error>.Continuation) {
        self.destination = destination
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        continuation.yield(.progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
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
            continuation.finish(throwing: DownloadFailure(underlying: error, resumeData: resumeData))
        } else if let failure = failure {
            continuation.finish(throwing: DownloadFailure(underlying: failure, resumeData: nil))
        } else if let movedURL = movedURL {
            continuation.yield(.finished(movedURL))
            continuation.finish()
        } else {
            continuation.finish()
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
            let file = try await FileDownload(url: url) { _ in temporaryFile }.run(onProgress: onProgress)
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

// Temporary wrappers for the callers that still use closures.
extension HTTPClient {
    static func fetchData(from url: URL, progress: ((Double) -> Void)? = nil,
                          completion: @escaping (Result<Data, Error>) -> Void) {
        Task {
            do {
                completion(.success(try await data(from: url, onProgress: { progress?($0) })))
            } catch {
                completion(.failure(error))
            }
        }
    }

    static func fetchString(from url: URL, progress: ((Double) -> Void)? = nil,
                            completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                completion(.success(try await string(from: url, onProgress: { progress?($0) })))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

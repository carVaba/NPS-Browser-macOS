//
//  HTTPClient.swift
//  NPS Browser
//

import Foundation

struct DownloadFailure: Error {
    let underlying: Error
    let resumeData: Data?
}

struct HTTPStatusError: Error {
    let statusCode: Int
}

// One download task that can be cancelled and resumed. It starts only after `start()` is called.
final class FileDownload: NSObject, URLSessionDownloadDelegate {
    typealias Destination = (_ suggestedFilename: String?) -> URL

    var onProgress: ((Double) -> Void)?
    var onFinish: ((Result<URL, DownloadFailure>) -> Void)?

    private enum Source {
        case url(URL)
        case resumeData(Data)
    }

    private let source: Source
    private let destination: Destination
    private var task: URLSessionDownloadTask?
    private var isCancelledBeforeStart = false
    private var movedURL: URL?
    private var failure: Error?

    init(url: URL, destination: @escaping Destination) {
        self.source = .url(url)
        self.destination = destination
    }

    init(resumeData: Data, destination: @escaping Destination) {
        self.source = .resumeData(resumeData)
        self.destination = destination
    }

    func start() {
        guard task == nil else { return }

        if isCancelledBeforeStart {
            onFinish?(.failure(DownloadFailure(underlying: URLError(.cancelled), resumeData: nil)))
            return
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        switch source {
        case .url(let url):
            task = session.downloadTask(with: url)
        case .resumeData(let data):
            task = session.downloadTask(withResumeData: data)
        }
        task?.resume()
        // Lets the session release this delegate when the task ends.
        session.finishTasksAndInvalidate()
    }

    func cancel() {
        guard let task = task else {
            isCancelledBeforeStart = true
            return
        }
        // The resume data arrives in the error of `urlSession(_:task:didCompleteWithError:)`.
        task.cancel(byProducingResumeData: { _ in })
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
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
            onFinish?(.failure(DownloadFailure(underlying: error, resumeData: resumeData)))
        } else if let failure = failure {
            onFinish?(.failure(DownloadFailure(underlying: failure, resumeData: nil)))
        } else if let movedURL = movedURL {
            onFinish?(.success(movedURL))
        }
    }
}

enum HTTPClient {
    static func fetchData(from url: URL, progress: ((Double) -> Void)? = nil,
                          completion: @escaping (Result<Data, Error>) -> Void) {
        if url.isFileURL {
            completion(Result { try Data(contentsOf: url) })
            return
        }

        let temporaryFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let download = FileDownload(url: url) { _ in temporaryFile }
        download.onProgress = progress
        download.onFinish = { result in
            switch result {
            case .success(let file):
                defer { try? FileManager.default.removeItem(at: file) }
                completion(Result { try Data(contentsOf: file) })
            case .failure(let failure):
                completion(.failure(failure.underlying))
            }
        }
        download.start()
    }

    static func fetchString(from url: URL, progress: ((Double) -> Void)? = nil,
                            completion: @escaping (Result<String, Error>) -> Void) {
        fetchData(from: url, progress: progress) { result in
            completion(result.map { data in
                String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            })
        }
    }
}

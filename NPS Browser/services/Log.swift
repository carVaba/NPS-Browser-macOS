//
//  Log.swift
//  NPS Browser
//

import Foundation
import os

struct Log: Sendable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NPS Browser", category: "app")

    func debug(_ message: Any) {
        logger.debug("\(String(describing: message), privacy: .public)")
    }

    func info(_ message: Any) {
        logger.info("\(String(describing: message), privacy: .public)")
    }

    func warning(_ message: Any) {
        logger.warning("\(String(describing: message), privacy: .public)")
    }

    func error(_ message: Any) {
        logger.error("\(String(describing: message), privacy: .public)")
    }
}

let log = Log()

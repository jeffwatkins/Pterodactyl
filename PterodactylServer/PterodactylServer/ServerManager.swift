//
//  ServerManager.swift
//  PterodactylServer
//
//  Created by Matt Stanford on 3/14/20.
//  Copyright © 2020 Matt Stanford. All rights reserved.
//

import Foundation
import Swifter
import OSLog

class ServerManager {

    private typealias RequestHandler = ((HttpRequest) -> HttpResponse)
    private let server = HttpServer()
    let defaultPort: in_port_t = 8081

    let logger = Logger(subsystem: "com.mattstanford.pterodactyl", category: "server")

    func startServer(options: [StartupOption: String]) {
        do {
            let port: in_port_t
            if let portString = options[.port],
               let passedInPort = in_port_t(portString) {
                port = passedInPort
            } else {
                port = defaultPort
            }
        
            logger.info("Starting server on port \(port.description, privacy: .public)")
            try server.start(port)

            // Enumerate all the available endpoints and call the appropriate setup method. This ensures we handle every endpoint at startup.
            for endpoint in Endpoint.allCases {
                switch endpoint {
                    case .push:
                        setupPushEndpoint()
                    case .updateDefaults:
                        setupUpdateDefaultsEndpoint()
                    case .deleteDefaults:
                        setupDeleteDefaultsEndpoint()
                }
            }

        } catch {
            logger.error("Error starting mock server \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func stopServer() {
        server.stop()
    }

    private func setupPushEndpoint() {
        
        let response: RequestHandler = { [weak self] request in
            guard let self = self else { return .internalServerError }

            let jsonDecoder = JSONDecoder()

            guard let pushRequest = try? jsonDecoder.decode(PushRequest.self, from: Data(request.body)) else {
                return HttpResponse.badRequest(nil)
            }

            let simId = pushRequest.simulatorId
            let appBundleId = pushRequest.appBundleId
            let payload = pushRequest.pushPayload

            if let pushFileUrl = self.createTemporaryPushFile(payload: payload) {
                let command = "xcrun simctl push \(simId) \(appBundleId) \(pushFileUrl.path)"
                self.run(command: command)
                
                do {
                    try FileManager.default.removeItem(at: pushFileUrl)
                } catch {
                    self.logger.error("Error removing file!")
                }
                
                return .ok(.text("Ran command: \(command)"))
            } else {
                return .internalServerError
            }
        }
        
        logger.info("Setup push endpoint")
        server.POST[.push] = response
    }

    private func setupUpdateDefaultsEndpoint() {

        let response: RequestHandler = { [weak self] request in
            guard let self = self else { return .internalServerError }

            let jsonDecoder = JSONDecoder()

            guard let updateDefaultsRequest = try? jsonDecoder.decode(UpdateDefaultsRequest.self, from: Data(request.body)) else {
                return HttpResponse.badRequest(nil)
            }

            let simId = updateDefaultsRequest.simulatorId
            let appBundleId = updateDefaultsRequest.appBundleId
            let defaults = updateDefaultsRequest.defaults
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = .withInternetDateTime

            for (key, value) in defaults {
                let newValue: String

                switch value {
                    case .string(let value):
                        newValue = "-string \"\(value)\""
                    case .int(let value):
                        newValue = "-int \(value)"
                    case .float(let value):
                        newValue = "-float \(value)"
                    case .bool(let value):
                        newValue = "-bool \(value ? "TRUE" : "FALSE")"
                    case .date(let value):
                        newValue = "-date \(dateFormatter.string(from: value))"
                }
                
                self.logger.log("setting \(key, privacy: .public) = \(newValue, privacy: .public)")
                let command = "xcrun simctl spawn \(simId) defaults write \(appBundleId) \(key) \(newValue)"
                self.run(command: command)
            }
            return .ok(.text("Updated defaults"))
        }

        logger.info("Setup update defaults")
        server.POST[.updateDefaults] = response
    }

    private func setupDeleteDefaultsEndpoint() {

        let response: RequestHandler = { [weak self] request in
            guard let self = self else { return .internalServerError }

            let jsonDecoder = JSONDecoder()

            guard let deleteDefaultsRequest = try? jsonDecoder.decode(DeleteDefaultsRequest.self, from: Data(request.body)) else {
                return .badRequest(nil)
            }

            let simId = deleteDefaultsRequest.simulatorId
            let appBundleId = deleteDefaultsRequest.appBundleId
            let keys = deleteDefaultsRequest.keys

            for key in keys {
                self.logger.log("deleting \(key, privacy: .public)")
                let command = "xcrun simctl spawn \(simId) defaults delete \(appBundleId) \(key)"
                self.run(command: command)
            }
            return .ok(.text("Updated defaults"))
        }

        logger.info("Setup delete defaults")
        server.POST[.deleteDefaults] = response
    }

    private func createTemporaryPushFile(payload: JSONObject) -> URL? {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let temporaryFilename = ProcessInfo().globallyUniqueString + ".apns"
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(temporaryFilename)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload.value, options: .prettyPrinted)
            try jsonData.write(to: temporaryFileURL, options: .atomic)
        } catch {
            logger.error("Error writing temporary file!")
            return nil
        }
        return temporaryFileURL
    }
    
    private func run(command: String) {
        let pipe = Pipe()
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", String(format:"%@", command)]
        task.standardOutput = pipe
        let file = pipe.fileHandleForReading

        logger.debug("Running command: \(command, privacy: .public)")

        task.launch()
        task.waitUntilExit()

        if let result = NSString(data: file.readDataToEndOfFile(), encoding: String.Encoding.utf8.rawValue) {
            logger.debug("command result: \(result, privacy: .public)")
        }
        else {
            logger.error("Error running command: \(command, privacy: .public)")
        }
    }
}

extension HttpServer.MethodRoute {
    subscript(endpoint: Endpoint) -> ((HttpRequest) -> HttpResponse)? {
        set {
            router.register(method, path: endpoint.rawValue, handler: newValue)
        }
        get { return nil }
    }
}


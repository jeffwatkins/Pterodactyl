//
//  Pterodactyl.swift
//  PterodactylLib
//
//  Created by Matt Stanford on 2/29/20.
//  Copyright © 2020 Matt Stanford. All rights reserved.
//

import Foundation

public class Pterodactyl {
    
    let targetAppBundleId: String
    let host: String
    let port: in_port_t

    public static let defaultPort = defaultPortFromEnvironment()

    public init(targetAppBundleId: String, host: String = "localhost", port: in_port_t = Pterodactyl.defaultPort) {
        self.targetAppBundleId = targetAppBundleId
        self.host = host
        self.port = port
    }
    
    public func triggerSimulatorNotification(withMessage message: String, additionalKeys: [String: Any]? = nil) {
        var innerAlert: [String: Any] = ["alert": message]
        if let additionalKeys = additionalKeys {
            //Merge dictionaries, override duplicates with the ones supplied by "additionalKeys"
            innerAlert = innerAlert.merging(additionalKeys) { (_, new) in new }
        }
        let payload = ["aps": innerAlert]
        triggerSimulatorNotification(withFullPayload: payload)
    }
    
    public func triggerSimulatorNotification(withFullPayload payload: [String: Any]) {
        guard let endpointUrl = url(for: .push) else { return }

        //Make JSON to send to send to server
        let json = PushRequest(
            simulatorId: ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "booted",
            appBundleId: targetAppBundleId,
            pushPayload: JSONObject(payload)
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(json) else { return }
        
        var request = URLRequest(url: endpointUrl)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        execute(request: request)
    }

    /**
     Update the test application's ``UserDefaults``.

     Use this method before launching the application under test to modify the ``UserDefaults``. For example:
     ```
     pterodactyl.updateDefaults([
        "Monkey": .string("On the bed"),
        "WarpDriveEnabled": .bool(true)
     ])
     ```
     **Note: This will only work while the test application is not running.** If called while the test application is running, changes will not necessary be reflected until the next time the test application is launched.
     */
    public func updateDefaults(_ defaults: [String: UpdateDefaultsValue]) {
        guard let endpointUrl = url(for: .updateDefaults) else { return }

        //Make JSON to send to send to server
        let json = UpdateDefaultsRequest(
            simulatorId: ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "booted",
            appBundleId: targetAppBundleId,
            defaults: defaults
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(json) else { return }

        var request = URLRequest(url: endpointUrl)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        execute(request: request)
    }

    public func deleteDefaults(for keys: [String]) {
        guard let endpointUrl = url(for: .deleteDefaults) else { return }

        //Make JSON to send to send to server
        let json = DeleteDefaultsRequest(
            simulatorId: ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "booted",
            appBundleId: targetAppBundleId,
            keys: keys
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(json) else { return }

        var request = URLRequest(url: endpointUrl)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        execute(request: request)
    }

    public func withDefaults(_ defaults: [String: UpdateDefaultsValue], block: (() throws -> Void)) rethrows {
        updateDefaults(defaults)
        defer {
            // Ensure we delete the defaults values even if the block we called throws an error.
            deleteDefaults(for: Array(defaults.keys))
        }
        try block()
    }

    private func url(for endpoint: Endpoint) -> URL? {
        return URL(string: "http://\(host):\(port)/\(endpoint.rawValue)")
    }

    /// Internal method to execute an URLRequest and wait for it to complete.
    private func execute(request: URLRequest) {
        let group = DispatchGroup()
        group.enter()
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in
            // Just wait for the task to complete…
            group.leave()
        }

        task.resume()
        group.wait()
    }

    private static func defaultPortFromEnvironment() -> in_port_t {
        let defaultPort: in_port_t = 8081
        guard let portString = ProcessInfo.processInfo.environment["PTERODACTYL_PORT"] else {
            return defaultPort
        }
        let port = in_port_t(portString) ?? defaultPort
        return port
    }

}

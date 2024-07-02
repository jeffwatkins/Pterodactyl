//
//  Requests.swift
//  PterodactylLib & PterodactylServer
//
//  Copyright © 2024 Matt Stanford. All rights reserved.
//

import Foundation

public enum UpdateDefaultsValue: Codable {
    case string(String)
    case int(Int)
    case float(Double)
    case bool(Bool)
    case date(Date)
}

struct PushRequest: Codable {
    let simulatorId: String
    let appBundleId: String
    let pushPayload: JSONObject
}

struct UpdateDefaultsRequest: Codable {
    let simulatorId: String
    let appBundleId: String
    let defaults: [String: UpdateDefaultsValue]
}

struct DeleteDefaultsRequest: Codable {
    let simulatorId: String
    let appBundleId: String
    let keys: [String]
}

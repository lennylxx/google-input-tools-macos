//
//  ProxySettings.swift
//  GoogleInputTools
//
//  Created by lennylxx on 3/5/26.
//

import CFNetwork
import Foundation

enum ProxyType: String, CaseIterable {
    case none
    case http
    case socks

    var displayName: String {
        switch self {
        case .none: return "Disabled"
        case .http: return "HTTP / HTTPS"
        case .socks: return "SOCKS"
        }
    }
}

struct ProxyConfiguration: Equatable {
    let type: ProxyType
    let host: String
    let port: Int
    let username: String
    let password: String

    var hasCredentials: Bool {
        return !username.isEmpty
    }

    var connectionProxyDictionary: [AnyHashable: Any] {
        switch type {
        case .none:
            return [:]
        case .http:
            return [
                kCFNetworkProxiesHTTPEnable as String: 1,
                kCFNetworkProxiesHTTPProxy as String: host,
                kCFNetworkProxiesHTTPPort as String: port,
                kCFNetworkProxiesHTTPSEnable as String: 1,
                kCFNetworkProxiesHTTPSProxy as String: host,
                kCFNetworkProxiesHTTPSPort as String: port,
            ]
        case .socks:
            var dict: [AnyHashable: Any] = [
                kCFNetworkProxiesSOCKSEnable as String: 1,
                kCFNetworkProxiesSOCKSProxy as String: host,
                kCFNetworkProxiesSOCKSPort as String: port,
            ]
            if hasCredentials {
                dict[kCFStreamPropertySOCKSUser as String] = username
                dict[kCFStreamPropertySOCKSPassword as String] = password
            }
            return dict
        }
    }
}

enum ProxySettings {

    private static let defaults = UserDefaults.standard

    static var type: ProxyType {
        get {
            if let raw = defaults.string(forKey: "proxyType"),
                let type = ProxyType(rawValue: raw)
            {
                return type
            }
            return .none
        }
        set { defaults.set(newValue.rawValue, forKey: "proxyType") }
    }

    static var host: String {
        get { defaults.string(forKey: "proxyHost") ?? "" }
        set { defaults.set(newValue, forKey: "proxyHost") }
    }

    static var port: Int {
        get { defaults.integer(forKey: "proxyPort") }
        set { defaults.set(newValue, forKey: "proxyPort") }
    }

    static var username: String {
        get { defaults.string(forKey: "proxyUsername") ?? "" }
        set { defaults.set(newValue, forKey: "proxyUsername") }
    }

    static var password: String {
        get { defaults.string(forKey: "proxyPassword") ?? "" }
        set { defaults.set(newValue, forKey: "proxyPassword") }
    }

    static var configuration: ProxyConfiguration? {
        let currentType = type
        guard currentType != .none else {
            return nil
        }

        let currentHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPort = port
        guard !currentHost.isEmpty, (1...65535).contains(currentPort) else {
            NSLog(
                "Ignoring invalid proxy configuration: type=\(currentType.rawValue), host=\(currentHost), port=\(currentPort)"
            )
            return nil
        }

        return ProxyConfiguration(
            type: currentType, host: currentHost, port: currentPort,
            username: username, password: password)
    }
}

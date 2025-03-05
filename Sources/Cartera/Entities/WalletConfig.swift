//
//  WalletConfig.swift
//  Cartera
//
//  Created by Rui Huang on 2/23/23.
//

import Foundation

public extension WalletConnections {
    var installed: Bool {
        if let native = native,
           let url = URL(string: native),
           let urlHandler = URLHandler.shared {
            return urlHandler.canOpenURL(url)
        }
        return false
    }
}

public extension WalletConfig {
    var installed: Bool {
        connections?.contains(where: { $0.installed }) ?? false
    }

    var iosEnabled: Bool {
        if let iosMinVersion = iosMinVersion {
            return Bundle.main.versionCompare(otherVersion: iosMinVersion).rawValue >= 0
        }
        return false
    }

    var connectionType: WalletConnectionType {
        if let type = connections?.first(where: { $0.installed || $0.type == "magicLink" })?.type {
            return WalletConnectionType(rawValue: type)
        }
        return .unknown
    }

    func connections(ofType type: WalletConnectionType) -> WalletConnections? {
        connections?.first(where: { $0.type == type.rawValue })
    }
}

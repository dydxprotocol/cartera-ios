//
//  WalletModels.swift
//  Cartera
//
//  Created by Rui Huang on 2/23/23.
//

public typealias Wallets = [Wallet]

// MARK: - Wallet
public struct Wallet: Codable, Equatable {
    public let id: String?
    public let name: String?
    public let homepage: String?
    public let chains: [String]?
    public let app: WalletApp?
    public let mobile: WalletMobile?
    public let desktop: WalletDesktop?
    public let metadata: WalletMetadata?
    public let config: WalletConfig?
    public let userFields: [String: String]?
}

public extension Wallet {
    var universal: String? {
        mobile?.universal
    }
    
    var native: String? {
        if let scheme = mobile?.native {
            return "\(scheme)"
        }
        return nil
    }
    
    var appLink: String? {
        app?.ios
    }
}

// MARK: - App
public struct WalletApp: Codable, Equatable {
    public let browser: String?
    public let ios: String?
    public let android: String?
    public let mac: String?
    public let windows: String?
    public let linux: String?
    public let native: String?
}

// MARK: - Config
public struct WalletConfig: Codable, Equatable {
    public let displayable: Bool?
    public let iosMinVersion: String?
    public let encoding: String?
    public let backlinked: Bool?
    public let imageUrl: String?
    public let connections: [WalletConnections]?
    public let methods: [String]?
}

// MARK: - Connection
public struct WalletConnections: Codable, Equatable {
    public let type, native: String?
    public let universal: String?
}

// MARK: - Desktop
public struct WalletDesktop: Codable, Equatable {
    public let native: String?
    public let universal: String?
}

// MARK: - Mobile
public struct WalletMobile: Codable, Equatable {
    public let native: String?
    public let universal: String?
}

// MARK: - Metadata
public struct WalletMetadata: Codable, Equatable {
    public let shortName: String?
    public let colors: WalletColors?
}

// MARK: - Colors
public struct WalletColors: Codable, Equatable {
    public let primary, secondary: String?
}


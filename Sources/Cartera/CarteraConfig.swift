//
//  CarteraConfig.swift
//  Cartera
//
//  Created by Rui Huang on 2/23/23.
//

import Foundation
import CoinbaseWalletSDK
import UIKit
import WalletConnectSign
import WalletConnectModal

public enum WalletConnectionType: Hashable {
    case walletConnect
    case walletConnectV2
    case walletConnectModal
    case walletSegue
    case magicLink
    case custom(String)
    case unknown
    
    init(rawValue: String) {
        if rawValue == "walletConnect" {
            self = .walletConnect
        } else if rawValue == "walletConnectV2" {
            self = .walletConnectV2
        } else if rawValue == "walletConnectModal" {
            self = .walletConnectModal
        } else if rawValue == "walletSegue" {
            self = .walletSegue
        } else if rawValue == "magicLink" {
            self = .magicLink
        } else {
            self = .custom(rawValue)
        }
    }
    
    var rawValue: String? {
        switch self {
        case .walletConnect:
            return "walletConnect"
        case .walletConnectV2:
            return "walletConnectV2"
        case .walletConnectModal:
            return "walletConnectModal"
        case .walletSegue:
            return "walletSegue"
        case .magicLink:
            return "magicLink"
        case .custom(let value):
            return value
        case .unknown:
            return nil
        }
    }
}

public struct CarteraConfig: SingletonProtocol {
    public static var shared = CarteraConfig()
    
    public mutating func registerProvider(connectionType: WalletConnectionType,
                                          provider: WalletOperationProviderProtocol,
                                          consent: WalletUserConsentProtocol? = nil) {
        registration[connectionType] = RegistrationConfig(provider: provider, consent: consent)
    }
   
    public var walletProvidersConfig: WalletProvidersConfig {
        didSet {
            if walletProvidersConfig != oldValue {
                updateConfigs()
            }
        }
    }
    
    public mutating func registerWallets(configJsonPath: String? = nil) {
        if let configJsonPath = configJsonPath {
            registerWalletsInternal(configJsonPath: configJsonPath)
        } else {
            let bundle = CarteraResources.resourceBundle
            if let configJsonPath = bundle.path(forResource: "wallets_config", ofType: "json") {
                registerWalletsInternal(configJsonPath: configJsonPath)
            } else {
                assertionFailure("registerWallets failed: wallets_config.json not found")
            }
        }
    }
    
    public mutating func registerWallets(configJsonData: Data) {
        do {
            _wallets = try JSONDecoder().decode(Wallets.self, from: configJsonData)
        } catch  {
            assertionFailure("registerWallets failed: \(error)")
        }
    }
    
    public var wallets: [Wallet] {
        _wallets ?? []
    }
 
    public init(localAuthenticator: LocalAuthenticatorProtocol = TimedLocalAuthenticator(),
                walletProvidersConfig: WalletProvidersConfig = WalletProvidersConfig()) {
        self.walletProvidersConfig = walletProvidersConfig
        URLHandler.shared = UIApplication.shared
        LocalAuthenticator.shared = localAuthenticator
        updateConfigs()
    }
    
    // MARK: Internal
    
    mutating func getProvider(of connectionType: WalletConnectionType) -> WalletOperationProviderProtocol? {
        registration[connectionType]?.provider
    }
    
    mutating func getUserConsentHandler(of connectionType: WalletConnectionType) -> WalletUserConsentProtocol? {
        registration[connectionType]?.consent
    }
    
    // MARK: Private
    
    private func updateConfigs() {
        if let walletSegueCallbackUrl = walletProvidersConfig.walletSegue?.callbackUrl,
            CoinbaseWalletSDK.isConfigured == false {
            CoinbaseWalletSDK.configure(callback: URL(string: walletSegueCallbackUrl)!)
        }

        if let walletConnectV2Config = walletProvidersConfig.walletConnectV2 {
            Networking.configure(
                groupIdentifier: walletConnectV2Config.appGroupIdentifier, 
                projectId: walletConnectV2Config.projectId,
                socketFactory: DefaultSocketFactory()
            )
            
            let redirect: AppMetadata.Redirect
            do {
                redirect = try AppMetadata.Redirect(native: walletConnectV2Config.redirectNative, universal: walletConnectV2Config.redirectUniversal)
            } catch {
                assertionFailure("updateConfigs failed: \(error)")
                return
            }
            
            let metadata = AppMetadata(
                name: walletConnectV2Config.clientName,
                description: walletConnectV2Config.clientDescription,
                url: walletConnectV2Config.clientUrl,
                icons: walletConnectV2Config.iconUrls,
                redirect: redirect
            )
            
            Pair.configure(metadata: metadata)
            
            Sign.configure(crypto: DefaultCryptoProvider())
            
            WalletConnectModal.configure(
                projectId: walletConnectV2Config.projectId,
                metadata: metadata
            )
        }
    }
    
    private struct RegistrationConfig {
        let provider: WalletOperationProviderProtocol
        let consent: WalletUserConsentProtocol?
    }
    
    private lazy var walletConnectV2Provider: WalletConnectV2Provider = {
        WalletConnectV2Provider()
    }()
    
    private lazy var registration: [WalletConnectionType: RegistrationConfig] = {
        [
            .walletConnect: RegistrationConfig(provider: WalletConnectV1Provider(), consent: nil),
            .walletConnectV2: RegistrationConfig(provider: walletConnectV2Provider, consent: nil),
            .walletConnectModal: RegistrationConfig(provider: walletConnectV2Provider, consent: nil),
            .walletSegue: RegistrationConfig(provider: WalletSegueProvider(), consent: nil),
        //    .magicLink: RegistrationConfig(provider: MagicLinkProvider(), consent: nil)
        ]
    }()
    
    private mutating func registerWalletsInternal(configJsonPath: String) {
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: configJsonPath), options: .mappedIfSafe)
            _wallets = try? JSONDecoder().decode(Wallets.self, from: jsonData)
        } catch  {
            assertionFailure("registerWallets failed: \(error)")
        }
    }
    
    private var _wallets: [Wallet]?
}

public struct WalletProvidersConfig: Equatable {
    public init(walletConnectV1: WalletConnectV1Config? = nil,
                walletConnectV2: WalletConnectV2Config? = nil,
                walletSegue: WalletSegueConfig? = nil) {
        self.walletConnectV1 = walletConnectV1
        self.walletConnectV2 = walletConnectV2
        self.walletSegue = walletSegue
    }
    
    var walletConnectV1: WalletConnectV1Config?
    var walletConnectV2: WalletConnectV2Config?
    var walletSegue: WalletSegueConfig?
}

public struct WalletConnectV1Config: Equatable {
    public init(clientName: String, clientDescription: String? = nil, iconUrl: String? = nil, scheme: String, clientUrl: String, bridgeUrl: String) {
        self.clientName = clientName
        self.clientDescription = clientDescription
        self.iconUrl = iconUrl
        self.scheme = scheme
        self.clientUrl = clientUrl
        self.bridgeUrl = bridgeUrl
    }
    
    let clientName: String
    let clientDescription: String?
    let iconUrl: String?
    let scheme: String
    let clientUrl: String
    let bridgeUrl: String
}

public struct WalletConnectV2Config: Equatable {
    public init(projectId: String, clientName: String, clientDescription: String, clientUrl: String, iconUrls: [String], redirectNative: String, redirectUniversal: String?, appGroupIdentifier: String) {
        self.projectId = projectId
        self.clientName = clientName
        self.clientDescription = clientDescription
        self.clientUrl = clientUrl
        self.iconUrls = iconUrls
        self.redirectNative = redirectNative
        self.redirectUniversal = redirectUniversal
        self.appGroupIdentifier = appGroupIdentifier
    }
    
    let projectId: String
    let clientName: String
    let clientDescription: String
    let clientUrl: String
    let iconUrls: [String]
    let redirectNative: String
    let redirectUniversal: String?
    let appGroupIdentifier: String
}

public struct WalletSegueConfig: Equatable {
    public init(callbackUrl: String) {
        self.callbackUrl = callbackUrl
    }
    
    // WalletSegue (Coinbase)
    let callbackUrl: String
}

class CarteraMarker: NSObject {}

extension UIApplication: URLHandlerProtocol {
    func open(_ url: URL, completionHandler completion: ((Bool) -> Void)?) {
        open(url, options: [:], completionHandler: completion)
    }
}

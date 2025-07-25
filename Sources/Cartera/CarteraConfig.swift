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
    case phantomWallet
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
        } else if rawValue == "phantomWallet" {
            self = .phantomWallet
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
        case .phantomWallet:
            return "phantomWallet"
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
        } catch {
            assertionFailure("registerWallets failed: \(error)")
        }
    }

    public var wallets: [Wallet] {
        _wallets ?? []
    }

    public var wcModalWallets = [
        "c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96",     // Metamask
        "4622a2b2d6af1c9844944291e5e7351a6aa24cd7b23099efac1b2fd875da31a0",     // Trust
        "971e689d0a5be527bac79629b4ee9b925e82208e5168b733496a09c0faed0709",     // OKX
        "c03dfee351b6fcc421b4494ea33b9d4b92a984f87aa76d1663bb28705e95034a",     // Uniswap
        "1ae92b26df02f0abca6304df07debccd18262fdf5fe82daa81593582dac9a369",     // Rainbow
        "ecc4036f814562b41a5268adc86270fba1365471402006302e70169465b7ac18",     // Zerion
        "c286eebc742a537cd1d6818363e9dc53b21759a1e8e5d9b263d0c03ec7703576",     // 1inch
        "ef333840daf915aafdc4a004525502d6d49d77bd9c65e0642dbaefb3c2893bef",     // imToken
        "38f5d18bd8522c244bdd70cb4a68e0e718865155811c043f052fb9f1c51de662",     // Bitget
        "0b415a746fb9ee99cce155c2ceca0c6f6061b1dbca2d722b3ba16381d0562150",     // Safepal
        "15c8b91ade1a4e58f3ce4e7a0dd7f42b47db0c8df7e0d84f63eb39bcb96c4e0f",     // Bybit
        "19177a98252e07ddfc9af2083ba8e07ef627cb6103467ffebb3f8f4205fd7927",     // Ledger Live
        "344d0e58b139eb1b6da0c29ea71d52a8eace8b57897c6098cb9b46012665c193",     // Timeless X
        "225affb176778569276e484e1b92637ad061b01e13a048b35a9d280c3b58970f",     // Safe
        "f2436c67184f158d1beda5df53298ee84abfc367581e4505134b5bcf5f46697d",     // Crypto.com
        "18450873727504ae9315a084fa7624b5297d2fe5880f0982979c17345a138277",     // Kraken
        "541d5dcd4ede02f3afaf75bf8e3e4c4f1fb09edb5fa6c4377ebf31c2785d9adf"      // Ronin
    ]
    
    public init(localAuthenticator: LocalAuthenticatorProtocol = TimedLocalAuthenticator(),
                walletProvidersConfig: WalletProvidersConfig = WalletProvidersConfig()) {
        self.walletProvidersConfig = walletProvidersConfig
        URLHandler.shared = UIApplication.shared
        LocalAuthenticator.shared = localAuthenticator
        updateConfigs()
    }
    
    @discardableResult
    public mutating func handleResponse(_ url: URL) throws -> Bool {
        for providers in registration.values {
            if providers.provider.handleResponse(url) {
                return true
            }
        }
        
        return false
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
                metadata: metadata,
                recommendedWalletIds: wcModalWallets,
                excludedWalletIds: [
                ]
            )
        }
        
        if let phantomWallet = walletProvidersConfig.phantomWallet {
            PhantomWalletProvider.configure(config: phantomWallet)
        }
    }

    private struct RegistrationConfig {
        let provider: WalletOperationProviderProtocol
        let consent: WalletUserConsentProtocol?
    }

    private lazy var registration: [WalletConnectionType: RegistrationConfig] = {
        let walletConnectV2Provider = WalletConnectV2Provider()
        return [
            .walletConnect: RegistrationConfig(provider: WalletConnectV1Provider(), consent: nil),
            .walletConnectV2: RegistrationConfig(provider: walletConnectV2Provider, consent: nil),
            .walletConnectModal: RegistrationConfig(provider: walletConnectV2Provider, consent: nil),
            .walletSegue: RegistrationConfig(provider: WalletSegueProvider(), consent: nil),
            .phantomWallet: RegistrationConfig(provider: PhantomWalletProvider(), consent: nil),
        //    .magicLink: RegistrationConfig(provider: MagicLinkProvider(), consent: nil)
        ]
    }()

    private mutating func registerWalletsInternal(configJsonPath: String) {
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: configJsonPath), options: .mappedIfSafe)
            _wallets = try? JSONDecoder().decode(Wallets.self, from: jsonData)
        } catch {
            assertionFailure("registerWallets failed: \(error)")
        }
    }

    private var _wallets: [Wallet]?
}

public struct WalletProvidersConfig: Equatable {
    public init(walletConnectV1: WalletConnectV1Config? = nil,
                walletConnectV2: WalletConnectV2Config? = nil,
                walletSegue: WalletSegueConfig? = nil,
                phantomWallet: PhantomWalletConfig? = nil) {
        self.walletConnectV1 = walletConnectV1
        self.walletConnectV2 = walletConnectV2
        self.walletSegue = walletSegue
        self.phantomWallet = phantomWallet
    }

    var walletConnectV1: WalletConnectV1Config?
    var walletConnectV2: WalletConnectV2Config?
    var walletSegue: WalletSegueConfig?
    var phantomWallet: PhantomWalletConfig?
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

public struct PhantomWalletConfig: Equatable {
    public init(appUrl: String, appRedirectBaseUrl: String, solanaMainnetUrl: String? = nil, solanaTestnetUrl: String? = nil) {
        self.appUrl = appUrl
        self.appRedirectBaseUrl = appRedirectBaseUrl
        self.solanaMainnetUrl = solanaMainnetUrl
        self.solanaTestnetUrl = solanaTestnetUrl
    }

    let appUrl: String
    let appRedirectBaseUrl: String
    let solanaMainnetUrl: String?
    let solanaTestnetUrl: String?
}

class CarteraMarker: NSObject {}

extension UIApplication: URLHandlerProtocol {
    func open(_ url: URL, completionHandler completion: ((Bool) -> Void)?) {
        open(url, options: [:], completionHandler: completion)
    }
}

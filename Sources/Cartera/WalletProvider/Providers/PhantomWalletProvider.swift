//
//  PhantomWalletProvider.swift
//  Cartera
//
//  Created by Rui Huang on 03/03/2025.
//

import Foundation
import TweetNacl
import Base58Swift
import UIKit

final class PhantomWalletProvider: NSObject, WalletOperationProviderProtocol {
    
    private enum CallbackAction: String {
        case onConnect
    }
    
    private let baseUrlString = "https://phantom.app/ul/v1"
    
    static private var appUrl: String?
    static private var appRedirectBaseUrl: String?
    static var isConfigured: Bool {
        return appUrl != nil && appRedirectBaseUrl != nil
    }
    
    static func configure(config: PhantomWalletConfig) {
        appUrl = config.appUrl
        appRedirectBaseUrl = config.appRedirectBaseUrl
    }
    
    private var publicKey: Data?  = nil
    private var privateKey: Data? = nil
    
    private var publickKeyEncoded: String? {
        guard let bytes = publicKey?.bytes else {
            return nil
        }
        
        return Base58.base58Encode(bytes)
    }
    
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    private func beginBackgroundTask() {
        if backgroundTaskId == .invalid {
            backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
                if let self = self {
                    self.endBackgroundTask()
                }
            }
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }

    private var openUrlCompletions = [(URL, ((Bool) -> Void)?)]()

    private var foregroundToken: NotificationToken?
    private var backgroundToken: NotificationToken?

    private var background: Bool = false {
        didSet {
            if background == false {
                if let openUrlCompletion = openUrlCompletions.first {
                    openLaunchDeeplink(url: openUrlCompletion.0, completion: openUrlCompletion.1)
                    openUrlCompletions.removeFirst()
                }
            }
        }
    }
    
    private var connectionCompletions: [URL: WalletConnectCompletion] = [:]
    
    
    // MARK: WalletDeeplinkHandlingProtocol
      
    func handleResponse(_ url: URL) -> Bool {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let appRedirectBaseUrl = Self.appRedirectBaseUrl,
              urlComponents.string?.starts(with: appRedirectBaseUrl) ?? false else {
            return false
        }
        guard let actionString = urlComponents.url?.lastPathComponent,
              let action = CallbackAction(rawValue: actionString) else {
            assertionFailure("PhantomWalletProvider Unsupported callback URL: \(url)")
            return false
        }
        
        let params = urlComponents.queryItems
        
        switch action {
        case .onConnect:
//            if params.fir
//            if let errorCode = params["errorCode"] {
//                let errorMessage = params["errorMessage"] ?: "Unkbown error"
//            }
            return true
            
        }
        
        return false
    }
    
    // MARK: WalletOperationProviderProtocol

    var walletStatus: (any WalletStatusProtocol)?
    
    var walletStatusDelegate: (any WalletStatusDelegate)?
    
    // MARK: WalletUserConsentOperationProtocol

    var userConsentDelegate: (any WalletUserConsentProtocol)?
    
    // MARK: WalletOperationProtocol

    func connect(request: WalletRequest, completion: @escaping WalletConnectCompletion) {
        guard let appUrl =  Self.appUrl, let appRedirectBaseUrl = Self.appRedirectBaseUrl else {
            assertionFailure("PhantomWalletConfig missing")
            return
        }
        
        guard let result = try? NaclBox.keyPair() else {
            completion(nil, WalletError.error(code: .unexpectedResponse, message: "Failed to generate key pair"))
            return
        }
        publicKey = result.publicKey
        privateKey = result.secretKey
        
        guard let publickKeyEncoded = publickKeyEncoded else {
            completion(nil, WalletError.error(code: .unexpectedResponse, message: "Failed to encode public key"))
            return
        }
        
        guard var urlComponents = URLComponents(string:  baseUrlString + "/connect") else {
            completion(nil, WalletError.error(code: .unexpectedResponse, message: "Failed to create URL"))
            return
        }
        
        let cluster: String
        if request.chainId == 1 {
            // mainnet
            cluster = "mainnet-beta"
        } else {
            cluster = "devnet"
        }

        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "app_url", value: appUrl))
        queryItems.append(URLQueryItem(name: "cluster", value: cluster))
        queryItems.append(URLQueryItem(name: "redirect_link", value: appRedirectBaseUrl + "/" + CallbackAction.onConnect.rawValue))
        queryItems.append(URLQueryItem(name: "dapp_encryption_public_key", value: publickKeyEncoded))
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            completion(nil, WalletError.error(code: .unexpectedResponse, message: "Failed to create URL"))
            return
        }
        
        openLaunchDeeplink(url: url) { [weak self] success in
            if !success {
                completion(nil, WalletError.error(code: .unexpectedResponse, message: "Failed to open URL"))
            }
            
            // let deeplink callback handle the result
            self?.connectionCompletions[url] = completion
        }
    }
    
    func disconnect() {
        publicKey = nil
        privateKey = nil
        openUrlCompletions = []
        connectionCompletions = [:]
    }
    
    func signMessage(request: WalletRequest, message: String, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        
    }
    
    func sign(request: WalletRequest, typedDataProvider: (any WalletTypedDataProviderProtocol)?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        
    }
    
    func send(request: WalletTransactionRequest, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        
    }
    
    func addChain(request: WalletRequest, chain: EthereumAddChainRequest, timeOut: TimeInterval?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        
    }
    
    private func openLaunchDeeplink(url: URL, completion: ((Bool) -> Void)? = nil) {
        if background == false {
             if let urlHandler = URLHandler.shared,
               urlHandler.canOpenURL(url) {
                beginBackgroundTask()
                urlHandler.open(url, completionHandler: completion)
            } else {
                completion?(false)
            }
        } else {
             openUrlCompletions.append((url, completion))
        }
    }
    
}

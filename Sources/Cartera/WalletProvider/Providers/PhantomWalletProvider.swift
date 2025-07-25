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
import SolanaSwift

final class PhantomWalletProvider: NSObject, WalletOperationProviderProtocol {
    
    private enum CallbackAction: String {
        case onConnect
        case onDisconnect
        case onSignMessage
        case onSignTransaction
        
        var request: String {
            switch self {
            case .onConnect:
                return "connect"
            case .onDisconnect:
                return "disconnect"
            case .onSignMessage:
                return "signMessage"
            case .onSignTransaction:
                return "signTransaction"
            }
        }
    }
    
    private let baseUrlString = "https://phantom.app/ul/v1"
    
    static private var appUrl: String?
    static private var appRedirectBaseUrl: String?
    static private var solanaMainnetUrl: String?
    static private var solanaTestnetUrl: String?
    static var isConfigured: Bool {
        return appUrl != nil && appRedirectBaseUrl != nil
    }
    
    static func configure(config: PhantomWalletConfig) {
        appUrl = config.appUrl
        appRedirectBaseUrl = config.appRedirectBaseUrl
    }
    
    private var publicKey: Data?  = nil
    private var privateKey: Data? = nil
    private var phantomPublicKey: Data? = nil
    private var session: String? = nil
    
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

    private var _walletStatus = WalletStatusImp() {
        didSet {
            walletStatusDelegate?.statusChanged(_walletStatus)
        }
    }
    
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
    
    private var connectionCompletion:  WalletConnectCompletion?
    private var connectionWallet: Wallet?
    private var operationCompletion: WalletOperationCompletion?
    
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
        
        switch action {
        case .onConnect:
            guard let completion = connectionCompletion else {
                return false
            }
            connectionCompletion = nil
            
            let errorCode = url.queryParams["errorCode"]
            let errorMessage = url.queryParams["errorMessage"] ?? "Unknown error"
            if let errorCode = errorCode {
                let code = Int(errorCode) ?? -1
                completion(nil, WalletError.error(code: .unexpectedResponse, message: errorMessage + " (\(code))"))
            } else {
                let encodedPublicKey = url.queryParams["phantom_encryption_public_key"]
                phantomPublicKey = base58Decode(data: encodedPublicKey)
                let nonce = url.queryParams["nonce"]
                if let data = decryptPayload(payload: url.queryParams["data"], nonce: nonce) {
                    if let response = try? JSONDecoder().decode(ConnectResponse.self,  from: data) {
                        session = response.session
                        let walletInfo = WalletInfo(address: response.public_key, chainId: nil, wallet: connectionWallet)
                        _walletStatus.state = .connectedToWallet
                        _walletStatus.connectedWallet = walletInfo
                        DispatchQueue.main.async {
                            completion(walletInfo, nil)
                        }
//
//                        if let sessionData = decodeSignedPayload(payload: response.session),
//                           let sessionStruct = try? JSONDecoder().decode(PhantomSession.self, from: sessionData) {
//                            completion(WalletInfo(address: sessionStruct.chain, chainId: nil, wallet: nil), nil)
//                        } else {
//                            completion(nil, WalletError.error(code: .unexpectedResponse, message: "Unable to decode session"))
//                        }
                    } else {
                        completion(nil, WalletError.error(code: .unexpectedResponse, message: "Unexpected JSON payload"))
                    }
                } else {
                    completion(nil, WalletError.error(code: .unexpectedResponse, message: "Unable to decrypt payload"))
                }
            }
            return true
            
        case .onDisconnect:
            let errorCode = url.queryParams["errorCode"]
            let errorMessage = url.queryParams["errorMessage"] ?? "Unknown error"
            if let errorCode = errorCode {
                Console.shared.log("PhantomWalletProvider Disconnected: \(errorMessage) (\(errorCode))")
            }
            return true
            
        case .onSignMessage:
            guard let completion = operationCompletion else {
                return false
            }
            operationCompletion = nil
            
            let errorCode = url.queryParams["errorCode"]
            let errorMessage = url.queryParams["errorMessage"] ?? "Unknown error"
            if let errorCode = errorCode {
                let code = Int(errorCode) ?? -1
                completion(nil, WalletError.error(code: .unexpectedResponse, message: errorMessage + " (\(code))"))
            } else {
                let nonce = url.queryParams["nonce"]
                if let data = decryptPayload(payload: url.queryParams["data"], nonce: nonce) {
                    if let response = try? JSONDecoder().decode(SignMessageResponse.self, from: data) {
                        completion(response.signature, nil)
                    } else {
                        completion(nil, WalletError.error(code: .unexpectedResponse, message: "Unexpected JSON payload"))
                    }
                } else {
                    completion(nil, WalletError.error(code: .unexpectedResponse, message: "Unable to decrypt payload"))
                }
            }
            return true
            
        case .onSignTransaction:
            guard let completion = operationCompletion else {
                return false
            }
            operationCompletion = nil
            
            let errorCode = url.queryParams["errorCode"]
            let errorMessage = url.queryParams["errorMessage"] ?? "Unknown error"
            if let errorCode = errorCode {
                let code = Int(errorCode) ?? -1
                completion(nil, WalletError.error(code: .unexpectedResponse, message: errorMessage + " (\(code))"))
            } else {
                let nonce = url.queryParams["nonce"]
                if let data = decryptPayload(payload: url.queryParams["data"], nonce: nonce) {
                    if let response = try? JSONDecoder().decode(SignTransactionResponse.self,  from: data) {
                        completion(response.transaction, nil)
                    } else {
                        completion(nil, WalletError.error(code: .unexpectedResponse, message: "Unexpected JSON payload"))
                    }
                } else {
                    completion(nil, WalletError.error(code: .unexpectedResponse, message: "Unable to decrypt payload"))
                }
            }
            return true
        }
    }

    // MARK: WalletOperationProviderProtocol

    var walletStatus: WalletStatusProtocol? {
        _walletStatus
    }
    
    var walletStatusDelegate: WalletStatusDelegate?

    // MARK: WalletUserConsentOperationProtocol

    var userConsentDelegate: (any WalletUserConsentProtocol)?
    
    // MARK: WalletOperationProtocol

    func connect(request: WalletRequest, completion: @escaping WalletConnectCompletion) {
        let connectedWallet = _walletStatus.connectedWallet
        guard session == nil else {
            completion(connectedWallet, nil)
            return
        }
        
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
        
        guard var urlComponents = URLComponents(string:  baseUrlString + "/" + CallbackAction.onConnect.request) else {
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
            } else {
                // let deeplink callback handle the result
                self?.connectionCompletion = completion
                self?.connectionWallet = request.wallet
            }
        }
    }
    
    func disconnect() {
//        guard let session = session else {
//            return
//        }
//        
//        if let request = try? DisconnectRequest(session: session).json(),
//           let url = createRequestUrl(request: request, action: .onDisconnect)  {
//            openLaunchDeeplink(url: url) { success in
//                if !success {
//                    Console.shared.log("Failed to open URL")
//                }
//            }
//        }
//        
        publicKey = nil
        privateKey = nil
        phantomPublicKey = nil
        openUrlCompletions = []
        connectionCompletion = nil
        operationCompletion = nil
        
        self.session = nil
        connectionWallet = nil
        _walletStatus.state = .idle
        _walletStatus.connectedWallet = nil
    }
    
    func signMessage(request: WalletRequest, message: String, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        connect(request: request) { [weak self] walletInfo, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(walletInfo)
                self?.doSignMessage(message: message, completion: completion)
            }
        }
    }
    
    private func doSignMessage(message: String, completion: @escaping WalletOperationCompletion) {
        let request = SignMessageRequest(session: session,
                                         message: base58Encode(data: message.data(using: .utf8)),
                                         display: "utf8")
        if let request = try? request.json(),
           let url = createRequestUrl(request: request, action: .onSignMessage) {
            openLaunchDeeplink(url: url) { [weak self] success in
                if !success {
                    assertionFailure("Failed to open URL")
                }
                
                self?.operationCompletion = completion
            }
        }
    }
    
    func sign(request: WalletRequest, typedDataProvider: (any WalletTypedDataProviderProtocol)?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        guard let typeDataString = typedDataProvider?.typedDataAsString else {
            completion(nil, WalletError.error(code: .invalidInput, message: "invalid typedData"))
            return
        }
        signMessage(request: request, message: typeDataString, connected: connected, completion: completion)
    }
    
    func send(request: WalletTransactionRequest, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        connect(request: request.walletRequest) { [weak self] walletInfo, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(walletInfo)
                self?.doSend(request: request, completion: completion)
            }
        }
    }
    
    private func doSend(request: WalletTransactionRequest, completion: @escaping WalletOperationCompletion) {
        guard let data = request.solana, let transaction = base58Encode(data: data) else {
            completion(nil, WalletError.error(code: .invalidInput, message: "Solana data not found"))
            return
        }
        
        doSignTransaction(transaction: transaction) { signed,error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                guard let signed else {
                    completion(nil, WalletError.error(code: .signingTransactionFailed))
                    return
                }
                
                let solanaMainnetEndpoint: APIEndPoint
                if let solanaMainnetUrl = PhantomWalletProvider.solanaMainnetUrl {
                    solanaMainnetEndpoint = APIEndPoint(address: solanaMainnetUrl, network: .mainnetBeta)
                } else {
                    solanaMainnetEndpoint = SolanaInteractor.mainnetEndpoint
                }
                
                let solanaTestnetEndpoint: APIEndPoint
                if let solanaTestnetUrl = PhantomWalletProvider.solanaTestnetUrl {
                    solanaTestnetEndpoint = APIEndPoint(address: solanaTestnetUrl, network: .mainnetBeta)
                } else {
                    solanaTestnetEndpoint = SolanaInteractor.devnetEndpoint
                }
                
                let endpoint = request.walletRequest.chainId == 1 ? solanaMainnetEndpoint : solanaTestnetEndpoint
                let solanaInteractor = SolanaInteractor(endpoint: endpoint)
                Task {
                    do {
                        let hash = try await solanaInteractor.sendTransaction(transaction: signed)
                        DispatchQueue.main.async {
                            completion(hash, nil)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(nil, error)
                        }
                    }
                }
            }
        }
    }
    
    private func doSignTransaction(transaction: String, completion: @escaping WalletOperationCompletion) {
        let request = SignTransactionRequest(session: session,
                                             transaction: transaction)
        if let request = try? request.json(),
           let url = createRequestUrl(request: request, action: .onSignTransaction) {
            openLaunchDeeplink(url: url) { [weak self] success in
                if !success {
                    assertionFailure("Failed to open URL")
                }
                
                self?.operationCompletion = completion
            }
        }
    }
    
    func addChain(request: WalletRequest, chain: EthereumAddChainRequest, timeOut: TimeInterval?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        // no-op
    }
    
    private func createRequestUrl(request: String?, action: CallbackAction) -> URL? {
        guard var urlComponents = URLComponents(string:  baseUrlString + "/" + action.request),
              let appRedirectBaseUrl = Self.appRedirectBaseUrl else {
            return nil
        }
        
        if  let request = request,
            let result = encryptPayload(payload: request.data(using: .utf8)),
            let payload = base58Encode(data: result.0),
            let nonce = base58Encode(data: result.1) {
            var queryItems = [URLQueryItem]()
            queryItems.append(URLQueryItem(name: "payload", value: payload))
            queryItems.append(URLQueryItem(name: "nonce", value: nonce))
            queryItems.append(URLQueryItem(name: "redirect_link", value: appRedirectBaseUrl + "/" + action.rawValue))
            queryItems.append(URLQueryItem(name: "dapp_encryption_public_key", value: publickKeyEncoded))
            
            urlComponents.queryItems = queryItems
            
            return urlComponents.url
        }
        
        return nil
       
    }
    
    private func base58Encode(data: Data?) -> String? {
        if let data = data {
            return Base58.base58Encode(data.bytes)
        }
        return nil
    }
    
    private func base58Decode(data: String?) -> Data? {
        if let data = data, let bytes = Base58.base58Decode(data) {
            return Data(bytes: bytes, count: bytes.count)
        }
        return nil
    }
    
    private func encryptPayload(payload: Data?) -> (Data, Data)? {
         let nonceData = Data.randomBytes(count: 24)
        
        if let payload = payload,
           let publicKey = phantomPublicKey,
           let privateKey = privateKey {
            let encryptedData = try? NaclBox.box(message: payload,
                                                 nonce: nonceData,
                                                 publicKey: publicKey,
                                                 secretKey: privateKey)
            if let encryptedData = encryptedData  {
                return (encryptedData, nonceData)
            }
            return nil
        }
        return nil
    }
    
    private func decryptPayload(payload: String?, nonce: String?) -> Data? {
        if let decodedData = base58Decode(data: payload),
           let decodedNonceData = base58Decode(data: nonce),
           let publicKey = phantomPublicKey,
           let privateKey = privateKey {
            return try? NaclBox.open(message: decodedData,
                                     nonce:  decodedNonceData,
                                     publicKey: publicKey,
                                     secretKey: privateKey)
        }
        
        return nil
    }
    
    private func decodeSignedPayload(payload: String?) -> Data? {
        if let decodedData = base58Decode(data: payload),
           let publicKey = phantomPublicKey {
            return try? NaclSign.signOpen(signedMessage: decodedData, publicKey: publicKey)
        }
        
        return nil
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

private extension Data {
    /// Returns cryptographically secure random data.
    ///
    /// - Parameter length: Length of the data in bytes.
    /// - Returns: Generated data of the specified length.
    static func random(length: Int) throws -> Data {
        return Data((0 ..< length).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })
    }
}

private extension URL {
    var queryParams: [String: String] {
        guard let urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return [:]
        }
       
        var queryParams: [String: String] = [:]
        for query in urlComponents.queryItems ?? [] {
            queryParams[query.name] = query.value
        }
        return queryParams
    }
}

private struct ConnectResponse: Codable {
    let public_key: String?
    let session: String?
}

private struct DisconnectRequest: Codable {
    let session: String?
}

private struct SignMessageRequest: Codable {
    let session: String?
    let message: String?
    let display: String?    //  "utf8" | "hex"
}

private struct SignMessageResponse: Codable {
    let signature: String?
}

private struct SignTransactionRequest: Codable {
    let session: String?
    let transaction: String?
}

private struct SignTransactionResponse: Codable {
    let transaction: String?
}

private struct PhantomSession: Codable {
    let app_url: String?
    let timestamp: String?
    let chain: String?
    let cluster: String?
}

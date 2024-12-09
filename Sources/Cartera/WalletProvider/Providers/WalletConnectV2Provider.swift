//
//  WalletConnectV2Provider.swift
//  
//
//  Created by Rui Huang on 3/16/23.
//

import BigInt
import CryptoKit
import WalletConnectSign
import UIKit
import Combine

final class WalletConnectV2Provider: NSObject, WalletOperationProviderProtocol {
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
    
    private var publishers = Set<AnyCancellable>()
    private var currentSession: Session?
    private var uri: WalletConnectURI? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?._walletStatus.connectionDeeplink = self?.uri?.absoluteString
            }
        }
    }
    private var requestingWallet: Wallet?
    
    private var connectCompletions = [WalletConnectCompletion]()
    private var operationCompletions = [RPCID: WalletOperationCompletion]()
    
    private var openUrlCompletions = [((Bool) -> Void)?]()
    
    private var foregroundToken: NotificationToken?
    private var backgroundToken: NotificationToken?
    
    private var background: Bool = false {
        didSet {
            if background == false {
                if let openUrlCompletion = openUrlCompletions.first {
                    openLaunchDeeplink(completion: openUrlCompletion)
                    openUrlCompletions.removeFirst()
                }
            }
        }
    }
   
    private var _walletStatus = WalletStatusImp() {
        didSet {
            walletStatusDelegate?.statusChanged(_walletStatus)
        }
    }
    
    var walletStatus: WalletStatusProtocol? {
        _walletStatus
    }
    
    var walletStatusDelegate: WalletStatusDelegate?
    
    var userConsentDelegate: WalletUserConsentProtocol?
    
    override init() {
        super.init()
        
        observeChanges()
        
        backgroundToken = NotificationCenter.default.observe(notification: UIApplication.didEnterBackgroundNotification, do: { [weak self] _ in
            self?.background = true
        })
        foregroundToken = NotificationCenter.default.observe(notification: UIApplication.willEnterForegroundNotification, do: { [weak self] _ in
            self?.background = false
        })
    }

    deinit {
        disconnect()
    }
     
    func connect(request: WalletRequest, completion: @escaping WalletConnectCompletion) {
        if let connectedWallet = _walletStatus.connectedWallet, request.wallet != nil, connectedWallet.wallet != request.wallet {
            Task {
                await doDisconnectAsync()
            }
        }
        
        if let wallet = _walletStatus.connectedWallet {
            completion(wallet, nil)
        } else {
            requestingWallet = request.wallet
            connectCompletions.append(completion)
            
            Task {
                do {
                    if self.uri == nil {
                        Console.shared.log("Creating WalletConnectV2 pair")
                        self.uri = try await Pair.instance.create()
                    }
                } catch {
                    Console.shared.log(error)
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.executeWithDeeplink(request: request) { success in
                        if success, self?.uri != nil {
                            Task {
                                self?.uri = await self?.doConnect(chainId: request.chainId, methods: request.wallet?.config?.methods)
                            }
                        } else {
                            completion(nil, WalletError.error(code: .linkOpenFailed))
                        }
                    }
                }
            }
        }
    }

    func disconnect() {
        Task {
            await doDisconnectAsync()
        }
    }
    
    func signMessage(request: WalletRequest, message: String, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        LocalAuthenticator.shared?.paused = true
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else if let wallet = self?._walletStatus.connectedWallet {
                connected?(wallet)
                self?.executeWithDeeplink(request: request) { success in
                    if success {
                        self?.reallySignMessage(message: message) { [weak self] signed, error in
                            LocalAuthenticator.shared?.paused = false
                            if error != nil {
                                self?.disconnect()
                            }
                            completion(signed, error)
                        }
                    } else {
                        completion(nil, WalletError.error(code: .linkOpenFailed))
                    }
                }
            } else {
                assertionFailure("wallet not found")
            }
        }
    }
    
    func sign(request: WalletRequest, typedDataProvider: WalletTypedDataProviderProtocol?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        LocalAuthenticator.shared?.paused = true
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else if let wallet = self?._walletStatus.connectedWallet {
                connected?(wallet)
                self?.executeWithDeeplink(request: request) { success in
                    if success {
                        self?.reallySign(typedDataProvider: typedDataProvider) { [weak self] signed, error in
                            LocalAuthenticator.shared?.paused = false
                            if error != nil {
                                self?.disconnect()
                            }
                            completion(signed, error)
                        }
                    } else {
                        completion(nil, WalletError.error(code: .linkOpenFailed))
                    }
                }
            } else {
                assertionFailure("wallet not found")
            }
        }
    }
    
    func send(request: WalletTransactionRequest, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        guard let ethereumTransactionRequest = request.ethereum else {
            assertionFailure("Unexpected transaction type.")
            return
        }

        guard let transaction = Transaction(ethereumTransactionRequest: ethereumTransactionRequest) else {
            assertionFailure("Unable to translate request to  Ethereum transaction.")
            return
        }

        LocalAuthenticator.shared?.paused = true
        connect(request: request.walletRequest) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else if let wallet = self?._walletStatus.connectedWallet {
                connected?(wallet)
                self?.executeWithDeeplink(request: request.walletRequest) { success in
                    if success {
                        self?.reallySend(transaction: transaction) { [weak self] response, error in
                            LocalAuthenticator.shared?.paused = false
                            if error != nil {
                                self?.disconnect()
                            }
                            completion(response, error)
                        }
                    } else {
                        completion(nil, WalletError.error(code: .linkOpenFailed))
                    }
                }
            }  else {
                assertionFailure("wallet not found")
            }
        }
    }
    
    func addChain(request: WalletRequest, chain: EthereumAddChainRequest, timeOut: TimeInterval? = nil, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        guard request.wallet?.config?.methods?.contains("wallet_addEthereumChain") ?? false else {
            completion(nil, WalletError.error(code: .addChainNotSupported))
            return
        }
        
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
                self?.executeWithDeeplink(request: request) { success in
                    if success {
                        self?.reallyAddChain(chain: chain, timeOut: timeOut) { [weak self] response, error in
                            LocalAuthenticator.shared?.paused = false
                            if error != nil {
                                self?.disconnect()
                            }
                            completion(response, error)
                        }
                    } else {
                        completion(nil, WalletError.error(code: .addChainFailed))
                    }
                }
            }
        }
    }
    
    private func executeWithDeeplink(request: WalletRequest, block: @escaping ((Bool) -> Void)) {
        if request.wallet != nil {
            openLaunchDeeplink() { success in
                block(success)
            }
        } else {
            block(true)
        }
    }
    
    private func doConnect(chainId: Int?, methods: [String]?) async -> WalletConnectURI? {
        Console.shared.log("[PROPOSER] Connecting to a pairing...")
        let chainId = chainId ?? 1
        let chains: Set<Blockchain> = Set([ Blockchain("eip155:\(chainId)")! ])
        let namespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: Array(chains),
                methods: Set(methods ?? [
                    "eth_sendTransaction",
                    "personal_sign",
                    "eth_signTypedData"
                ]),
                events: [
                ]
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [:]
        let sessionProperties: [String: String] = [
            "caip154-mandatory": "true"
        ]
        
        do {
            return try await Sign.instance.connect(
                requiredNamespaces: namespaces,
                optionalNamespaces: optionalNamespaces,
                sessionProperties: sessionProperties
            )
        } catch {
            Console.shared.log(error)
            return nil
        }
        
    }
    
    private func doDisconnectAsync() async {
        if let session = currentSession {
            do {
                try await Sign.instance.disconnect(topic: session.topic)
                DispatchQueue.main.async { [weak self] in
                    self?.resetStates()
                }
            } catch {
                Console.shared.log(error)
            }
        }
    }
    
    private func resetStates() {
        currentSession = nil
        uri = nil
        requestingWallet = nil
        _walletStatus.connectedWallet = nil
        _walletStatus.state = .idle
        connectCompletions = []
        operationCompletions = [:]
        openUrlCompletions = []
    }
    
    private func reallySignMessage(message: String, completion: @escaping WalletOperationCompletion) {
        guard let session = currentSession,
              let account = session.namespaces.first?.value.accounts.first?.address,
              let chainId = session.namespaces.first?.value.accounts.first?.blockchain else {
            completion(nil, WalletError.error(code: .invalidSession))
            return
        }
        
        let payload = AnyCodable([message, account])
        guard let request = try? Request(topic: session.topic, method: "personal_sign", params: payload, chainId: chainId) else {
            completion(nil, WalletError.error(code: .invalidInput))
            return
        }
    
        operationCompletions[request.id] = completion
        Task {
            do {
                try await Sign.instance.request(params: request)
                
            } catch {
                Console.shared.log(error)
                DispatchQueue.main.async { [weak self] in
                    completion(nil, WalletError.error(code: .signingMessageFailed, message: error.localizedDescription))
                    self?.operationCompletions.removeValue(forKey: request.id)
                }
            }
        }
    }
    
    private func reallySign(typedDataProvider: WalletTypedDataProviderProtocol?, completion: @escaping WalletOperationCompletion) {
        guard let session = currentSession,
              let account = session.namespaces.first?.value.accounts.first?.address,
              let chainId =  session.namespaces.first?.value.accounts.first?.blockchain else {
            completion(nil, WalletError.error(code: .invalidSession))
            return
        }
        guard let typeDataString = typedDataProvider?.typedDataAsString else {
            completion(nil, WalletError.error(code: .invalidInput, message: "invalid typedData"))
            return
        }
        
        let payload = AnyCodable([account, typeDataString])
        guard let request = try? Request(topic: session.topic, method: "eth_signTypedData", params: payload, chainId: chainId) else {
            completion(nil, WalletError.error(code: .invalidInput))
            return
        }
    
        operationCompletions[request.id] = completion
        Task {
            do {
                try await Sign.instance.request(params: request)
                
            } catch {
                Console.shared.log(error)
                DispatchQueue.main.async { [weak self] in
                    completion(nil, WalletError.error(code: .signingMessageFailed, message: error.localizedDescription))
                    self?.operationCompletions.removeValue(forKey: request.id)
                }
            }
        }
    }
    
    private func reallySend(transaction: Transaction, completion: @escaping WalletOperationCompletion) {
        guard let session = currentSession,
              let chainId =  session.namespaces.first?.value.accounts.first?.blockchain else {
            completion(nil, WalletError.error(code: .invalidSession))
            return
        }
     
        let payload = AnyCodable([transaction])
        guard let request = try? Request(topic: session.topic, method: "eth_sendTransaction", params: payload, chainId: chainId) else {
            completion(nil, WalletError.error(code: .invalidInput))
            return
        }
    
        operationCompletions[request.id] = completion
        Task {
            do {
                try await Sign.instance.request(params: request)
            } catch {
                Console.shared.log(error)
                DispatchQueue.main.async { [weak self] in
                    completion(nil, WalletError.error(code: .signingTransactionFailed, message: error.localizedDescription))
                    self?.operationCompletions.removeValue(forKey: request.id)
                }
            }
        }
    }
    
    private func reallyAddChain(chain: EthereumAddChainRequest, timeOut: TimeInterval? = nil, completion: @escaping WalletOperationCompletion) {
        guard let session = currentSession,
              let chainId =  session.namespaces.first?.value.accounts.first?.blockchain else {
            completion(nil, WalletError.error(code: .invalidSession))
            return
        }
     
        let payload = AnyCodable([chain])
        guard let request = try? Request(topic: session.topic, method: "wallet_addEthereumChain", params: payload, chainId: chainId) else {
            completion(nil, WalletError.error(code: .invalidInput))
            return
        }
    
        operationCompletions[request.id] = completion
        Task {
            do {
                try await Sign.instance.request(params: request)
                
                if let timeOut = timeOut {
                    DispatchQueue.main.asyncAfter(deadline: .now() + timeOut) { [weak self] in
                        if let completion = self?.operationCompletions[request.id] {
                            completion(nil, WalletError.error(code: .addChainFailed))
                            self?.operationCompletions.removeValue(forKey: request.id)
                        }
                    }
                }
            } catch {
                Console.shared.log(error)
                DispatchQueue.main.async { [weak self] in
                    completion(nil, WalletError.error(code: .addChainFailed, message: error.localizedDescription))
                    self?.operationCompletions.removeValue(forKey: request.id)
                }
            }
        }
    }

    private func openLaunchDeeplink(completion: ((Bool) -> Void)? = nil) {
        if background == false {
            if let wallet = _walletStatus.connectedWallet?.wallet ?? requestingWallet,
               let deeplink = uri?.absoluteString,
               let url = WalletConnectUtils.createUrl(wallet: wallet, deeplink: deeplink, type: .walletConnectV2),
               let urlHandler = URLHandler.shared,
               urlHandler.canOpenURL(url) {
                beginBackgroundTask()
                urlHandler.open(url, completionHandler: completion)
            } else {
                completion?(false)
            }
        } else {
            completion?(true)
          //  openUrlCompletions.append(completion)
        }
    }
    
    private func observeChanges() {
        Sign.instance.socketConnectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { (status: SocketConnectionStatus) in
                Console.shared.log("WalletConnectV2 socketConnectionStatus: \(status)")
            }
            .store(in: &publishers)
        
        Sign.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { (string, reason) in
                Console.shared.log("WalletConnectV2 sessionDelete: \(string) \(reason)")
            }
            .store(in: &publishers)

        Sign.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                Console.shared.log("WalletConnectV2 sessionResponse: \(response)")
                     
                if let completion = self?.operationCompletions[response.id] {
                    self?.operationCompletions.removeValue(forKey: response.id)
                    switch response.result {
                    case .response(let response):
                        let decodedString = try? response.get(String.self)
                        completion(decodedString, nil)
                    case .error(let error):
                        completion(nil, WalletError.error(code: .connectionFailed, message: error.message))
                    }
                }
            }
            .store(in: &publishers)

        Sign.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                Console.shared.log("WalletConnectV2 sessionSettle: \(session)")
                self?.currentSession = session
                self?._walletStatus.connectedWallet = WalletInfo(session: session, wallet: self?.requestingWallet)
                self?.connectCompletions.forEach { completion in
                    completion(self?._walletStatus.connectedWallet, nil)
                }
                self?.connectCompletions = []
                self?._walletStatus.state = .connectedToWallet
            }
            .store(in: &publishers)
        
        Sign.instance.sessionRejectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (proposal: Session.Proposal, reason: Reason) in
                Console.shared.log("WalletConnectV2 sessionRejectionPublisher: \(reason)")
                self?.connectCompletions.forEach { completion in
                    completion(nil, WalletError.error(code: .refusedByWallet, message: reason.message))
                }
            }
            .store(in: &publishers)
        
        Sign.instance.sessionEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { (event: Session.Event, sessionTopic: String, chainId: Blockchain?) in
                Console.shared.log("WalletConnectV2 sessionEventPublisher: \(sessionTopic)")
            }
            .store(in: &publishers)
        
        Sign.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { sessions in
                Console.shared.log("WalletConnectV2 sessionsPublisher: \(sessions.count)")
            }
            .store(in: &publishers)
    }

}

extension WalletInfo {
    convenience init(session: Session, wallet: Wallet?) {
         let account = session.namespaces.values.first?.accounts.first
         let address = account?.address
         let chainId: Int?
         if let reference = account?.reference {
             chainId = Int(reference)
         } else {
             chainId = nil
         }
         let name = session.peer.name
         let imageUrl: URL?
         if let icon = session.peer.icons.first, let url = URL(string: icon) {
             imageUrl = url
         } else {
             imageUrl = nil
         }
         self.init(address: address, chainId: chainId, wallet: wallet, peerName: name, peerImageUrl: imageUrl)
     }
}

struct Transaction: Codable {
    let from, to, data: String
    
    init?(ethereumTransactionRequest: EthereumTransactionRequest) {
        let transaction = ethereumTransactionRequest.transaction
        
        if let from = transaction.from, let to = transaction.to {
    
            let dataText = transaction.data.hex()
         
            self.from = from.hex(eip55: false)
            self.to = to.hex(eip55: false)
            self.data =  dataText
        } else {
            return nil
        }
    }
}

//
//  WalletConnectV1Provider.swift
//
//  Created by Rui Huang on 7/26/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import BigInt
import CryptoKit
import WalletConnectSwift
import Web3
import UIKit
import Commons

final class WalletConnectV1Provider: NSObject, WalletOperationProviderProtocol {
    private static let responseDelayBackground = 0.5
    private static let responseDelayForeground = 0.5

    private var responseDelay: Double {
        background ? Self.responseDelayBackground : Self.responseDelayForeground
    }

    private var config: WalletConnectV1Config? {
        CarteraConfig.shared.walletProvidersConfig.walletConnectV1
    }
    
    private let sessionTag = "\(Swift.type(of: WalletConnectV1Provider.self)).session"

    private var expected: WalletInfo?

    private var client: Client? {
        didSet {
            if client !== oldValue {
                if let session = session {
                    try? oldValue?.disconnect(from: session)
                }
            }
        }
    }

    private var session: Session? {
        didSet {
            if session != nil {
                if let sessionData = try? JSONEncoder().encode(session) {
                    UserDefaults.standard.set(sessionData, forKey: sessionTag)
                } else {
                    assertionFailure()
                }
            } else {
                if !background {
                    UserDefaults.standard.removeObject(forKey: sessionTag)
                }
            }
        }
    }

    private var wc: WCURL? {
        didSet {
            if wc != oldValue {
                _walletStatus.connectionDeeplink = wc?.absoluteString
            }
        }
    }

    private var background: Bool = false {
        didSet {
            if background != oldValue {
                if !background {
                    if session != nil {
                        reconnect()
                    }
                }
            }
        }
    }

    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    private var connectionCompletion: WalletConnectCompletion?

    private var launchDeeplink: String? {
        return launchLink(wcDeeplink: _walletStatus.connectionDeeplink)
    }

    private var foregroundToken: NotificationToken?
    private var backgroundToken: NotificationToken?
    
    private var _walletStatus = WalletStatusImp() {
        didSet {
            if _walletStatus.state != oldValue.state {
                switch _walletStatus.state {
                case .idle, .listening:
                    break

                case .connectedToServer:
                    launch()

                case .connectedToWallet:
                    break // revive()
                }
            }
            
            walletStatusDelegate?.statusChanged(_walletStatus)
        }
    }
    
    override init() {
        super.init()
        
        backgroundToken = NotificationCenter.default.observe(notification: UIApplication.didEnterBackgroundNotification, do: { [weak self] _ in
            self?.background = true
        })
        foregroundToken = NotificationCenter.default.observe(notification: UIApplication.willEnterForegroundNotification, do: { [weak self] _ in
            self?.background = false
        })
    }

    deinit {
        reset()
    }

    // MARK: WalletStatusProtocol

    var walletStatus: WalletStatusProtocol? {
        _walletStatus
    }
    var walletStatusDelegate: WalletStatusDelegate?

    // MARK: WalletOperationProtocol

    var userConsentDelegate: WalletUserConsentProtocol?

    func connect(request: WalletRequest, completion: @escaping WalletConnectCompletion) {
        switch _walletStatus.state {
        case .idle:
            expected = WalletInfo(address: request.address, chainId: request.chainId, wallet: request.wallet)
            connectionCompletion = completion
            listen()

        case .listening:
            connectionCompletion = completion
            launch()

        case .connectedToServer:
            connectionCompletion = completion
            revive()

        case .connectedToWallet:
            connectionCompletion = completion
            runCompletion(_walletStatus.connectedWallet, nil)
            //revive()
        }
    }

    func disconnect() {
        if let session = session {
            try? client?.disconnect(from: session)
            self.session = nil
        }

        client = nil
        _walletStatus.state = .idle
        _walletStatus.connectedWallet = nil
    }

    func signMessage(request: WalletRequest, message: String, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        LocalAuthenticator.shared?.paused = true
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
                self?.openLaunchDeeplink()
                self?.reallySignMessage(message: message) { [weak self] signed, error in
                    LocalAuthenticator.shared?.paused = false
                    if error != nil {
                        self?.disconnect()
                    }
                    completion(signed, error)
                }
            }
        }
    }

    func sign(request: WalletRequest, typedDataProvider: WalletTypedDataProviderProtocol?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        LocalAuthenticator.shared?.paused = true
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
                self?.openLaunchDeeplink()
                self?.reallySign(typedDataProvider: typedDataProvider) { [weak self] signed, error in
                    LocalAuthenticator.shared?.paused = false
                    if error != nil {
                        self?.disconnect()
                    }
                    completion(signed, error)
                }
            }
        }
    }

    func send(request: WalletTransactionRequest, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        guard let ethereumTransactionRequest = request.ethereum else {
            assertionFailure("Unexpected transaction type.")
            return
        }

        guard let transaction = translate(ethereumTransactionRequest: ethereumTransactionRequest) else {
            assertionFailure("Unable to translate request to  Ethereum transaction.")
            return
        }

        LocalAuthenticator.shared?.paused = true
        connect(request: request.walletRequest) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
                self?.openLaunchDeeplink()
                self?.reallySend(transaction: transaction) { [weak self] response, error in
                    LocalAuthenticator.shared?.paused = false
                    if error != nil {
                        self?.disconnect()
                    }
                    completion(response, error)
                }
            }
        }
    }

    func addChain(request: WalletRequest, chain: EthereumAddChainRequest, timeOut: TimeInterval?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
                self?.openLaunchDeeplink()
                self?.reallyAddChain(chain: chain) { [weak self] response, error in
                    LocalAuthenticator.shared?.paused = false
                    if error != nil {
                        self?.disconnect()
                    }
                    completion(response, error)
                }
            }
        }
    }
    
    // MARK: Private

    private func translate(ethereumTransactionRequest: EthereumTransactionRequest) -> Client.Transaction? {
        let transaction = ethereumTransactionRequest.transaction
        
        if let from = transaction.from {

            let dataText = transaction.data.hex()
            let valueText = transaction.value?.hex()

            Console.shared.log("Transaction: Value \(transaction.value?.hex() ?? "")")

            return Client.Transaction(from: from.hex(eip55: false),
                                      to: transaction.to?.hex(eip55: false),
                                      data: dataText,
                                      gas: nil,
                                      gasPrice: nil,
                                      value: valueText, 
                                      nonce: nil,
                                      type: nil,
                                      accessList: nil,
                                      chainId: nil,
                                      maxPriorityFeePerGas: nil,
                                      maxFeePerGas: nil)
        } else {
            return nil
        }
    }

    private func reset() {
        disconnect()
    }

    private func launchLink(wcDeeplink: String?) -> String? {
        if let wcDeeplink = wcDeeplink {
            let elements = wcDeeplink.components(separatedBy: "?")
            return elements.first
        }
        return nil
    }

    private func reconnect() {
        if let client = client, let session = session {
            try? client.reconnect(to: session)
        } else if let sessionData = UserDefaults.standard.object(forKey: sessionTag) as? Data {
            if let session = try? JSONDecoder().decode(Session.self, from: sessionData) {
                if client === nil {
                    client = Client(delegate: self, dAppInfo: session.dAppInfo)
                }
                try? client?.reconnect(to: session)
            }
        } else {
            listen()
        }
    }

    private func listen() {
        wc = wcPayload()
        if let wc = wc {
            listen(wc: wc)
        }
        _walletStatus.state = .listening
    }

    private func wcPayload() -> WCURL? {
        guard let bridgeUrl = config?.bridgeUrl, let bridgeUrl = URL(string: bridgeUrl) else {
            assertionFailure("Incomplete WalletConnectV1Config")
            return nil
        }
        
        if let key = try? CryptoUtils.randomKey().lowercased() {
            return WCURL(topic: UUID().uuidString.lowercased(), bridgeURL: bridgeUrl, key: key)
        } else {
            return nil
        }
    }

    private func listen(wc: WCURL) {
        guard let clientName = config?.clientName,
              let iconUrl = config?.iconUrl, let iconUrl = URL(string: iconUrl),
              let clientUrl = config?.clientUrl, let clientUrl = URL(string: clientUrl) else {
            assertionFailure("Incomplete WalletConnectV1Config")
            return
        }
                
        let clientMeta = Session.ClientMeta(name: clientName,
                                            description: config?.clientDescription ?? "",
                                            icons: [iconUrl],
                                            url: clientUrl,
                                            scheme: nil)
        let dAppInfo = Session.DAppInfo(peerId: UUID().uuidString, peerMeta: clientMeta)
        client = Client(delegate: self, dAppInfo: dAppInfo)
        try? client?.connect(to: wc)
    }

    private func launch() {
        if session == nil {
            beginBackgroundTask()
            if let wallet = _walletStatus.connectedWallet?.wallet ?? expected?.wallet,
               let url = WalletConnectUtils.createUrl(wallet: wallet, deeplink: _walletStatus.connectionDeeplink, type: .walletConnect),
               let urlHandler = URLHandler.shared,
               urlHandler.canOpenURL(url) {
                urlHandler.open(url, completionHandler: nil)
            }
        }
    }

    private func revive() {
        if connectionCompletion != nil {
            if background {
                runCompletion(_walletStatus.connectedWallet, nil)
            } else {
                beginBackgroundTask()
                openLaunchDeeplink()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.runCompletion(self?._walletStatus.connectedWallet, nil)
                }
            }
        }
    }

    private func openLaunchDeeplink() {
        if let wallet = _walletStatus.connectedWallet?.wallet ?? expected?.wallet,
           let url = WalletConnectUtils.createUrl(wallet: wallet, deeplink: launchDeeplink, type: .walletConnect),
           let urlHandler = URLHandler.shared,
           urlHandler.canOpenURL(url) {
            urlHandler.open(url, completionHandler: nil)
        }
    }
    
    private func runCompletion(_ walletInfo: WalletInfo?, _ error: Error?) {
        connectionCompletion?(walletInfo, error)
        connectionCompletion = nil
    }

    private func delay(completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.responseDelayBackground) { /* [weak self] in */
            if CarteraAppState.shared.background {
                completion()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.responseDelayForeground) { /* [weak self] in */
                    completion()
                }
            }
        }
    }

    private func reallySignMessage(message: String, completion: @escaping WalletOperationCompletion) {
        if let client = client, let session = session, let account = session.walletInfo?.accounts.first, let wc = wc {
            Console.shared.log("eth_personalSign: Send")
            Console.shared.log(message)
            do {
                try client.personal_sign(url: wc, message: message, account: account){ [weak self] response in
                    self?.delay {
                        let string = try? response.result(as: String.self)
                        if let error = response.error {
                            Console.shared.log("error:\n \(error)")
                        }
                        completion(string, response.error)
                    }
                }
            } catch {
                completion(nil, WalletError.error(code: .signingMessageFailed))
            }
        } else {
            // assertionFailure("Unable to eth_signTypedData")
        }
    }

    private func reallySign(typedDataProvider: WalletTypedDataProviderProtocol?, completion: @escaping WalletOperationCompletion) {
        if let client = client, let session = session, let account = session.walletInfo?.accounts.first, let wc = wc, let json = typedDataProvider?.typedDataAsString {
            Console.shared.log("eth_signTypedData: Send")
            Console.shared.log(json)
            do {
                try client.eth_signTypedData(url: wc, account: account, message: json) { [weak self] response in
                    self?.delay {
                        let string = try? response.result(as: String.self)
                        if let error = response.error {
                            Console.shared.log("error:\n \(error)")
                        }
                        completion(string, response.error)
                    }
                }
            } catch {
                completion(nil, WalletError.error(code: .signingMessageFailed))
            }
        } else {
            // assertionFailure("Unable to eth_signTypedData")
        }
    }

    private func reallySend(transaction: Client.Transaction, completion: @escaping WalletOperationCompletion) {
        if let client = client, let wc = wc {
            Console.shared.log("eth_sendTransaction: Send")
            do {
                try client.eth_sendTransaction(url: wc, transaction: transaction) { [weak self] response in
                    self?.delay {
                        let string = try? response.result(as: String.self)
                        completion(string, response.error)
                    }
                }
            } catch {
                completion(nil, WalletError.error(code: .signingTransactionFailed))
            }
        } else {
            // assertionFailure("Unable to eth_sendTransaction")
        }
    }
    
    private func reallyAddChain(chain: EthereumAddChainRequest, completion: @escaping WalletOperationCompletion) {
        if let client = client, session != nil, let wc = wc {
            do {
                let request = try WalletConnectSwift.Request(url: wc, method: "wallet_addEthereumChain", params: [chain])
                try client.send(request) { [weak self] (response: Response) in
                    self?.delay {
                        let string = try? response.result(as: String.self)
                        if let error = response.error {
                            Console.shared.log("error:\n \(error)")
                        }
                        completion(string, response.error)
                    }
                }
            } catch {
                completion(nil, WalletError.error(code: .addChainFailed))
            }
        } else {
            // assertionFailure("Unable to wallet_addEthereumChain")
        }
    }

    private func type(name: String, type: String) -> [String: String] {
        return ["name": name, "type": type]
    }

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
}

extension WalletConnectV1Provider: ClientDelegate {
    func client(_ client: Client, didConnect url: WCURL) {
        Console.shared.log("WalletConnect: didConnectUrl")
        DispatchQueue.runInMainThread { [weak self] in
            if let self = self {
                self.wc = url
                self._walletStatus.state = .connectedToServer
                Console.shared.log("WalletConnect: connected URL")
            }
        }
    }

    func client(_ client: Client, didFailToConnect url: WCURL) {
        Console.shared.log("WalletConnect: didFailToConnect")
        DispatchQueue.runInMainThread { [weak self] in
            if let self = self {
                var error: Error?
                if self.wc != nil {
                    if self.session != nil {
                        error = WalletError.error(code: .connectionFailed, message: "Disconnected by wallet")
                    } else {
                        error = WalletError.error(code: .refusedByWallet)
                    }
                } else {
                    error = WalletError.error(code: .connectionFailed, message: "Failed to connect to server")
                }
                self.disconnect()
                self.runCompletion(nil, error)
            }
        }
    }

    func client(_ client: Client, didConnect session: Session) {
        Console.shared.log("WalletConnect: didConnectSession")
        HapticFeedback.shared?.prepareNotify(type: .success)
        HapticFeedback.shared?.prepareNotify(type: .error)
        delay { [weak self] in
            if let self = self {
                self.wc = session.url
                self.client = client
                self.session = session
                if let walletInfo = session.walletInfo, let ethereumAddress = walletInfo.accounts.first {
                    let errorTitle: String?
                    let errorMessage: String?
                    let code: CarteraErrorCode?
                    if let expectedChainId = self.expected?.chainId, expectedChainId != 0, walletInfo.chainId != 0, walletInfo.chainId != expectedChainId {
                        errorTitle = "Network Mismatch"
                        errorMessage = "Please switch network from the wallet"
                        code  = .networkMismatch
                    } else if let expectedEthereumAddress = self.expected?.address, ethereumAddress.lowercased() != expectedEthereumAddress.lowercased() {
                        errorTitle = "Wallet Mismatch"
                        errorMessage = "Please switch your wallet to " + expectedEthereumAddress
                        code = .walletMismatch
                    } else {
                        errorTitle = nil
                        errorMessage = nil
                        code = nil
                    }
                    
                    if let code = code {
                        HapticFeedback.shared?.notify(type: .error)
                        self.reset()
                        self.runCompletion(nil, WalletError.error(code: code, title: errorTitle, message: errorMessage))
                    } else {
                        HapticFeedback.shared?.notify(type: .success)
                        self._walletStatus.connectedWallet = WalletInfo(address: ethereumAddress,
                                                                        chainId: walletInfo.chainId,
                                                                        wallet: self.expected?.wallet,
                                                                        peerName: walletInfo.peerMeta.name,
                                                                        peerImageUrl: walletInfo.peerMeta.icons.first)
                        self._walletStatus.state = .connectedToWallet
                        self.runCompletion(self._walletStatus.connectedWallet, nil)
                    }
                } else {
                    self.disconnect()
                    self.runCompletion(nil, WalletError.error(code: .connectionFailed, message: "Wallet Connect failed"))
                }
            }
        }
    }

    func client(_ client: Client, didUpdate session: Session) {
        Console.shared.log("WalletConnect: didUpdateSession")
//        self.client(client, didConnect: session)
    }

    func client(_ client: Client, didDisconnect session: Session) {
        Console.shared.log("WalletConnect: didDisconnectSession")
        if !background {
            DispatchQueue.runInMainThread { [weak self] in
                self?.disconnect()
            }
        }
    }
}

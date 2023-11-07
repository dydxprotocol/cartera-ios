//
//  WalletSegueProvider.swift
//  dydxWallet
//
//  Created by Rui Huang on 7/26/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import Foundation
import CoinbaseWalletSDK
import web3
import BigInt

final class WalletSegueProvider: NSObject, WalletOperationProviderProtocol {
    
    // MARK: WalletOperationProviderProtocol

    var walletStatus: WalletStatusProtocol? {
        _walletStatus
    }
    var walletStatusDelegate: WalletStatusDelegate?
   
    // MARK: WalletUserConsentOperationProtocol
    
    var userConsentDelegate: WalletUserConsentProtocol?

    // MARK: Private vars
    
    private let cbwallet = CoinbaseWalletSDK.shared
    private var _walletStatus = WalletStatusImp() {
        didSet {
            walletStatusDelegate?.statusChanged(_walletStatus)
        }
    }
    private var account: Account?
   
    // MARK: WalletOperationProtocol
    
    func connect(request: WalletRequest, completion: @escaping WalletConnectCompletion) {
        if _walletStatus.connectedWallet == nil || cbwallet.isConnected() == false {
            _walletStatus.state = .idle
        }
        let wallet = request.wallet
        let expected = WalletInfo(address: request.address, chainId: request.chainId, wallet: wallet)

        switch _walletStatus.state {
        case .idle:
            HapticFeedback.shared?.prepareNotify(type: .success)
            HapticFeedback.shared?.prepareNotify(type: .error)
            cbwallet.initiateHandshake(initialActions: [Action(jsonRpc: .eth_requestAccounts)]) { [weak self] result, account in
                switch result {
                case .success(let response):
                    Console.shared.log("Response:\n \(response.content)")
                    self?.logObject(label: "Account:\n", account)

                    if let account = account {
                        if let expectedChainId = expected.chainId, expectedChainId != 0, account.networkId != expectedChainId {

                            let errorTitle = "Network Mismatch"
                            let errorMessage = expectedChainId == 1 ?
                                "Set your wallet network to 'Ethereum Mainnet'." :
                                "set your wallet network to 'Goerli Test Network'"
                            completion(nil, WalletError.error(code: .networkMismatch, title: errorTitle, message: errorMessage))

                        } else if let expectedEthereumAddress = expected.address, expectedEthereumAddress.lowercased() != account.address.lowercased() {

                            let errorTitle = "Wallet Mismatch"
                            let errorMessage = "Please switch your wallet to " + expectedEthereumAddress
                            completion(nil, WalletError.error(code: .walletMismatch, title: errorTitle, message: errorMessage))

                        } else {
                            HapticFeedback.shared?.notify(type: .success)
                            self?.account = account
                            self?._walletStatus.connectedWallet = WalletInfo(address: account.address,
                                                                             chainId: Int(account.networkId),
                                                                            wallet: wallet)
                            self?._walletStatus.state = .connectedToWallet
                            completion(self?._walletStatus.connectedWallet, nil)
                        }
                    } else {
                        HapticFeedback.shared?.notify(type: .error)
                        completion(nil, WalletError.error(code: .walletContainsNoAccount))
                    }
                case .failure(let error):
                    HapticFeedback.shared?.notify(type: .error)
                    Console.shared.log("error:\n \(error)")
                    completion(nil, error)
                }
            }
        case .listening:
            assertionFailure("Invalid state")
        case .connectedToServer:
            completion(_walletStatus.connectedWallet, nil)
        case .connectedToWallet:
            completion(_walletStatus.connectedWallet, nil)
        }
    }

    func disconnect() {
        _walletStatus.state = .idle
    }

    func signMessage(request: WalletRequest, message: String, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        guard let action = Action(message: message) else {
            assertionFailure("Unable to sign message.")
            completion(nil, WalletError.error(code: .signingMessageFailed))
            return
        }
        
        doSign(request: request, action: action, connected: connected, completion: completion)
    }

    func sign(request: WalletRequest, typedDataProvider: WalletTypedDataProviderProtocol?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        guard let typedDataJson = typedDataProvider,
              let action = Action(signTypedData: typedDataJson) else {
            assertionFailure("Unable to sign request.")
            completion(nil, WalletError.error(code: .signingMessageFailed))
            return
        }
        
        doSign(request: request, action: action, connected: connected, completion: completion)
    }

    private func doSign(request: WalletRequest, action: Action, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        LocalAuthenticator.shared?.paused = true
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
                self?.reallyMakeRequest(action: action) { [weak self] signed, error in
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
        guard let action = Action(sendTransaction: request) else {
            assertionFailure("Unable to translate request to Ethereum transaction.")
            completion(nil, WalletError.error(code: .signingTransactionFailed))
            return
        }

        
        LocalAuthenticator.shared?.paused = true
        connect(request: request.walletRequest) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
                self?.reallyMakeRequest(action: action) { [weak self] response, error in
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
        guard let action = Action(addChain: chain) else {
            assertionFailure("Unable to translate request to Ethereum transaction.")
            completion(nil, WalletError.error(code: .signingTransactionFailed))
            return
        }

        LocalAuthenticator.shared?.paused = true
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
                self?.reallyMakeRequest(action: action) { [weak self] response, error in
                    LocalAuthenticator.shared?.paused = false
                    if error != nil {
                        self?.disconnect()
                    }
                    completion(response, error)
                }
            }
        }
    }

    private func reallyMakeRequest(action: Action, completion: @escaping WalletOperationCompletion) {
        let request = Request(actions: [action], account: nil)
        logObject(label: "Request:\n", request)

        cbwallet.makeRequest(request) { result in
            switch result {
            case .success(let response):
                Console.shared.log("Response:\n \(response.content)")
                if let content = response.content.first {
                    switch content {
                    case .success(let jsonValue):
                        Console.shared.log("Result (raw JSON): \(jsonValue)")
                        if let signature = try? jsonValue.decode(as: String.self) {
                            completion(signature, nil)
                        } else {
                            completion(nil, WalletError.error(code: .unexpectedResponse, message: "Unexpected response payload: \(jsonValue)"))
                        }
                    case .failure(let error):
                        completion(nil, WalletError.error(code: .unexpectedResponse, message: "Unexpected response payload: \(error.code), \(error.message)"))
                    }
                }
            case .failure(let error):
                Console.shared.log("error:\n \(error)")
                completion(nil, error)
            }
        }
    }
}

private extension Action {
    init?(message: String) {
        self.init(jsonRpc: .personal_sign(address: "", message: message))
    }
    
    init?(signTypedData typedDataProvider: WalletTypedDataProviderProtocol) {
        if let typedDataAsString = typedDataProvider.typedDataAsString,
           let typedDataJson = JSONString(rawValue: typedDataAsString) {
            self.init(jsonRpc: .eth_signTypedData_v3(
                address: "",
                typedDataJson: typedDataJson
            ))
        } else {
            return nil
        }
    }

    init?(sendTransaction transactionRequest: WalletTransactionRequest) {
        if let ethereum = transactionRequest.ethereum,
           let from = ethereum.transaction.from {

            let chainId = transactionRequest.walletRequest.chainId
            let transaction = ethereum.transaction
            let gasPrice =  ethereum.gasPrice
            let gas = ethereum.gas

            let dataText = transaction.data?.web3.hexString ?? "0x"
            let gasText = String(bigUInt: gas)
            let gasPriceText = String(bigUInt: gasPrice)
            let valueText = String(bigUInt: transaction.value) ?? "0"
            let nonce: Int? = nil
            let chainIdText: String
            if let chainId = chainId {
                chainIdText = "\(chainId)"
            } else {
                chainIdText = "1"
            }

            self.init(jsonRpc: .eth_sendTransaction(
                fromAddress: from.asString().uppercased(),
                toAddress: ethereum.transaction.to.asString(),
                weiValue: valueText,
                data: dataText,
                nonce: nonce,
                gasPriceInWei: gasPriceText,
                maxFeePerGas: nil,
                maxPriorityFeePerGas: nil,
                gasLimit: gasText,
                chainId: chainIdText)
            )
        } else {
            return nil
        }
    }
    
    init?(addChain chain: EthereumAddChainRequest) {
        let nativeCurrency: AddChainNativeCurrency?
        if let chainCurrency = chain.nativeCurrency {
            nativeCurrency = AddChainNativeCurrency(name: chainCurrency.name,
                                                    symbol: chainCurrency.symbol,
                                                    decimals: Int(chainCurrency.decimals))
        } else {
            nativeCurrency = nil
        }
        let jsonRpc =  Web3JSONRPC.wallet_addEthereumChain(chainId: chain.chainId,
                                                           blockExplorerUrls: chain.blockExplorerUrls,
                                                           chainName: chain.chainName,
                                                           iconUrls: chain.iconUrls,
                                                           nativeCurrency:  nativeCurrency,
                                                           rpcUrls: chain.rpcUrls ?? [])
        self.init(jsonRpc: jsonRpc)
    }
}

private extension String {
    init?(bigUInt: BigUInt?) {
        if let int = bigUInt {
            self = "\(int)"
        } else {
            return nil
        }
    }
}

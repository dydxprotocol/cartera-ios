//
//  MagicAuthHandler.swift
//  dydxWallet
//
//  Created by Rui Huang on 9/2/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//
/*
import Foundation
import MagicSDK
import MagicSDK_Web3

final class MagicLinkProvider: NSObject, WalletOperationProviderProtocol {
   
    // MARK: Private vars
   
    private var web3: Web3?

    private var _walletStatus = WalletStatusImp() {
        didSet {
            walletStatusDelegate?.statusChanged(_walletStatus)
        }
    }
    
    // MARK: WalletStatusProtocol

    var walletStatus: WalletStatusProtocol? {
        _walletStatus
    }
    var walletStatusDelegate: WalletStatusDelegate?

    // MARK: WalletOperationProtocol

    var userConsentDelegate: WalletUserConsentProtocol?

    func connect(request: WalletRequest, completion: @escaping WalletConnectCompletion) {
        let wallet = request.wallet
        switch _walletStatus.state {
        case .idle:
            Magic.shared.user.getMetadata { [weak self] resp in
                Console.shared.log("getMetadata Response:\n \(resp)")
                if let error = resp.error {
                    Console.shared.log("error:\n \(error)")
                    completion(nil, error)
                } else if let result = resp.result {
                    self?.web3 = Web3(provider: Magic.shared.rpcProvider)
                    self?._walletStatus.connectedWallet = WalletInfo(address: result.publicAddress,
                                                                     chainId: request.chainId,
                                                                     wallet: wallet)
                    self?._walletStatus.state = .connectedToWallet
                    completion(self?._walletStatus.connectedWallet, nil)
                } else {
                    assertionFailure("Unexpected response")
                    completion(nil, WalletError.error(message: "getMetadata failed"))
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
        LocalAuthenticator.shared?.paused = true
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
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
        guard let typedData = typedDataProvider?.typedData(),
              let typedDataV3 = MagicSDK.EIP712TypedData(typedData: typedData) else {
            assertionFailure("Unable to sign request.")
            completion(nil, WalletError.error(message: "sign failed"))
            return
        }

        LocalAuthenticator.shared?.paused = true
        connect(request: request) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
                self?.reallySign(typedDataV3: typedDataV3) { [weak self] signed, error in
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
        guard let transaction = MagicSDK_Web3.EthereumTransaction(sendTransaction: request)else {
            assertionFailure("Unable to translate request to Ethereum transaction.")
            completion(nil, WalletError.error(message: "send failed"))
            return
        }

        LocalAuthenticator.shared?.paused = true
        connect(request: request.walletRequest) { [weak self] _, error in
            if let error = error {
                LocalAuthenticator.shared?.paused = false
                completion(nil, error)
            } else {
                connected?(self?._walletStatus.connectedWallet)
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

    // MARK: Private

    private func reallySignMessage(message: String, completion: @escaping WalletOperationCompletion) {
        if let address = _walletStatus.connectedWallet?.address,
            let ethereumAddress = try? EthereumAddress(ethereumValue: address) {
            logObject(label: "personalSign Request:\n", message)

            if let data = try? EthereumData.string(message) {
                web3?.eth.sign(from: ethereumAddress, message: data) { resp in
                    Console.shared.log("personalSign Response:\n \(resp)")
                    if let error = resp.error {
                        Console.shared.log("error:\n \(error)")
                        completion(nil, error)
                    } else if let result = resp.result, let signature = result.ethereumValue().string {
                        completion(signature, nil)
                    } else {
                        assertionFailure("Unexpected response")
                        completion(nil, WalletError.error(message: "sign failed"))
                    }
                }
            } else {
                completion(nil, WalletError.error(message: "sign failed"))
            }
        } else {
            completion(nil, WalletError.error(message: "sign failed"))
        }
    }

    private func reallySign(typedDataV3: MagicSDK.EIP712TypedData, completion: @escaping WalletOperationCompletion) {
        if let address = _walletStatus.connectedWallet?.address,
            let ethereumAddress = try? EthereumAddress(ethereumValue: address) {
            logObject(label: "signTypedDataV3 Request:\n", typedDataV3)

            web3?.eth.signTypedDataV3(account: ethereumAddress, data: typedDataV3) { resp in
                Console.shared.log("signTypedDataV3 Response:\n \(resp)")
                if let error = resp.error {
                    Console.shared.log("error:\n \(error)")
                    completion(nil, error)
                } else if let result = resp.result, let signature = result.ethereumValue().string {
                    completion(signature, nil)
                } else {
                    assertionFailure("Unexpected response")
                    completion(nil, WalletError.error(message: "sign failed"))
                }
            }
        } else {
            completion(nil, WalletError.error(message: "sign failed"))
        }
    }

    private func reallySend(transaction: MagicSDK_Web3.EthereumTransaction, completion: @escaping WalletOperationCompletion) {
        logObject(label: "sendTransaction Request:\n", transaction)

        web3?.eth.sendTransaction(transaction: transaction) { resp in
            Console.shared.log("sendTransaction Response:\n \(resp)")
            if let error = resp.error {
                Console.shared.log("error:\n \(error)")
                completion(nil, error)
            } else if let result = resp.result, let signature = result.ethereumValue().string {
                completion(signature, nil)
            } else {
                assertionFailure("Unexpected response")
                completion(nil, WalletError.error(message: "sendTransaction failed"))
            }
        }
    }
}

private extension MagicSDK.EIP712TypedData {
    init?(typedData: [String: Any]) {
        var mutated = typedData

        if var domain = typedData["domain"] as? [String: Any] {
            domain["verifyingContract"] = ""
            mutated["domain"] = domain
        }

        if let data = try? JSONSerialization.data(withJSONObject: mutated, options: .withoutEscapingSlashes),
           let magicLinkData = try? JSONDecoder().decode(MagicSDK.EIP712TypedData.self, from: data) {
            self = magicLinkData
        } else {
            return nil
        }
    }
}

private extension MagicSDK_Web3.EthereumTransaction {
    init?(sendTransaction transactionRequest: WalletTransactionRequest) {
        if let ethereum = transactionRequest.ethereum,
            let address = ethereum.transaction.from?.value,
            let from = try? EthereumAddress(ethereumValue: address),
            let to = try? EthereumAddress(ethereumValue: ethereum.transaction.to.value) {
            self.init(nonce: nil,
                      gasPrice: EthereumQuantity(bigUInt: ethereum.gasPrice),
                      gas: EthereumQuantity(bigUInt: ethereum.gas),
                      from: from,
                      to: to,
                      value: EthereumQuantity(bigUInt: ethereum.transaction.value),
                      data: EthereumData(ethereum.transaction.data?.makeBytes() ?? [])
            )
        } else {
            return nil
        }
    }
}

private extension EthereumQuantity {
    init?(bigUInt: BigUInt?) {
        if let bigUInt = bigUInt {
            self.init(quantity: bigUInt)
        } else {
            return nil
        }
    }
}
*/

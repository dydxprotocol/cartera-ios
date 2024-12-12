//
//  WalletOperationProtocol.swift
//  dydxWallet
//
//  Created by Rui Huang on 7/26/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import Foundation
import Web3
import BigInt

public struct WalletRequest: Equatable, Hashable {
    public let wallet: Wallet?
    public let address: String?
    public let chainId: Int
    public let useModal: Bool

    public init(wallet: Wallet?, address: String?, chainId: Int, useModal: Bool) {
        self.wallet = wallet
        self.address = address
        self.chainId = chainId
        self.useModal = useModal
    }
}

public struct WalletTransactionRequest {
    public let walletRequest: WalletRequest
    // Union of transaction request types
    public let ethereum: EthereumTransactionRequest?

    public init(walletRequest: WalletRequest, ethereum: EthereumTransactionRequest?) {
        self.walletRequest = walletRequest
        self.ethereum = ethereum
    }
}

public struct EthereumTransactionRequest {
    public let transaction: EthereumTransaction

    public init(transaction: EthereumTransaction) {
        self.transaction = transaction
    }
}

/// https://eips.ethereum.org/EIPS/eip-3085
public struct EthereumAddChainRequest: Codable {
    public struct NativeCurrency: Codable {
        let name: String
        let symbol: String
        let decimals: BigUInt
    }
    public let chainId: String
    public let chainName: String?
    public let rpcUrls: [String]?
    public let iconUrls: [String]?
    public let nativeCurrency: NativeCurrency?
    public let blockExplorerUrls: [String]?

    public init(chainId: String, chainName: String? = nil, rpcUrls: [String]? = nil, iconUrls: [String]? = nil, nativeCurrency: EthereumAddChainRequest.NativeCurrency? = nil, blockExplorerUrls: [String]? = nil) {
        self.chainId = chainId
        self.chainName = chainName
        self.rpcUrls = rpcUrls
        self.iconUrls = iconUrls
        self.nativeCurrency = nativeCurrency
        self.blockExplorerUrls = blockExplorerUrls
    }
}

public typealias WalletConnectedCompletion = (_ info: WalletInfo?) -> Void
public typealias WalletOperationCompletion = (_ signed: String?, _ error: Error?) -> Void
public typealias WalletConnectCompletion = (_ info: WalletInfo?, _ error: Error?) -> Void

public protocol WalletOperationProtocol {
    func connect(request: WalletRequest, completion: @escaping WalletConnectCompletion)
    func disconnect()
    func signMessage(request: WalletRequest, message: String, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion)
    func sign(request: WalletRequest, typedDataProvider: WalletTypedDataProviderProtocol?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion)
    func send(request: WalletTransactionRequest, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion)
    func addChain(request: WalletRequest, chain: EthereumAddChainRequest, timeOut: TimeInterval?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion)
}

public protocol WalletUserConsentOperationProtocol: WalletOperationProtocol {
    var userConsentDelegate: WalletUserConsentProtocol? { get set }
}

public protocol WalletOperationProviderProtocol: WalletStatusProviding, WalletUserConsentOperationProtocol, NSObjectProtocol {}

public extension WalletOperationProtocol {
    func logObject<T: Encodable>(label: String = "", _ object: T, function: String = #function) {
        #if DEBUG
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(object)
            let jsonString = String(data: data, encoding: .utf8)!
            Console.shared.log("\(label)\(jsonString)")
        } catch {
            Console.shared.log("\(error)")
        }
        #endif
    }
}

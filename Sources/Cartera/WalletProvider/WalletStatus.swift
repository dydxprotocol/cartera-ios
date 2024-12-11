//
//  WalletStatus.swift
//  Cartera
//
//  Created by Rui Huang on 2/22/23.
//

import Foundation

public class WalletInfo {
    public var address: String?
    public var chainId: Int?
    public var wallet: Wallet?
    public var peerName: String?
    public var peerImageUrl: URL?

    public init(address: String?, chainId: Int?, wallet: Wallet?, peerName: String? = nil, peerImageUrl: URL? = nil) {
        self.address = address
        self.chainId = chainId
        self.wallet = wallet
        self.peerName = peerName
        self.peerImageUrl = peerImageUrl
    }
}

public enum WalletState: String {
    case idle
    case listening
    case connectedToServer
    case connectedToWallet
}

public protocol WalletStatusProtocol {
    var connectedWallet: WalletInfo? { get }
    var state: WalletState { get }
    var connectionDeeplink: String? { get }
}

public protocol WalletStatusDelegate {
    func statusChanged(_ status: WalletStatusProtocol)
}

public protocol WalletStatusProviding {
    var walletStatus: WalletStatusProtocol? { get }
    var walletStatusDelegate: WalletStatusDelegate? { get set }
}

struct WalletStatusImp: WalletStatusProtocol {
    var connectedWallet: WalletInfo?
    var state: WalletState = .idle
    var connectionDeeplink: String?
}

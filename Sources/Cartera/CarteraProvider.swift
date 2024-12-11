//
//  CarteraProvider.swift
//  Cartera
//
//  Created by Rui Huang on 2/23/23.
//

import Foundation

public final class CarteraProvider: NSObject, WalletOperationProviderProtocol {
    private var currentRequestHandler: WalletOperationProviderProtocol?
    
    private let debugLinkHandler = WalletConnectionType.walletConnectV2
    
    public func startDebugLink(chainId: Int, completion: @escaping WalletConnectCompletion) {
        currentRequestHandler = CarteraConfig.shared.getProvider(of: debugLinkHandler)
        userConsentDelegate = SkippedWalletUserConsent()
        currentRequestHandler?.walletStatusDelegate = walletStatusDelegate
        let request = WalletRequest(wallet: nil, address: nil, chainId: chainId, useModal: false)
        currentRequestHandler?.connect(request: request, completion: completion)
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: WalletOperationProviderProtocol
    
    public var walletStatus: WalletStatusProtocol? {
        currentRequestHandler?.walletStatus
    }
    
    public var walletStatusDelegate: WalletStatusDelegate? {
        didSet {
            currentRequestHandler?.walletStatusDelegate = walletStatusDelegate
        }
    }
    
    public var userConsentDelegate: WalletUserConsentProtocol? {
        didSet {
            currentRequestHandler?.userConsentDelegate = userConsentDelegate
        }
    }
    
    public func connect(request: WalletRequest, completion: @escaping WalletConnectCompletion) {
        updateCurrentHandler(request: request)
        currentRequestHandler?.connect(request: request, completion: completion)
    }
    
    public func disconnect() {
        currentRequestHandler?.disconnect()
    }

    public func signMessage(request: WalletRequest, message: String, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        updateCurrentHandler(request: request)
        currentRequestHandler?.signMessage(request: request, message: message, connected: connected, completion: completion)
    }

    public func sign(request: WalletRequest, typedDataProvider: WalletTypedDataProviderProtocol?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        updateCurrentHandler(request: request)
        currentRequestHandler?.sign(request: request, typedDataProvider: typedDataProvider, connected: connected, completion: completion)
    }

    public func send(request: WalletTransactionRequest, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        updateCurrentHandler(request: request.walletRequest)
        userConsentDelegate?.showTransactionConsent(request: request) { [weak self] status in
            switch status {
            case .consented:
                self?.currentRequestHandler?.send(request: request, connected: connected, completion: completion)
            case .rejected:
                let error = WalletError.error(code: .userCanceled, message: "User canceled")
                completion(nil, error)
            }
        }
    }
    
    public func addChain(request: WalletRequest, chain: EthereumAddChainRequest, timeOut: TimeInterval?, connected: WalletConnectedCompletion?, completion: @escaping WalletOperationCompletion) {
        updateCurrentHandler(request: request)
        // Disregard chainId, since we don't want to check for chainId match here.
        let request = WalletRequest(wallet: request.wallet, address: request.address, chainId: request.chainId, useModal: request.useModal)
        currentRequestHandler?.addChain(request: request, chain: chain, timeOut: timeOut, connected: connected, completion: completion)
    }
    
    // MARK: Private
    
    private func updateCurrentHandler(request: WalletRequest) {
        var newHandler: WalletOperationProviderProtocol?
        if request.useModal {
            newHandler = CarteraConfig.shared.getProvider(of: .walletConnectModal)
        } else if let connectionType = request.wallet?.config?.connectionType {
            newHandler = CarteraConfig.shared.getProvider(of: connectionType)
        } else {
            newHandler = CarteraConfig.shared.getProvider(of: debugLinkHandler) // Debug QR-Code
        }
        
        if newHandler !== currentRequestHandler {
            currentRequestHandler?.disconnect()
            currentRequestHandler?.walletStatusDelegate = nil
            currentRequestHandler?.userConsentDelegate = nil
            
            currentRequestHandler = newHandler
            userConsentDelegate = getUserActionDelegate(request: request)
            currentRequestHandler?.walletStatusDelegate = walletStatusDelegate
        }
        
        if request.wallet != currentRequestHandler?.walletStatus?.connectedWallet?.wallet {
            currentRequestHandler?.disconnect()
        }
    }
    
    private func getUserActionDelegate(request: WalletRequest) -> WalletUserConsentProtocol {
        if let connectionType = request.wallet?.config?.connectionType,
           let userConsentHandler = CarteraConfig.shared.getUserConsentHandler(of: connectionType) {
            return userConsentHandler
        }

        return SkippedWalletUserConsent()
    }
}

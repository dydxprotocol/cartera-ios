//
//  WalletConsent.swift
//  Cartera
//
//  Created by Rui Huang on 2/22/23.
//

import Foundation

public enum WalletUserConsentStatus {
    case consented
    case rejected
}

public typealias WalletUserConsentCompletion = (_ consentStatus: WalletUserConsentStatus) -> Void

public protocol WalletUserConsentProtocol {
    func showTransactionConsent(request: WalletTransactionRequest, completion: WalletUserConsentCompletion?)
}

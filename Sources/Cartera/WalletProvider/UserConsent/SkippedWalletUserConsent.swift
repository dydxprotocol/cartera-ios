//
//  SkippedWalletUserAction.swift
//  dydxWallet
//
//  Created by Rui Huang on 9/20/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import Foundation

final class SkippedWalletUserConsent: WalletUserConsentProtocol {
    func showTransactionConsent(request: WalletTransactionRequest, completion: WalletUserConsentCompletion?) {
        completion?(.consented)
    }
}

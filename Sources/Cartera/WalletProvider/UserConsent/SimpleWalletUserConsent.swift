//
//  SimpleWalletUserAction.swift
//  dydxWallet
//
//  Created by Rui Huang on 9/20/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import Foundation
import UIKit

final public class SimpleWalletUserConsent: WalletUserConsentProtocol {
    public init() {}

    public func showTransactionConsent(request: WalletTransactionRequest, completion: WalletUserConsentCompletion?) {
        let gasString: String
        if let gas = request.ethereum?.gas, let gasPrice = request.ethereum?.gasPrice {
            let gasCost = gas.multiplied(by: gasPrice)
            let gasDouble = (Double(String(gasCost)) ?? 0.0) / 1_000_000_000
            gasString = "\(gasDouble) Gwei"
        } else {
            gasString = ""
        }
        let valueString: String
        if let value = request.ethereum?.transaction.value {
            let valueDouble = (Double(String(value)) ?? 0.0) / 1_000_000_000 / 1_000_000_000
            valueString = "\(valueDouble) ETH"
        } else {
            valueString = ""
        }
        let alert = UIAlertController(title: "Approve this transaction?", message: "Esimated gas: \(gasString).  Transaction value: \(valueString)", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Approve", style: .default, handler: { _ in
            completion?(.consented)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            completion?(.rejected)
        }))

        topController?.present(alert, animated: true)
    }

    private var topController: UIViewController? {
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        if var viewController = keyWindow?.rootViewController {
            while let presentedViewController = viewController.presentedViewController {
                viewController = presentedViewController
            }
            return viewController
        }

        return nil
    }
}

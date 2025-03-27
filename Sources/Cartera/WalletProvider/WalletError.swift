//
//  WalletConstants.swift
//  dydxWallet
//
//  Created by Rui Huang on 7/27/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import Foundation

struct WalletError {
    static func error(code: CarteraErrorCode, title: String? = nil, message: String? = nil) -> Error? {
        var userInfo = [String: String]()
        if let title = title, title.isNotEmpty {
            userInfo["title"] = title
        } else {
            userInfo["title"] = "Wallet Error 1"
        }
        if message?.isNotEmpty ?? false {
            userInfo["message"] = message
        } else {
            userInfo["message"] = code.message
        }
        return NSError(domain: "Cartera", code: code.rawValue, userInfo: userInfo)
    }
}

//
//  WalletTypedDataProtocols.swift
//  dydxWallet
//
//  Created by John Huang on 1/25/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import Foundation

public protocol WalletTypedDataProviderProtocol {
    func typedData() -> [String: Any]?
}

public extension WalletTypedDataProviderProtocol {
    func type(name: String, type: String) -> [String: String] {
        return ["name": name, "type": type]
    }

    var typedDataAsString: String? {
        if let typedData = typedData(),
           let data = try? JSONSerialization.data(withJSONObject: typedData, options: .withoutEscapingSlashes) {
            return String(data: data, encoding: .ascii)
        }
        return nil
    }
}

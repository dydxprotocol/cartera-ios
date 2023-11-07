//
//  WalletTypedData.swift
//  dydxWallet
//
//  Created by John Huang on 1/25/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import Foundation

public class WalletTypedData {
    public var typeName: String
    public var definitions: [[String: String]]?
    public var data: [String: Any]?

    public var valid: Bool {
        if let definitions = definitions, let data = data {
            let firstNonExisting = definitions.first { definition in
                if let key = definition["name"] {
                    return data[key] == nil
                } else {
                    return true
                }
            }
            return firstNonExisting == nil
        } else {
            return false
        }
    }

    public init(typeName: String) {
        self.typeName = typeName
    }

    public func type(name: String, type: String) -> [String: String] {
        return ["name": name, "type": type]
    }
}

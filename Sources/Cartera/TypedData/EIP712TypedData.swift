//
//  EIP712TypedData.swift
//  dydxWallet
//
//  Created by John Huang on 1/25/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import Foundation

public class EIP712TypedData: WalletTypedData {
    public init(name: String, chainId: Int, version: String?) {
        super.init(typeName: "EIP712Domain")
        var definitions =  [[String: String]]()
        var data = [String: Any]()

        definitions.append(type(name: "name", type: "string"))
        data["name"] = name

        if let version = version {
            definitions.append(type(name: "version", type: "string"))
            data["version"] = version
        }
        definitions.append(type(name: "chainId", type: "uint256"))
        data["chainId"] = chainId
        self.definitions = definitions
        self.data = data
    }
}

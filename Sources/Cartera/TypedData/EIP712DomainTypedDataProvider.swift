//
//  EIP712DomainTypedDataProvider.swift
//  dydxWallet
//
//  Created by John Huang on 1/25/22.
//  Copyright © 2022 dYdX Trading Inc. All rights reserved.
//

import Foundation

public class EIP712DomainTypedDataProvider: NSObject, WalletTypedDataProviderProtocol {
    public dynamic var eip712: EIP712TypedData?
    public dynamic var message: WalletTypedData?

    public init(name: String, chainId: Int, version: String?) {
        self.eip712 = EIP712TypedData(name: name, chainId: chainId, version: version)
        super.init()
    }

    public func typedData() -> [String: Any]? {
        if valid, let eip712 = eip712, let message = message {
            var types = [String: Any]()
            types[eip712.typeName] = eip712.definitions
            types[message.typeName] = message.definitions

            var typedData = [String: Any]()
            typedData["types"] = types
            typedData["primaryType"] = message.typeName
            typedData["domain"] = eip712.data!
            typedData["message"] = message.data!

            return typedData
        } else {
            return nil
        }
    }
    
    private var valid: Bool {
        return (eip712?.valid ?? false) && (message?.valid ?? false)
    }
}

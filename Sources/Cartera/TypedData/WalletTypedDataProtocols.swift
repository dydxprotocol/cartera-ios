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
        if let typedData = typedData() {
           return stableStringify(typedData)
        }
        return nil
    }
}

// Ensures that JSON keys are sorted in a stable order before converting the object to a JSON string:
private func stableStringify(_ dictionary: [String: Any]) -> String? {
    let sortedKeys = dictionary.keys.sorted() // Sort keys alphabetically
    var sortedDict = [String: Any]()
    
    for key in sortedKeys {
        if let value = dictionary[key] {
            if let subDict = value as? [String: Any] {
                sortedDict[key] = stableStringify(subDict) // Recursively sort nested dictionaries
            } else if let array = value as? [Any] {
                sortedDict[key] = stableStringifyArray(array) // Handle arrays
            } else {
                sortedDict[key] = value // Keep other values as is
            }
        }
    }
    
    // Convert sorted dictionary to JSON
    if let jsonData = try? JSONSerialization.data(withJSONObject: sortedDict, options: []),
       let jsonString = String(data: jsonData, encoding: .ascii) {
        return jsonString
    }
    
    return nil
}

// Helper function to handle arrays (preserving order but handling nested objects)
private func stableStringifyArray(_ array: [Any]) -> [Any] {
    return array.map { element in
        if let dict = element as? [String: Any] {
            return stableStringify(dict) ?? dict
        } else if let subArray = element as? [Any] {
            return stableStringifyArray(subArray)
        } else {
            return element
        }
    }
}

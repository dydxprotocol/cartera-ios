//
//  CryptoUtils.swift
//  dydxWallet
//
//  Created by Qiang Huang on 4/24/21.
//

import Foundation

struct CryptoUtils {
    // https://developer.apple.com/documentation/security/1399291-secrandomcopybytes
    static func randomKey() throws -> String {
        var bytes = [Int8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes: bytes, count: 32).toHexString()
        } else {
            // we don't care in the example app
            enum TestError: Error {
                case unknown
            }
            throw TestError.unknown
        }
    }
}

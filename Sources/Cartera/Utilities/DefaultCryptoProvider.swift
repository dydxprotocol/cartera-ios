//
//  DefaultCryptoProvider.swift
//  
//
//  Created by Rui Huang on 28/03/2024.
//

import Foundation
//import Web3
import CryptoSwift
//import HDWalletKit
import WalletConnectSigner
import CryptoKit
import BigInt

struct DefaultCryptoProvider: CryptoProvider {

    public func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        return Data()
//
//        let publicKey = try EthereumPublicKey(
//            message: message.bytes,
//            v: EthereumQuantity(quantity: BigUInt(signature.v)),
//            r: EthereumQuantity(signature.r),
//            s: EthereumQuantity(signature.s)
//        )
//        return Data(publicKey.rawPublicKey)
    }

    public func keccak256(_ data: Data) -> Data {
        return Data()
//        
//        let digest = SHA3(variant: .keccak256)
//        let hash = digest.calculate(for: [UInt8](data))
//        return Data(hash)
    }
}

//
//struct secp256k1 {
//    static func recoverPublicKey(from signature: (messageHash: Data, r: Data, s: Data, v: UInt8)) throws -> Data {
//          let messageHash = signature.messageHash
//          let r = signature.r
//          let s = signature.s
//          let v = signature.v
//
//          // Compute the recovery parameter
//          let recoveryParam = Int(v) - 27
//
//          // Construct the secp256k1 curve
//          let curve = CurveType.secp256k1
//
//          // Compute the curve order
//          let order = curve.order
//
//          // Compute the public key candidate
//          let z = messageHash
//
//          // Compute r^2
//          let rSquared = BigInt(Data(r)).power(2, modulus: order)
//
//          // Compute s^2
//          let sSquared = BigInt(Data(s)).power(2, modulus: order)
//
//          // Compute u1 = z * s^2
//          let u1 = BigInt(z) * sSquared % order
//
//          // Compute u2 = r^2 * s^2
//          let u2 = rSquared * sSquared % order
//
//          // Compute the point (x, y) = u1 * G + u2 * Q
//          let x = (curve.generator.x * u1 + curve.generator.x * u2) % order
//          let y = (curve.generator.y * u1 + curve.generator.y * u2) % order
//
//          // Compute the point candidate
//          let pointCandidate = CryptoKit.CurvePoint(x: x, y: y, curve: curve)
//
//          // Verify if the recovered point candidate is on the curve
//          guard curve.contains(point: pointCandidate) else {
//              throw CryptoError.invalidPublicKey
//          }
//
//          // Compute the public key
//          let publicKey = pointCandidate.x.export().dropFirst()
//
//          return publicKey
//      }
//}

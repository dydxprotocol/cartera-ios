//
//  CarteraErrorCode.swift
//  Cartera
//
//  Created by Rui Huang on 3/30/23.
//

public enum CarteraErrorCode: Int {
    case userCanceled
    case networkMismatch
    case walletMismatch
    case walletContainsNoAccount
    case signingMessageFailed
    case unexpectedResponse
    case signingTransactionFailed
    case connectionFailed
    case refusedByWallet
    case linkOpenFailed
    case invalidSession
    case invalidInput
    case addChainFailed
    case addChainNotSupported

    var message: String {
        switch self {
        case .userCanceled:
            return "User canceled"
        case .networkMismatch:
            return "Network mismatch"
        case .walletMismatch:
            return "Wallet mismatch"
        case .walletContainsNoAccount:
            return "Unable to obtain account"
        case .signingMessageFailed:
            return "Signing message failed"
        case .unexpectedResponse:
            return "Unexpected response"
        case .signingTransactionFailed:
            return "Signing transaction failed"
        case .connectionFailed:
            return "Connection failed"
        case .refusedByWallet:
            return "Refused by wallet"
        case .linkOpenFailed:
            return "Unable to open link"
        case .invalidSession:
            return "Invalid session"
        case .invalidInput:
            return "Invalid input"
        case .addChainFailed:
            return "Add or switch chain failed"
        case .addChainNotSupported:
            return "Add or switch chain method not supported"
        }
    }
}

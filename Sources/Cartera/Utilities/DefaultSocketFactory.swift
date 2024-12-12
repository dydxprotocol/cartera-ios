//
//  DefaultSocketFactory.swift
//  
//
//  Created by Rui Huang on 3/16/23.
//

import Foundation
import Starscream
import WalletConnectRelay

extension Starscream.WebSocket: @retroactive WebSocketConnecting { }

struct DefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        return Starscream.WebSocket(url: url)
    }
}

//
//  WalletConnectUtils.swift
//  
//
//  Created by Rui Huang on 3/17/23.
//

import Foundation

struct WalletConnectUtils {
    static func createUrl(wallet: Wallet, deeplink: String?, type: WalletConnectionType) -> URL? {
        if let deeplink = deeplink {
            let url: URL?
            if wallet.config?.installed ?? false {
                if let walletConfig =  wallet.config {
                    url = build(deeplink: deeplink, wallet: wallet, config: walletConfig, type: type)
                } else {
                    url = URL(string: deeplink)
                }
            } else if let appLink = wallet.appLink {
                url = URL(string: appLink)
            } else {
                url = URL(string: deeplink)
            }
            return url
        } else {
            if let native = wallet.native, wallet.config?.installed ?? false {
                let deeplink = "\(native)///"
                return URL(string: deeplink)
            }
        }
        return nil
    }

    private static func build(deeplink: String, wallet: Wallet, config: WalletConfig, type: WalletConnectionType) -> URL? {
        /*
         Rainbow sample universal link:
         https://rnbwapp.com/wc?uri=wc%3A53f62d4f-7a28-4a67-a0ec-320533b589b9%401%3Fbridge%3Dhttps%253A%252F%252Fn.bridge.walletconnect.org%26key%3Dd6231e9386a0db10f7326a454169343edebe7058da528173135a4651056e08e6
         */
        /*
         Rainbow sample deep link: (doesn't work on 9/14/2021)
         rainbow://wc?uri=wc%3A53f62d4f-7a28-4a67-a0ec-320533b589b9%401%3Fbridge%3Dhttps%253A%252F%252Fn.bridge.walletconnect.org%26key%3Dd6231e9386a0db10f7326a454169343edebe7058da528173135a4651056e08e6
         */
        let encoding = config.encoding

        let universal = config.connections(ofType: type)?.universal?.trim()
        let native = config.connections(ofType: type)?.native?.trim()

        let useUniversal = universal?.isNotEmpty ?? false
        let useNative = native?.isNotEmpty ?? false

        var url: URL?
        if let universal = universal, useUniversal {
            url = createUniversallink(universal: universal, deeplink: deeplink, encoding: encoding)
        }
        if let native = native, useNative, url == nil {
            url = createDeeplink(native: native, deeplink: deeplink, encoding: encoding)
        }
        if url == nil {
            url = URL(string: deeplink)
        }
        return url
    }

    private static func createUniversallink(universal: String, deeplink: String, encoding: String?) -> URL? {
        let encoded = encodeUri(deeplink: deeplink, encoding: encoding)
        let link = "\(universal)/wc?uri=\(encoded)"
        return URL(string: link)
    }

    private static func createDeeplink(native: String, deeplink: String, encoding: String?) -> URL? {
        let encoded = encodeUri(deeplink: deeplink, encoding: encoding)
        let link = "\(native)//wc?uri=\(encoded)"
        return URL(string: link)
    }
    
    private static func encodeUri(deeplink: String, encoding: String?) -> String {
        if let encoding = encoding {
            let encodingSet = NSCharacterSet(charactersIn: encoding)
            let allowedSet = encodingSet.inverted
            return deeplink.addingPercentEncoding(withAllowedCharacters: allowedSet) ?? deeplink
        } else {
            return deeplink
        }
    }
}

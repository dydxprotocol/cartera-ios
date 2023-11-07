//
//  UrlHandler.swift
//  Utilities
//
//  Created by Qiang Huang on 8/21/19.
//  Copyright © 2019 dYdX. All rights reserved.
//

import Foundation

protocol URLHandlerProtocol {
    func open(_ url: URL, completionHandler completion: ((Bool) -> Void)?)
    func canOpenURL(_ url: URL) -> Bool
}

class URLHandler {
    static var shared: URLHandlerProtocol?
}

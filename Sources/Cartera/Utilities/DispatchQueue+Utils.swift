//
//  DispatchQueue+Utils.swift
//  Utilities
//
//  Created by Qiang Huang on 12/27/18.
//  Copyright © 2018 dYdX. All rights reserved.
//

import Foundation

typealias RunBlock = @convention(block) () -> Void

extension DispatchQueue {
    static func runInMainThread(_ block: @escaping RunBlock) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}

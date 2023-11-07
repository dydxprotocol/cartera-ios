//
//  Console.swift
//  Utilities
//
//  Created by Qiang Huang on 3/9/20.
//  Copyright © 2020 dYdX. All rights reserved.
//

import Foundation

final class Console: NSObject, SingletonProtocol {
    static var shared: Console = Console()

    private var visible: Bool = {
        #if DEBUG
            return true
        #else
            if Installation.appStore || !Installation.jailBroken {
                return false
            }
            return true
        #endif
    }()

    func log(_ object: Any?) {
        if visible, let object = object {
            print(object)
        }
    }

    func log(_ object1: Any?, _ object2: Any?) {
        log("\(object1 ?? "")\n\(object2 ?? "")")
    }
}

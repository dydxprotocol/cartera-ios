//
//  HapticFeedbackProtocol.swift
//  Utilities
//
//  Created by Qiang Huang on 10/30/21.
//  Copyright © 2021 dYdX Trading Inc. All rights reserved.
//

import Foundation

enum ImpactLevel: Int {
    case low
    case medium
    case high
}

enum NotificationType: Int {
    case success
    case warnng
    case error
}

protocol HapticFeedbackProtocol {
    func prepareImpact(level: ImpactLevel)
    func prepareSelection()
    func prepareNotify(type: NotificationType)
    
    func impact(level: ImpactLevel)
    func selection()
    func notify(type: NotificationType)
}

class HapticFeedback: NSObject {
    static var shared: HapticFeedbackProtocol?
}

//
//  NotificationToken.swift
//  Utilities
//
//  Created by Qiang Huang on 5/14/19.
//  Copyright © 2019 dYdX. All rights reserved.
//

import Foundation

class NotificationToken {
    let notificationCenter: NotificationCenter
    let token: NSObjectProtocol

    init(notificationCenter: NotificationCenter = .default, token: NSObjectProtocol) {
        self.notificationCenter = notificationCenter
        self.token = token
    }

    deinit {
        notificationCenter.removeObserver(token)
    }
}

extension NotificationCenter {
    func observe(_ obj: Any? = nil, notification: NSNotification.Name?, queue: OperationQueue? = nil, do block: @escaping (Notification) -> Void) -> NotificationToken {
        let token = addObserver(forName: notification, object: obj, queue: queue, using: block)
        return NotificationToken(notificationCenter: self, token: token)
    }
}

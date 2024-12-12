//
//  AppState.swift
//  Utilities
//
//  Created by Qiang Huang on 4/26/21.
//  Copyright © 2021 dYdX. All rights reserved.
//

import Foundation
import UIKit

typealias ForegroundTask = () -> Void

public final class CarteraAppState: NSObject, SingletonProtocol {
    static var shared: CarteraAppState = CarteraAppState()

    @objc private(set) dynamic var background: Bool = false {
        didSet {
            didSetBackground(oldValue: oldValue)
        }
    }

    private var foregroundToken: NotificationToken?
    private var backgroundToken: NotificationToken?

    private var foregroundTasks: [ForegroundTask] = []

    override public init() {
        super.init()
        backgroundToken = NotificationCenter.default.observe(notification: UIApplication.didEnterBackgroundNotification, do: { [weak self] _ in
            self?.background = true
        })
        foregroundToken = NotificationCenter.default.observe(notification: UIApplication.willEnterForegroundNotification, do: { [weak self] _ in
            self?.background = false
        })
    }

    func runForegrounding(task: @escaping ForegroundTask) {
        if background {
            foregroundTasks.append(task)
        } else {
            task()
        }
    }

    private func didSetBackground(oldValue: Bool) {
        if background != oldValue {
            if !background {
                for task in foregroundTasks {
                    task()
                }
                foregroundTasks = []
            }
        }
    }
}

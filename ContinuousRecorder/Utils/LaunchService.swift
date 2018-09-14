//
//  AppDelegate+launcher.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 14/09/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Cocoa
import ServiceManagement


extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@objcMembers class LaunchService: NSObject {
    // MARK: - Private
    private let launcherAppId = "deblonde.LauncherApplication"

    private var helperIsRunning: Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
    }

    // MARK: - Properties
    static let shared = LaunchService()
    @objc dynamic var isEnabled = false
    
    // MARK: -

    // Initialization
    private override init() {
        print("Created singleton LaunchService")
    }

    func checkHelper() {
        if helperIsRunning {
            NSLog("\(#function): isRunning")
            // TODO: Currently we only know whether it launch at login was enabled if it was launched by it at login..
            isEnabled = true
            // kill the helper that started us
            DistributedNotificationCenter.default.post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
    }
    
    func toggleLaunchAtLogin(_ on: Bool) -> Bool {
        let success = SMLoginItemSetEnabled(launcherAppId as CFString, on)
        if success {
            isEnabled = on
        }
        return success
    }
}

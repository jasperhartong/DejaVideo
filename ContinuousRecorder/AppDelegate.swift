//
//  AppDelegate.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 24/08/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // Main recording object to inject into controllers
    @objc var recording: ContinuousRecording!

    // Menu bar
    let menuBarController: MenuBarController

    // Secondary Windows
    let settingsWindowController: SettingsWindowController
    let exportEffectWindowController: ExportEffectWindowController
    
    // Starting up the main app
    override init () {
        do {
            recording = try ContinuousRecording()
        } catch { print(error.localizedDescription) }
        
        settingsWindowController = SettingsWindowController(recording)
        exportEffectWindowController = ExportEffectWindowController(recording)
        menuBarController = MenuBarController(recording, settingsWindowController)

        // complete init
        super.init()
        
        // Quit if no recording (can only be done after completing init)
        if recording == nil { NSApplication.shared.terminate(self) }
        
    }

    // MARK: Application Lifecycle
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // shut down helper app if started on launch
        LaunchService.shared.checkHelper()
        
        if (recording.state == .recording) {
            exportEffectWindowController.showFor(seconds:3.0)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}


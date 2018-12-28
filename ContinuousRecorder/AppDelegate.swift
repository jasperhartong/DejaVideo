//
//  AppDelegate.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 24/08/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Cocoa
import CoreGraphics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // Main recording object to inject into controllers
    @objc var recording: ContinuousRecording!

    // To keep track of main screen (== withMenuBar)
    private var currentMainScreenID: CGDirectDisplayID?

    // Menu bar
    let menuBarController: MenuBarController

    // Secondary Windows
    let settingsWindowController: SettingsWindowController
    let exportEffectWindowController: ExportEffectWindowController
    
    // Starting up the main app
    override init () {
        do {
            let config = ContinuousRecordingConfig()
            
            recording = try ContinuousRecording(config:config)
            currentMainScreenID = CGDirectDisplayID.withMenuBar
        } catch { print(error.localizedDescription) }
        
        settingsWindowController = SettingsWindowController(recording)
        exportEffectWindowController = ExportEffectWindowController(recording)
        menuBarController = MenuBarController(recording, settingsWindowController)

        // complete init
        super.init()
        
        // Quit if no recording (can only be done after completing init)
        if recording == nil { NSApplication.shared.terminate(self) }
        
        observeMainScreenChanges()
    }

    // MARK: Application Lifecycle
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // shut down helper app if started on launch
        LaunchService.shared.checkHelper()
        
        // Show a nice animation upon launch
        showSplashIfRecording()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // MARK: Private
    private func observeMainScreenChanges() {
        // Signal the user which screen is recording upon "main" display changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApplication.shared,
            queue: OperationQueue.main) {
                notification -> Void in
                if self.currentMainScreenID != CGDirectDisplayID.withMenuBar {
                    self.currentMainScreenID = CGDirectDisplayID.withMenuBar
                    self.showSplashIfRecording()
                }
        }
    }
    
    private func showSplashIfRecording() {
        if (recording.state == .recording) {
            exportEffectWindowController.showFor(seconds:2.0, delay: 1.0)
        }
    }
}


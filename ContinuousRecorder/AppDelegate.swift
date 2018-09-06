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
    @objc var recording: ContinuousRecording!
    private var observers = [NSKeyValueObservation]()
    
    private var statusItem : NSStatusItem? = nil

    // menu items
    private let itemProgress: NSMenuItem = NSMenuItem()
    private let itemMenuSeparator: NSMenuItem = NSMenuItem.separator()
    private let itemSettings: NSMenuItem = NSMenuItem(
        title: "Settings", action: #selector(AppDelegate.settings), keyEquivalent: "")
    private let itemQuit: NSMenuItem = NSMenuItem(
        title: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: "")
    
    // Menu images
    private let imageRecordActive: NSImage = NSImage(named: NSImage.Name(rawValue: "MenuRec"))!
    private let imageRecordInactive: NSImage = NSImage(named: NSImage.Name(rawValue: "MenuRecInactive"))!
    //    private let progressTimer: Timer // TODO: Add timer to update for progress
    
    // Embedded recording progress view
    var recordingProgressController: RecordingProgressController!
    
    // Settings View Window
    var settingsWindowController: SettingsWindowController!
    
    // Starting up the main app
    override init () {
        do {
            recording = try ContinuousRecording()
        } catch { print(error.localizedDescription) }

        // complete init
        super.init()
        
        // Quit if no recording (can only be done after completing init)
        if recording == nil { NSApplication.shared.terminate(self) }
        
        // Set up controllers of (sub) views
        recordingProgressController = RecordingProgressController(recording)
        recordingProgressController.savePanelOpened = {
            self.statusItem?.menu?.cancelTracking()
        }
        settingsWindowController = SettingsWindowController()
        itemProgress.view = recordingProgressController.view

        // Set up observers
        observeRecording()
    }
    
    private func observeRecording() {
        observers = [
            self.recording.observe(\ContinuousRecording.state) { recording, observedChange in
                self.updateMenuImage()
                self.updateMenuTitle()
            }
        ]
    }
    
    private func createMenu () {
        let menu = NSMenu()

        for menuItem in [
            itemProgress,
            itemMenuSeparator,
            itemSettings,
            itemQuit
        ] {
            menu.addItem(menuItem)
        }
        statusItem?.menu = menu
    }
    
    private func updateMenuImage() {
        switch recording.state {
        case .idle:
            statusItem?.image = imageRecordInactive
        case .recording:
            statusItem?.image = imageRecordActive
        case .recordingExporting:
            // TODO: Add separate image for exporting
            statusItem?.image = imageRecordActive
        }
    }
    
    private func updateMenuTitle() {
        switch recording.state {
        case .idle, .recording:
            statusItem?.title = ""
        case .recordingExporting:
            statusItem?.title = "Exporting"
        }
    }
    
    // MARK: Application Lifecycle
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        createMenu()
        updateMenuImage()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        recording.stop(clearFragments: true)
    }
    
    // MARK: Menu actions
    @objc func start() {
        recording.start()
    }
    
    @objc func stop() {
        recording.stop(clearFragments: true)
    }
    
    @objc func settings() {
        settingsWindowController.window?.setIsVisible(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Delay ensures correct becomeMain() behavior when the settingswindow was already opened before
            // Gives time for the menu to close and pass on "Main" to the already opened window
            // Otherwise the settingsWindow would becomeMain only for a split second
            self.settingsWindowController.window?.becomeMain()
        }
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }


}


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
    private let itemStart: NSMenuItem = NSMenuItem(
        title: "Start Recording", action: #selector(AppDelegate.start), keyEquivalent: "")
    private let itemStop: NSMenuItem = NSMenuItem(
        title: "Stop Recording", action: #selector(AppDelegate.stop), keyEquivalent: "")
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

        // Set up observers
        observeRecording()
    }
    
    private func observeRecording() {
        observers = [
            self.recording.observe(\ContinuousRecording.isRecording) { recording, observedChange in
                self.updateMenuImage()
                self.updateMenuItems()
            },
            self.recording.observe(\ContinuousRecording.isExporting) { recording, observedChange in
                self.toggleExporting()
            }
        ]
    }
    
    private func createMenu () {
        let menu = NSMenu()

        for menuItem in [
            itemProgress,
            itemStart,
            itemStop,
            itemMenuSeparator,
            itemSettings,
            itemQuit
        ] {
            menu.addItem(menuItem)
        }
        statusItem?.menu = menu
        updateMenuItems()
    }
    
    private func updateMenuItems () {
        if (recording.isRecording) {
            itemProgress.view = recordingProgressController.view
            itemProgress.isHidden = false
            itemStop.isHidden = false
            itemStart.isHidden = true
        } else {
            itemProgress.view = nil
            itemProgress.isHidden = true
            itemStop.isHidden = true
            itemStart.isHidden = false
        }
    }
    
    private func updateMenuImage() {
        if recording.isRecording {
            statusItem?.image = imageRecordActive
        } else {
            statusItem?.image = imageRecordInactive
        }
    }
    
    private func toggleExporting() {
        if recording.isExporting {
            statusItem?.title = "Exporting"
        } else {
            statusItem?.title = ""
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
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }


}


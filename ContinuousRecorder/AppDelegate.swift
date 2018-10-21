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
        title: "Settings", action: #selector(AppDelegate.openSettings), keyEquivalent: "")
    private let itemQuit: NSMenuItem = NSMenuItem(
        title: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: "")
    
    // Menu images
    private let menuImageIdle: NSImage = NSImage(named: NSImage.Name(rawValue: "menu-image-idle"))!
    private let menuImageRecording: NSImage = NSImage(named: NSImage.Name(rawValue: "menu-image-recording"))!
    private let menuImageExporting: NSImage = NSImage(named: NSImage.Name(rawValue: "menu-image-exporting"))!
    
    // Embedded recording progress view
    var recordingProgressController: RecordingProgressController!
    
    // Secondary Windows
    let settingsWindowController: SettingsWindowController
    let exportEffectWindowController: ExportEffectWindowController
    
    // Starting up the main app
    override init () {
        do {
            recording = try ContinuousRecording()
        } catch { print(error.localizedDescription) }

        settingsWindowController = SettingsWindowController(recording)
        exportEffectWindowController = ExportEffectWindowController()

        // complete init
        super.init()
        
        // Quit if no recording (can only be done after completing init)
        if recording == nil { NSApplication.shared.terminate(self) }
        
        // Set up controllers of (sub) views
        recordingProgressController = RecordingProgressController(recording)
        recordingProgressController.savePanelOpened = {
            // close menu
            self.statusItem?.menu?.cancelTracking()
        }
        itemProgress.view = recordingProgressController.view

        // Set up observers
        observeRecording()
    }
    
    private func observeRecording() {
        observers = [
            self.recording.observe(\ContinuousRecording.state) { recording, observedChange in
                self.updateMenuImage()
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
            statusItem?.image = menuImageIdle
            exportEffectWindowController.hide()
        case .recording:
            statusItem?.image = menuImageRecording
            exportEffectWindowController.hide()
        case .preppedExport:
            statusItem?.image = menuImageExporting
            exportEffectWindowController.hide()
        case .exporting:
            statusItem?.image = menuImageExporting
            exportEffectWindowController.show()
        }
    }
    
    // MARK: Application Lifecycle
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // shut down helper app if started on launch
        LaunchService.shared.checkHelper()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // TODO: For now don't highlight the menu so the menu images show nice
        statusItem?.highlightMode = false

        createMenu()
        updateMenuImage()
        
        if (recording.state == .recording) {
            exportEffectWindowController.showFor(seconds:3.0)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // MARK: Menu actions
    @objc func openSettings() {
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


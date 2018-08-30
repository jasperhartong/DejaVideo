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
    private var recObservation: NSKeyValueObservation?
    
    private var statusItem : NSStatusItem? = nil
    private let itemStart: NSMenuItem = NSMenuItem(title: "Start Recording", action: #selector(AppDelegate.start), keyEquivalent: "")
    private let itemGrab: NSMenuItem = NSMenuItem(title: "Grab Recording", action: #selector(AppDelegate.grab), keyEquivalent: "")
    private let itemStop: NSMenuItem = NSMenuItem(title: "Stop Recording", action: #selector(AppDelegate.stop), keyEquivalent: "")
    private let itemQuitSeparator: NSMenuItem = NSMenuItem.separator()
    private let itemQuit: NSMenuItem = NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: "")
    private let imageRecordActive: NSImage = NSImage(named: NSImage.Name(rawValue: "MenuRec"))!
    private let imageRecordInactive: NSImage = NSImage(named: NSImage.Name(rawValue: "MenuRecInactive"))!

    @IBOutlet weak var window: NSWindow!

    override init () {
        do {
            recording = try ContinuousRecording()
        } catch { print(error.localizedDescription) }

        super.init()

        if recording == nil {
            NSApplication.shared.terminate(self)
            return
        }
        
        recObservation = self.recording.observe(\ContinuousRecording.isRecording) { recording, observedChange in
            self.updateMenuImage()
            self.updateMenuItems()
        }
    }
    
    private func createMenu () {
        let menu = NSMenu()
        for menuItem in [
            itemStart,
            itemGrab,
            itemStop,
            itemQuitSeparator,
            itemQuit
        ] {
            menu.addItem(menuItem)
        }
        statusItem?.menu = menu
        updateMenuItems()
    }
    
    private func updateMenuItems () {
        if (recording.isRecording) {
            itemStop.isHidden = false
            itemGrab.isHidden = false
            itemStart.isHidden = true
        } else {
            itemStop.isHidden = true
            itemGrab.isHidden = true
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
    
    @objc func grab() {
        
        let destination = NSURL.fileURL(withPathComponents: [ NSTemporaryDirectory(), "test.mov"])!
        recording.renderCurrentRetention(destination, {(destination, error) -> Void in
            if let destination = destination {
                print("\(destination)")
                NSWorkspace.shared.open(destination)
            }
            if let error = error {
                print("\(error)")
            }
        })
    }
    
    @objc func stop() {
        recording.stop(clearFragments: true)
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }


}


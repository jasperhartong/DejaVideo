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
    var item : NSStatusItem? = nil
    var recording: ContinuousRecording!

    @IBOutlet weak var window: NSWindow!

    override init () {
        do {
            recording = try ContinuousRecording()
        } catch { print(error.localizedDescription) }

        super.init()

        if recording == nil {
            NSApplication.shared.terminate(self)
        }
    }
    
    private func updateMenuItems () {
        // Defines function to run when the user clicks on the text on menu bar
        //item?.action = #selector(AppDelegate.testMe)
        let menu = NSMenu()
        if (recording.isRecording) {
            menu.addItem(NSMenuItem(title: "Grab Recording", action: #selector(AppDelegate.grab), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(AppDelegate.stop), keyEquivalent: ""))
        } else if (!recording.isPreparingRecording) {
            let startItem = NSMenuItem(title: "Start Recording", action: #selector(AppDelegate.start), keyEquivalent: "")
            startItem.isEnabled = false
            menu.addItem(startItem)
        } else {
            menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(AppDelegate.start), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quitMe), keyEquivalent: ""))
        item?.menu = menu
    }
    
    private func updateMenuImage () {
        item?.image = NSImage(named: NSImage.Name(rawValue: "MenuRec"))
    }
    
    // MARK: Application Lifecycle
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateMenuImage()
        updateMenuItems()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        recording.stop(clearFragments: true)
    }
    
    // MARK: Menu actions
    @objc func start() {
        recording.start(onStartCallback: {()-> Void in
            // it takes a bit to start up the recording session
            print("started recording")
            self.updateMenuItems()
        })
        updateMenuItems()
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
        updateMenuItems()
    }
    
    @objc func quitMe() {
        NSApplication.shared.terminate(self)
    }


}


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

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        //Displays text on menu bar
        item?.image = NSImage(named: NSImage.Name(rawValue: "MenuRec"))
        
        // Defines function to run when the user clicks on the text on menu bar
        //item?.action = #selector(AppDelegate.testMe)
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Option 1", action: #selector(AppDelegate.testMe), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quitMe), keyEquivalent: ""))
        item?.menu = menu

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func testMe() {
        print ("It works!")
    }
    
    @objc func quitMe() {
        NSApplication.shared.terminate(self)
    }


}


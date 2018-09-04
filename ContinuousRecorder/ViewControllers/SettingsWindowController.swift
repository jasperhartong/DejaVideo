//
//  settingsViewController.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 04/09/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Foundation

import Foundation
import Cocoa

class SettingsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    // Mark Toolbar
    var toolbar:NSToolbar!
    var toolbarTabsArray: [NSToolbarItem] = []
    var toolbarTabsIdentifierArray:[String] = []

    var currentViewController:NSViewController!
    var currentView = ""
    
    // MARK: Outlets
    @IBAction func activateTabGeneral(_ sender: Any) {
        print("\(#function)")
    }
    @IBAction func activateTabAbout(_ sender: Any) {
        print("\(#function)")
    }
    
    
    // MARK: Window setup and teardown
    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "SettingsWindow")
    }

    init() {
        // use .windowNibName
        super.init(window:nil)
    }
    
    override func windowDidLoad() {
        // Overloading this controller to delegate multiple things :)
        self.window?.delegate = self
        self.window?.toolbar?.delegate = self
        self.window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: "General")
        // ensure the settings window is on top
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

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

class GeneralSettingsViewController: NSViewController {
    
    init() {
        super.init(nibName: NSNib.Name(rawValue: "GeneralSettingsView"), bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AboutViewController: NSViewController {
    
    init() {
        super.init(nibName: NSNib.Name(rawValue: "AboutView"), bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    private let generalSettingsViewController = GeneralSettingsViewController()
    private let aboutViewController = AboutViewController()
    
    // MARK: Outlets
    @IBAction func activateTabGeneral(_ sender: Any) {
        contentViewController = generalSettingsViewController
    }
    @IBAction func activateTabAbout(_ sender: Any) {
        contentViewController = aboutViewController
    }
    
    // MARK: Window setup and teardown
    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "SettingsWindow")
    }

    init() {
        // Use .windowNibName
        super.init(window:nil)
    }
    
    override func windowDidLoad() {
        // Overloading this controller to delegate multiple things :)
        self.window?.delegate = self
        self.window?.toolbar?.delegate = self
        self.window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: "General")
        // Set initial tab
        contentViewController = generalSettingsViewController
        // ensure the settings window is on top
        self.window?.level = .floating
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

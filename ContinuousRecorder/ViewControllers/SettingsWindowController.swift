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
    @IBOutlet weak var launchAtLoginCheckbox: NSButton!
    @IBAction func launchAtLoginCheckboxClicked(_ sender: Any) {
        _ = LaunchService.shared.toggleLaunchAtLogin(launchAtLoginCheckbox.state == .on)
        
    }
    
    @IBAction func roadmapButtonClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://roadmap.dejavideo.com")!)
    }
    init() {
        super.init(nibName: NSNib.Name(rawValue: "GeneralSettingsView"), bundle: nil)
        _ = LaunchService.shared.observe(\LaunchService.isEnabled) { _, _ in
            self.updateLaunchAtLoginCheckbox()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        updateLaunchAtLoginCheckbox()
    }
    
    func updateLaunchAtLoginCheckbox() {
        launchAtLoginCheckbox.state = LaunchService.shared.isEnabled ? .on : .off
    }
    
}

class AboutViewController: NSViewController {
    
    @IBAction func twitterButtonClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://twitter.com/jasperhartong")!)
    }
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
    
    override func keyDown(with event: NSEvent) {
        // Let cmd-w work to close settings window
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers! {
            case "w":
                self.window?.close()
            default:
                break
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

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
    
    @IBOutlet weak var recordingSettingsLabel: NSTextFieldCell!
    @IBAction func roadmapButtonClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://roadmap.dejavideo.com")!)
    }
    
    let recording: ContinuousRecording

    init(_ rec: ContinuousRecording) {
        recording = rec

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
        // TODO: Also get duration dynamically
        recordingSettingsLabel.stringValue = "Currently exports the last minute in \(Int(recording.fps))fps, needing approximatly \(recording.estimatedRAM)"
    }
    
    func updateLaunchAtLoginCheckbox() {
        launchAtLoginCheckbox.state = LaunchService.shared.isEnabled ? .on : .off
    }
    
}

class AboutViewController: NSViewController {
    @IBOutlet weak var versionLabel: NSTextFieldCell!
    
    @IBAction func twitterButtonClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://twitter.com/jasperhartong")!)
    }
    init() {
        super.init(nibName: NSNib.Name(rawValue: "AboutView"), bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.versionLabel.stringValue = "v\(version) - build: \(build)"
        }
    }
}

class SettingsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    private let generalSettingsViewController: GeneralSettingsViewController
    private let aboutViewController = AboutViewController()
    
    // MARK: Outlets
    @IBAction func activateTabGeneral(_ sender: Any) {
        contentViewController = generalSettingsViewController
        self.window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: "General")
    }
    @IBAction func activateTabAbout(_ sender: Any) {
        contentViewController = aboutViewController
        self.window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: "About")
    }
    
    // MARK: Window setup and teardown
    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "SettingsWindow")
    }

    init(_ rec: ContinuousRecording) {
        generalSettingsViewController = GeneralSettingsViewController(rec)

        // Use .windowNibName
        super.init(window:nil)
    }
    
    override func windowDidLoad() {
        // Overloading this controller to delegate multiple things :)
        self.window?.delegate = self
        self.window?.toolbar?.delegate = self
        // ensure the settings window is on top
        self.window?.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        // Set initial tab
        activateTabGeneral(self)
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

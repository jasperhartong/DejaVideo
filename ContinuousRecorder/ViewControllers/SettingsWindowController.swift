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
        NSWorkspace.shared.open(URL(string: "http://roadmap.dejavideo.app")!)
    }
    
    @IBAction func systemPreferencesButtonClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.display")!)
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
        updateRecordingSettingsLabel()
    }
    
    func updateLaunchAtLoginCheckbox() {
        launchAtLoginCheckbox.state = LaunchService.shared.isEnabled ? .on : .off
    }
    
    func updateRecordingSettingsLabel() {
        // TODO: Also format the duration in the string dynamically
        let fps = 1 / recording.config.fragmentInterval
        let fragmentSize = recording.fragmentSize != nil ? recording.fragmentSize! : 7056000;
        let estimatedRAM = fps * recording.config.retention * Double(fragmentSize)
        let estimatedRAMStr: String = String(format: "%.1f GB.", estimatedRAM / 1_000_000_000)
        
        recordingSettingsLabel.stringValue = "DejaVideo records the last minute in \(Int(fps))fps on a \(recording.config.scale) scale (~\(estimatedRAMStr) RAM). Currently it only records the display that holds the menubar."
    }
    
}

class AboutViewController: NSViewController {
    private let version: String
    private let build: String

    @IBOutlet weak var versionLabel: NSTextFieldCell!
    
    @IBAction func twitterButtonClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://twitter.com/jasperhartong")!)
    }
    
    @IBAction func websiteButtonClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://dejavideo.app/#v=\(version)")!)
    }
    init() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.version = "\(version)"
            self.build = "\(build)"
        } else {
            self.version = "unknown"
            self.build = "unknown"
        }
        super.init(nibName: NSNib.Name(rawValue: "AboutView"), bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        versionLabel.stringValue = "v\(version) - build: \(build)"
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
        self.window?.styleMask.remove(.resizable)
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

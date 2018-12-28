//
//  MenuBarController.swift
//  DejaVideo
//
//  Created by Jasper Hartong on 21/10/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Cocoa
import Foundation

@objc class MenuBarController: NSObject {
    @objc var recording: ContinuousRecording!
    let settingsWindowController: SettingsWindowController
    
    private var observers = [NSKeyValueObservation]()
    
    private var statusItem : NSStatusItem? = nil
    private var progressTimer: Timer!
    
    // menu items
    private let itemProgress: NSMenuItem = NSMenuItem()
    private let itemMenuSeparator: NSMenuItem = NSMenuItem.separator()
    private let itemSettings: NSMenuItem = NSMenuItem(
        title: "Settings", action: #selector(openSettings), keyEquivalent: "")
    private let itemQuit: NSMenuItem = NSMenuItem(
        title: "Quit", action: #selector(quit), keyEquivalent: "")
    
    // Menu images
    private let menuImageIdle: NSImage = NSImage(named: NSImage.Name(rawValue: "menu-image-idle"))!
    private let menuImageRecording: NSImage = NSImage(named: NSImage.Name(rawValue: "menu-image-recording"))!
    private let menuImageExporting: NSImage = NSImage(named: NSImage.Name(rawValue: "menu-image-exporting"))!
    
    // Embedded recording progress view
    var recordingProgressController: RecordingProgressController!
    
    init(_ recording: ContinuousRecording, _ settingsWindowController: SettingsWindowController) {
        self.recording = recording
        self.settingsWindowController = settingsWindowController
        
        super.init()

        // Set up controllers of (sub) views
        recordingProgressController = RecordingProgressController(recording)
        recordingProgressController.savePanelOpened = {
            // close menu
            self.statusItem?.menu?.cancelTracking()
        }
        itemProgress.view = recordingProgressController.view
        
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // TODO: For now don't highlight the menu so the menu images show nice
        statusItem?.highlightMode = false

        
        createMenu()
        
        // Set up observers
        observeRecording()
    }
    
    private func observeRecording() {
        // Call listeners also on init
        updateMenu()

        observers = [
            self.recording.observe(\ContinuousRecording.state) { recording, observedChange in
                self.updateMenu()
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
                // Default target is AppDelegate, set to `self` to let `#selector()` work
                menuItem.target = self
                menu.addItem(menuItem)
        }
        statusItem?.menu = menu
    }
    
    private func setStyledMenuTitle(_ title: String) {
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = .left
        pstyle.firstLineHeadIndent = 4

        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: -1, height: 1)
        // Base shadow color on textBackgroundColor so it works in dark OS theme as well
        shadow.shadowColor = NSColor.textBackgroundColor
        shadow.shadowBlurRadius = 0
        
        
        statusItem?.button?.attributedTitle = NSMutableAttributedString(
            string: title,
            attributes: [
                NSAttributedStringKey.font: NSFont.monospacedDigitSystemFont(
                    ofSize: NSFont.labelFontSize,
                    weight: NSFont.Weight.bold
                ),
                NSAttributedStringKey.shadow: shadow,
                NSAttributedStringKey.paragraphStyle: pstyle,
                NSAttributedStringKey.baselineOffset: -4,
            ])
    }
    
    @objc private func setRecordingMenuTitle() {
        let fragmentCount: Double = Double(recording.fragmentCount)
        let fragmentInterval: Double = Double(recording.config.fragmentInterval)
        let exportableSeconds: Double = fragmentCount * fragmentInterval
        // show up until the last second
        if (exportableSeconds == 0 || recording.config.retention - 1 <= exportableSeconds) {
            setStyledMenuTitle("")
        } else {
            setStyledMenuTitle(String(format: "%02d", Int(exportableSeconds)))
        }
    }
    
    private func updateMenu() {
        switch recording.state {
        case .idle:
            if let timer = progressTimer {
                timer.invalidate()
            }
            statusItem?.button?.image = menuImageIdle
            setStyledMenuTitle("")
        case .recording:
            statusItem?.button?.image = menuImageRecording
            setRecordingMenuTitle()
            progressTimer = Timer.scheduledTimer(
                timeInterval: recording.config.fragmentInterval,
                target: self,
                selector: #selector(setRecordingMenuTitle),
                userInfo: nil,
                repeats: true)
            // Make sure it updates when the menu is open
            RunLoop.main.add(progressTimer, forMode: .commonModes)
        case .preppedExport:
            setStyledMenuTitle("")
            statusItem?.button?.image = menuImageRecording
        case .exporting:
            setStyledMenuTitle("")
            statusItem?.button?.image = menuImageExporting
        }
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

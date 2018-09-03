//
//  RecordingProgressController.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 30/08/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Foundation
import Cocoa

class RecordingProgressController: NSViewController, NSUserNotificationCenterDelegate {
    private let savePanel: NSSavePanel
    var savePanelOpened: (() -> Void)?
    private func configureSavePanel() {
        savePanel.allowedFileTypes = ["mp4"]
        savePanel.allowsOtherFileTypes = false
        savePanel.level = .modalPanel
    }
    private func openSavePanel () {
        savePanelOpened?()

        // Make sure that savePanel is on top an in focus
        NSApp.activate(ignoringOtherApps: true)

        // open savePanel
        savePanel.begin { (modalResponse) in
            if modalResponse == .OK {
                if let destination = self.savePanel.url {
                    self.renderTo(destination: destination)
                } else {
                    print("Something went wrong")
                }
            }
            // turn off app focus
            NSApp.activate(ignoringOtherApps: false)
        }
    }

    // Observing the ContinuousRecording
    @objc private let recording: ContinuousRecording
    private var observers = [NSKeyValueObservation]()
    private func observeRecording() {
        observers = [
            self.recording.observe(\ContinuousRecording.isRecording) { recording, observedChange in
                self.toggleProgressTimer()
            },
            self.recording.observe(\ContinuousRecording.isExporting) { recording, observedChange in
                self.updateExportIndicator()
            }
        ]
    }
    
    // Outlets
    @IBOutlet weak var exportProgress: NSProgressIndicator!
    @IBOutlet weak var retentionProgress: NSProgressIndicator!
    @IBOutlet weak var exportButton: NSButton!
    @IBAction func buttonClicked(_ sender: NSButton) {
        self.openSavePanel()
    }
    
    private func renderTo(destination: URL) {
        recording.exportCurrentRetention(destination, {(destination, error) -> Void in
            // We're done
            if let destination = destination {
                print("\(destination)")
                NSWorkspace.shared.open(destination)
            }
            if let error = error {
                print("\(error)")
                let notification = NSUserNotification()
                notification.title = "Export Error"
                notification.informativeText = "Something went wrong during export, please try again."
                notification.soundName = nil
                NSUserNotificationCenter.default.delegate = self
                NSUserNotificationCenter.default.deliver(notification)
            }
        })
    }
    
    // TODO: Make me an extension with NSUserNotificationCenterDelegate
    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    // Export indicator
    private func updateExportIndicator() {
        // BUG: First time opened, it's not spinning: https://stackoverflow.com/questions/38031137/how-to-program-a-delay-in-swift-3
        exportProgress.usesThreadedAnimation = true
        if recording.isExporting {
            exportProgress.startAnimation(self)
            exportButton.isEnabled = false
        } else {
            self.exportProgress.stopAnimation(self)
            self.exportButton.isEnabled = true
        }
    }
    
    // Progress Timer & indicator
    private var progressTimer: Timer!
    
    private func toggleProgressTimer() {
        if recording.isRecording {
            if let button = exportButton {
                let cell = button.cell! as! NSButtonCell
                cell.backgroundColor = NSColor.red
                // cell.sound = NSSound(named: NSSound.Name("Morphy"))
                
            }
            progressTimer = Timer.scheduledTimer(
                // set up an update timer that is similar to how often we record
                timeInterval: recording.config.fragmentInterval,
                target: self,
                selector: #selector(updateProgressIndicator),
                userInfo: nil,
                repeats: true)

            // Make sure it updates when the menu is open
            RunLoop.main.add(progressTimer, forMode: .commonModes)
        } else {
            progressTimer.invalidate()
        }

    }
    
    @objc private func updateProgressIndicator() {
        let fragmentCount: Double = Double(recording.recordingFragments.count)
        let fragmentInterval: Double = Double(recording.config.fragmentInterval)
        let retention: Double = Double(recording.config.retention)
        let maxFragmentCount: Double = retention / fragmentInterval
        let exportableSeconds: Int = Int(fragmentCount * fragmentInterval)
        var readableTime = "\(exportableSeconds) seconds"
        if exportableSeconds == 1 {
            readableTime = "second"
        } else if exportableSeconds >= 120 {
            readableTime = "\(exportableSeconds/60) minutes"
        } else if exportableSeconds >= 60 {
            readableTime = "minute"
        }
        
        // update retentionProgress
        retentionProgress.isHidden = false
        retentionProgress.maxValue = maxFragmentCount
        retentionProgress.doubleValue = fragmentCount
        if fragmentCount >= maxFragmentCount {
            retentionProgress.isHidden = true
        }
        // update exportButton
        exportButton.title = "Export last \(readableTime)"
    }
    
    override func viewDidLayout() {
        // Doubledowns on ensuring that the indicator states are always correct
        updateExportIndicator()
        updateProgressIndicator()
    }
    
    init(_ rec: ContinuousRecording) {
        recording = rec
        savePanel = NSSavePanel()

        super.init(nibName: NSNib.Name(rawValue: "RecordingProgressView"), bundle: nil)

        configureSavePanel()
        observeRecording()
    }
    
    deinit {
        progressTimer.invalidate()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

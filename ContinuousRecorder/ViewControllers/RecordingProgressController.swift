//
//  RecordingProgressController.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 30/08/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Foundation
import Cocoa

class RecordingProgressController: NSViewController {
    // MARK: Outlets
    @IBOutlet weak var logoImage: NSImageView!
    @IBOutlet weak var exportButton: NSButton!
    @IBAction func buttonClicked(_ sender: NSButton) {
        self.openSavePanel()
    }
    @IBOutlet weak var recordingButton: NSButton!
    @IBAction func recordingButtonClicked(_ sender: Any) {
        switch recording.state {
        case .idle:
            self.recording.start()
        case .recording:
            self.recording.stop(clearFragments: true)
        case .recordingExporting:
            break
        }
    }
    
    // MARK: SavePanel
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
    
    // MARK: Observing the ContinuousRecording
    @objc private let recording: ContinuousRecording
    private var observers = [NSKeyValueObservation]()
    private func observeRecording() {
        observers = [
            self.recording.observe(\ContinuousRecording.state) { recording, observedChange in
                self.updateRecordingButton()
                self.updateExportButton()
            }
        ]
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
                self.presentNotification("Export Error", "Something went wrong during export, please try again.")
            }
        })
    }
    
//    // Export indicator
//    private func updateExportIndicator() {
//        // BUG: First time opened, it's not spinning: https://stackoverflow.com/questions/38031137/how-to-program-a-delay-in-swift-3
//        exportProgress.usesThreadedAnimation = true
//        if recording.isExporting {
//            exportProgress.startAnimation(self)
//            exportButton.isEnabled = false
//        } else {
//            self.exportProgress.stopAnimation(self)
//            self.exportButton.isEnabled = true
//        }
//    }
    
    // MARK: recordingButton
    private func updateRecordingButton() {
        switch recording.state {
        case .idle:
            recordingButton.isEnabled = true
            recordingButton.title = "Start Recording"
        case .recording:
            recordingButton.isEnabled = true
            recordingButton.title = "Stop Recording"
        case .recordingExporting:
            recordingButton.isEnabled = false
            recordingButton.title = "Exporting.."
        }
    }
    
    // MARK: exportButton
    private func updateExportButton() {
        switch recording.state {
        case .idle:
            logoImage.isHidden = false
            exportButton.isHidden = true
            exportButton.isEnabled = true
            if let timer = exportButtonTextTimer {
                timer.invalidate()
            }

        case .recording:
            logoImage.isHidden = true
            exportButton.isHidden = false
            exportButton.isEnabled = true
            updateExportButtonText()
            exportButtonTextTimer = Timer.scheduledTimer(
                timeInterval: recording.config.fragmentInterval,
                target: self,
                selector: #selector(updateExportButtonText),
                userInfo: nil,
                repeats: true)
            
            // Make sure it updates when the menu is open
            RunLoop.main.add(exportButtonTextTimer, forMode: .commonModes)

        case .recordingExporting:
            logoImage.isHidden = true
            exportButton.isHidden = false
            exportButton.isEnabled = false
        }
    }
    
    private var exportButtonTextTimer: Timer!
    
    @objc private func updateExportButtonText() {
        let fragmentCount: Double = Double(recording.recordingFragments.count)
        let fragmentInterval: Double = Double(recording.config.fragmentInterval)
        let exportableSeconds: Int = Int(fragmentCount * fragmentInterval)
        var readableTime = "\(exportableSeconds) seconds"
        if exportableSeconds == 1 {
            readableTime = "second"
        } else if exportableSeconds >= 120 {
            readableTime = "\(exportableSeconds/60) minutes"
        } else if exportableSeconds >= 60 {
            readableTime = "minute"
        }

        // update exportButton
        exportButton.title = "Export last \(readableTime)"
    }
    
    override func viewDidLayout() {
        // Doubledowns on ensuring that the indicator states are always correct
        updateExportButton()
        updateRecordingButton()
    }
    
    init(_ rec: ContinuousRecording) {
        recording = rec
        savePanel = NSSavePanel()

        super.init(nibName: NSNib.Name(rawValue: "RecordingProgressView"), bundle: nil)

        configureSavePanel()
        observeRecording()
    }
    
    deinit {
        exportButtonTextTimer.invalidate()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension RecordingProgressController: NSUserNotificationCenterDelegate {
    func presentNotification(_ title: String, _ informativeText: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = informativeText
        notification.soundName = nil
        NSUserNotificationCenter.default.delegate = self
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // ensure the notification is shown at the top right of the screen and not only in the notifications center
    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
}

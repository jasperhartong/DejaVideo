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
    @IBOutlet weak var image: NSImageView!
    @IBOutlet weak var exportButton: LayerBackedButton!
    @IBAction func exportButtonClicked(_ sender: NSButton) {
        self.openSavePanel()
    }
    @IBOutlet weak var startButton: LayerBackedButton!
    @IBAction func startButtonClicked(_ sender: Any) {
        if recording.state == .idle {
            self.recording.start()
        }
    }
    
    @IBOutlet weak var stopButton: LayerBackedButton!
    @IBAction func stopButtonClicked(_ sender: Any) {
        if recording.state == .recording {
            self.recording.stop(clearFragments: true)
        }
    }
    
    // MARK: Callbacks
    var savePanelOpened: (() -> Void)?
    
    // MARK: Images
    private let imageExporting: NSImage = NSImage(named: NSImage.Name(rawValue: "exporting-indicator-400w"))!
    private let imageLogo: NSImage = NSImage(named: NSImage.Name(rawValue: "deja-video-400w"))!
    
    // MARK: SavePanel
    private let savePanel: NSSavePanel
    private func configureSavePanel() {
        savePanel.allowedFileTypes = ["mp4"]
        savePanel.allowsOtherFileTypes = false
        savePanel.level = .modalPanel
    }
    private func openSavePanel () {
        let prepSuccess = recording.prepExporting()
        if !prepSuccess {
            presentNotification("Export Error", "Something went wrong preparing the export, please try again.")
            return
        }
        // optional callback
        savePanelOpened?()
        
        // Make sure that savePanel is on top an in focus
        NSApp.activate(ignoringOtherApps: true)
        
        // open savePanel and await response
        savePanel.begin { (modalResponse) in
            self.savePanelCallback(modalResponse)
        }
    }
    
    private func savePanelCallback(_ modalResponse: NSApplication.ModalResponse) {
        // turn off app focus
        NSApp.activate(ignoringOtherApps: false)

        switch modalResponse {
        case .OK:
            if let destination = self.savePanel.url {
                self.renderTo(destination: destination)
            } else {
                fallthrough
            }
        case .cancel:
            let cancelSuccess = self.recording.cancelExport()
            if !cancelSuccess {
                self.presentNotification("Export Error", "Something went wrong cancelling the export, best is to restart the app. Sorry :).")
            }
        default:
            self.presentNotification("Export Error", "No destination could be determined, please try again.")
        }
    }
    
    // MARK: Observing the ContinuousRecording
    @objc private let recording: ContinuousRecording
    private var observers = [NSKeyValueObservation]()
    private func observeRecording() {
        observers = [
            self.recording.observe(\ContinuousRecording.state) { recording, observedChange in
                self.updateRecordingButtons()
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
    
    // MARK: recordingButton
    private func updateRecordingButtons(firstTime: Bool = false) {
        switch recording.state {
        case .idle:
            startButton.isEnabled = true
            startButton.title = "Start Recording"
            stopButton.isEnabled = false
            stopButton.hide(animated: !firstTime)
        case .recording:
            startButton.isEnabled = false
            stopButton.isEnabled = true
            stopButton.show(animated: !firstTime)
        case .exporting, .preppedExport:
            startButton.isEnabled = false
            startButton.title = "Exporting.."
            stopButton.hide(animated: !firstTime)
        }
    }
    
    // MARK: exportButton
    private func updateExportButton(firstTime: Bool = false) {
        switch recording.state {
        case .idle:
            image.image = imageLogo
            exportButton.hide(animated: !firstTime)
            if let timer = exportButtonTextTimer {
                timer.invalidate()
            }

        case .recording:
            image.image = imageLogo
            exportButton.show(animated: !firstTime)
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

        case .exporting, .preppedExport:
            // TODO: Let image animate while exporting
            image.image = imageExporting
            exportButton.hide()
        }
    }
    
    private var exportButtonTextTimer: Timer!
    
    @objc private func updateExportButtonText() {
        let fragmentCount: Double = Double(recording.fragmentCount)
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

    override func viewDidLoad() {
        updateExportButton(firstTime:true)
        updateRecordingButtons(firstTime:true)
    }
    
    override func viewWillLayout() {
        // Doubledowns on ensuring that the indicator states are always correct
        updateExportButton()
        updateRecordingButtons()
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

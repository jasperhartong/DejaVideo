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
    // Observing the ContinuousRecording
    @objc private let recording: ContinuousRecording
    private var observers = [NSKeyValueObservation]()
    private func observeRecording() {
        observers = [
            self.recording.observe(\ContinuousRecording.isRecording) { recording, observedChange in
                self.toggleProgressTimer()
            }
        ]
    }
    
    // Outlets
    @IBOutlet weak var exportProgress: NSProgressIndicator!
    @IBOutlet weak var retentionProgress: NSProgressIndicator!
    @IBOutlet weak var exportButton: NSButton!
    @IBAction func buttonClicked(_ sender: NSButton) {
        // Save to temporary location for now
        let destination = NSURL.fileURL(withPathComponents: [ NSTemporaryDirectory(), "temporary.mov"])!
        // show we're doing something
        exportProgress.startAnimation(self)
        
        recording.renderCurrentRetention(destination, {(destination, error) -> Void in
            // We're done
            self.exportProgress.stopAnimation(self)
            if let destination = destination {
                print("\(destination)")
                NSWorkspace.shared.open(destination)
            }
            if let error = error {
                print("\(error)")
            }
        })
    }
    
    // Progress Timer
    private var progressTimer: Timer!
    
    private func toggleProgressTimer() {
        if recording.isRecording {
            if let button = exportButton {
                let cell = button.cell! as! NSButtonCell
                cell.backgroundColor = NSColor.red
                cell.sound = NSSound(named: NSSound.Name("Morphy"))
                
            }
            progressTimer = Timer.scheduledTimer(
                // set up an update timer that is similar to how often we record
                timeInterval: recording.config.fragmentInterval,
                target: self,
                selector: #selector(updateProgress),
                userInfo: nil,
                repeats: true)
            // Make sure it updates when the menu is open
            RunLoop.main.add(progressTimer, forMode: .commonModes)
        } else {
            progressTimer.invalidate()
        }

    }
    
    @objc private func updateProgress() {
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
    
    init(_ rec: ContinuousRecording) {
        recording = rec
        super.init(nibName: NSNib.Name(rawValue: "RecordingProgressView"), bundle: nil)
        observeRecording()
    }
    
    deinit {
        progressTimer.invalidate()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

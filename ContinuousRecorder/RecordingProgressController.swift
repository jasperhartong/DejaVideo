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
    @IBOutlet weak var circularProgress: NSProgressIndicator!
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
        circularProgress.maxValue = recording.config.retention / recording.config.fragmentInterval
        circularProgress.doubleValue = Double(recording.recordingFragments.count)
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

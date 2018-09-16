//
//  ContinuousRecorder.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 24/08/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//
import os
import AVFoundation


/**
 
 * What happens if;
 * - Disk is full?
 * - Computer goes to sleep?
 * - A recording session crashes?
 * - The fps/ quality is changed (while recording)?
 * - the resolution is changed of the recorded display?
 * - the user is inactive for a long period/ becomes active after a long period
 
 
 * Additions:
 * - Make the separate methods unit-testable
 * - Make all idempotent
 * - Ignore own menu window
 * - Allow to ignore incognito windows
 * - SystemWide Shortcut
 * - Plugin architecture for tracking other things in a sliding window
 * - Blurring facilities
 
 */

enum fragmentRecorderError: Error {
    case couldNotAddScreen  // TODO: use me ?
    case couldNotExport
}

struct ContinuousRecordingConfig {
    // How long do we retain recordings for? (seconds)
    let retention: Double = 120.0
    // Config defining in how many files to separate, defines diskspace
    let fragmentInterval: Double = 0.25
}

class TimeStamped: NSObject {
    public let creationDate: Date = Date()
    public var modificationDate: Date = Date()
}

class RecordingFragment: TimeStamped {
    private let manager: RecordingFragmentManager
    private let index: Int
    private let fileNamePrefix = "RecordingFragment"
    private let fileURL: URL
    private var grabFrameTimer: Timer!
    public var mousePoint: CGPoint?
    public var image: CGImage?
    
    private var isCurrentFragment: Bool {
        return index == manager.nextFragmentCount - 1
    }
    
    override var description: String {
        return "RecordingFragment:: \(fileURL)"
    }
    
    init(_ manager: RecordingFragmentManager, _ index: Int) {
        self.manager = manager
        self.index = index
        self.fileURL = NSURL.fileURL(withPathComponents: [
            manager.fragmentDirectory,
            "\(fileNamePrefix)\(manager.sharedUniqueString)\(index).png"
            ])!
        
        self.image = CGWindowListCreateImage(  // lower impact than CGDisplayCreateImage(delegate.screenId)
            CGRect.infinite,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution)
        
        let fakeEvent = CGEvent(source: nil)
        if let fakeEvent = fakeEvent {
            self.mousePoint = fakeEvent.location
        }
    }
    
    func toPNG() {
        if let image = image, let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, kUTTypePNG, 1, nil){
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
    }
}

class RecordingFragmentManager: TimeStamped {
    private var fragmentTimer: RepeatingBackgroundTimer!
    let fragmentDirectory = NSTemporaryDirectory()
    let sharedUniqueString = NSUUID().uuidString
    
    var recordingFragments: [RecordingFragment] = []
    var nextFragmentCount = 0
    @objc dynamic var isRecording: Bool = false
    
    private let retention: Double
    private let interval: Double
    
    @objc private func fragmentTimerFired() {
        nextFragment()
        vacuumFragments()
    }

    /**
        Release references to old fragments so their deinit is called
    */
    private func vacuumFragments() {
        let minRetentionDate = Date().addingTimeInterval(-retention)
        recordingFragments = recordingFragments.filter{$0.creationDate > minRetentionDate}
    }

    /**
        Initiates a new fragment and appends to recordingFragments
     */
    private func nextFragment() {
        let next = RecordingFragment(self, nextFragmentCount)
        recordingFragments.append(next)
        // Keep track of amount of fragments created during complete session
        nextFragmentCount += 1
    }
    
    // MARK: public
    init(retention: Double, interval: Double) {
        self.retention = retention
        self.interval = interval
    }
    
    func startFragmentTimer() {
        if isRecording {
            return
        }
        isRecording = true

        // first fire immediatly
        fragmentTimerFired()

        fragmentTimer = RepeatingBackgroundTimer(timeInterval: interval)
        fragmentTimer.eventHandler = {
            self.fragmentTimerFired()
        }
        fragmentTimer.resume()
    }
    
    func invalidateFragmentTimer() {
        if !isRecording {
            return
        }
        isRecording = false
        if let timer = fragmentTimer {
            timer.suspend()
        }
    }
    
    /**
        Release references to all fragments so their deinit is called
     */
    func clearAllFragments() {
        recordingFragments = []
    }
    
    var allTimeFragmentCount: Int {
        return nextFragmentCount - 1
    }
    
    var currentFragmentCount: Int {
        return recordingFragments.count
    }
    
}

// TODO: Implement the below in a statemachine with transitions

/*
                          <==========================(error)=
                          <===========================(done)=
 idle =(start)=> recording =(prep)=> preppedExport =(export)=> exporting
      <=(stop)=            <(cancel)=
*/

@objc
enum RecordingState: Int {
    case idle
    case recording
    case preppedExport
    case exporting
}


@objcMembers class ContinuousRecording: RecordingFragmentManager {
    let screenId: CGDirectDisplayID
    let config: ContinuousRecordingConfig
    
    var exportFragments: [RecordingFragment] = []
    
    private let stateKey: String = "ContinuousRecording::state"
    @objc dynamic var state: RecordingState = .idle {
        didSet {
            UserDefaults.standard.set(state.rawValue, forKey: stateKey)
        }
    }
    
    private func recoverState() {
        let recoveredState = RecordingState(rawValue: UserDefaults.standard.integer(forKey: stateKey))

        // Restart recording if it wasn't idle before
        if (recoveredState != .idle) {
            start()
        }
    }
    
    init(
        screenId: CGDirectDisplayID = CGMainDisplayID(),
        config: ContinuousRecordingConfig = ContinuousRecordingConfig()
        ) throws {
        self.screenId = screenId
        self.config = config
        super.init(retention: config.retention, interval: config.fragmentInterval)
        recoverState()
    }
    
    func start() {
        if (state != .idle) {
            return
        }
        startFragmentTimer()
        state = .recording
    }

    func stop(clearFragments: Bool = false) {
        if (state != .recording) {
            return
        }
        invalidateFragmentTimer()

        if clearFragments {
            clearAllFragments()
        }
        state = .idle
    }
    
    func prepExporting() -> Bool {
        if state != .recording {
            return false
        }
        // move current recordings to be ready for export
        exportFragments = recordingFragments
        recordingFragments = []

        state = .preppedExport
        return true
    }
    
    func cancelExport() -> Bool {
        if state != .preppedExport {
            return false
        }
        // move back fragments that would be exported
        recordingFragments = recordingFragments + exportFragments
        
        state = .recording
        return true
    }
    
    func exportCurrentRetention(_ destination: URL, _ completion: @escaping ((URL?, Error?) -> Void)){
        // you can only export if it's prepped
        if state != .preppedExport {
            completion(nil, fragmentRecorderError.couldNotExport)
            return
        }
        guard let anImage = self.exportFragments.first?.image else {
            _ = cancelExport()
            completion(nil, fragmentRecorderError.couldNotExport)
            return
        }
        state = .exporting
        
        
        NSLog("Exporting \(exportFragments.count) fragments ")

        let queue = DispatchQueue(label:"export", qos: .userInitiated)
        queue.async {
            let settings = VidWriter.videoSettings(
                codec: AVVideoCodecType.h264,
                width: anImage.width,
                height: anImage.height)

            // Note: Currently we always overwrite the destination by first deleting it
            // TODO: Add more error cases? Like when writing fails?
            do {
                try FileManager.default.removeItem(at: destination)
            } catch {print(error.localizedDescription)}
            
            let vidWriter = VidWriter(url: destination, vidSettings: settings)
            vidWriter.applyTimeWith(duration: Float(self.config.fragmentInterval), frameNumber: self.exportFragments.count)
            
            vidWriter.createMovieFrom(fragments: self.exportFragments, completion: { (destination) in
                self.exportFragments = []
                self.state = .recording
                completion(destination, nil)
                NSLog("Exporting fragments: DONE ")
            })
        }
    }
}

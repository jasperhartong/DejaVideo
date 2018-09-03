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

//        if let image = self.image, let point = self.mousePoint {
//            NSLog("\(image.hashValue) :: \(self.index) / \(manager.recordingFragments.count) :: \(point.x),\(point.y)")
//        }
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

//enum RecordingState {
//    case initialized
//    case starting
//    case started
//    case stopping
//    case stopped
//}
//
//enum ExportState {
//    case Exporting
//    case error
//    case idle
//}

@objcMembers class ContinuousRecording: RecordingFragmentManager {
    let screenId: CGDirectDisplayID
    let config: ContinuousRecordingConfig

    @objc dynamic var isExporting: Bool = false
    
    init(
        screenId: CGDirectDisplayID = CGMainDisplayID(),
        config: ContinuousRecordingConfig = ContinuousRecordingConfig()
        ) throws {
        self.screenId = screenId
        self.config = config
        super.init(retention: config.retention, interval: config.fragmentInterval)
    }
    
    func start() {
        startFragmentTimer()
    }

    func stop(clearFragments: Bool = false) {
        invalidateFragmentTimer()

        if clearFragments {
            clearAllFragments()
        }
    }
    
    func exportCurrentRetention(_ destination: URL, _ completion: @escaping ((URL?, Error?) -> Void)){
        guard let anImage = self.recordingFragments.first?.image else {
            completion(nil, fragmentRecorderError.couldNotExport)
            return
        }
        isExporting = true
        
        // Make sure to trim at where we are now
        invalidateFragmentTimer()
        startFragmentTimer()
        
        NSLog("Exporting \(recordingFragments.count) fragments ")

        let queue = DispatchQueue(label:"export", qos: .utility)
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
            vidWriter.applyTimeWith(duration: Float(self.config.fragmentInterval), frameNumber: self.recordingFragments.count)
            
            vidWriter.createMovieFrom(fragments: self.recordingFragments, completion: { (destination) in
                self.clearAllFragments() // TODO: It shouldn't actually be cleared completely here, as the frames captured while exporting will then also be dropped
                completion(destination, nil)
                self.isExporting = false
                NSLog("Exporting fragments: DONE ")
            })
        }
    }
}

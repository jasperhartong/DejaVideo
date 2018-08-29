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
 */

enum fragmentRecorderError: Error {
    case couldNotAddScreen  // TODO: use me ?
    case couldNotExport
}

struct ContinuousRecordingConfig {
    // How long do we retain recordings for? (seconds)
    let retention: Double = 60.0
    // Config defining in how many files to separate, defines diskspace
    let fragmentInterval: Double = 0.5
}

class TimeStamped: NSObject {
    public let creationDate: Date = Date()
    public var modificationDate: Date = Date()
}

class RecordingFragment: TimeStamped {
    private let manager: RecordingFragmentManager
    private let delegate: ContinuousRecording
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
    
    init(_ manager: RecordingFragmentManager, _ delegate: ContinuousRecording, _ index: Int) {
        self.manager = manager
        self.delegate = delegate
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

        if let image = self.image, let point = self.mousePoint {
            NSLog("\(image.hashValue) :: \(self.index) / \(manager.recordingFragments.count) :: \(point.x),\(point.y)")
        }
    }
    
    func toPNG() {
        if let image = image, let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, kUTTypePNG, 1, nil){
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
    }
}

class RecordingFragmentManager {
    private var delegate: ContinuousRecording!
    
    private var fragmentTimer: RepeatingBackgroundTimer!
    private var _isRecording: Bool = false
    let fragmentDirectory = NSTemporaryDirectory()
    let sharedUniqueString = NSUUID().uuidString
    
    var recordingFragments: [RecordingFragment] = []
    var nextFragmentCount = 0
    
    private let retention: Double
    private let interval: Double
    
    @objc private func fragmentTimerFired() {
        nextFragment()
        vacuumFragments()
    }
    
    private func vacuumFragments() {
        let minRetentionDate = Date().addingTimeInterval(-retention)
        recordingFragments = recordingFragments.filter{$0.creationDate > minRetentionDate}
    }
    
    private func nextFragment() {
        let next = RecordingFragment(self, delegate, nextFragmentCount)
        recordingFragments.append(next)
        // Keep track of amount of fragments created during complete session
        nextFragmentCount += 1
    }
    
    // MARK: public
    init(retention: Double, interval: Double) {
        self.retention = retention
        self.interval = interval
    }
    
    func setDelegate(_ delegate: ContinuousRecording) {
        self.delegate = delegate
    }
    
    func startFragmentTimer() {
        // first fire immediatly
        fragmentTimerFired()

        fragmentTimer = RepeatingBackgroundTimer(timeInterval: interval)
        fragmentTimer.eventHandler = {
            self.fragmentTimerFired()
        }
        fragmentTimer.resume()
        

        _isRecording = true
    }
    
    func invalidateFragmentTimer() {
        fragmentTimer.suspend()
        _isRecording = false
    }
    
    var isRecording: Bool {
        return _isRecording
    }
    
    func clearAllFragments() {
        // deinits make sure to remove the file
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

class ContinuousRecording: TimeStamped {
    private let fragmentManager: RecordingFragmentManager
    private let config: ContinuousRecordingConfig
    public let screenId: CGDirectDisplayID
    
    
    private var onStartCallback: (() -> Void)?
    private func didStart() {
        if let onStartCallback = onStartCallback {
            onStartCallback()
            self.onStartCallback = nil
        }
    }
    
    init(
        screenId: CGDirectDisplayID = CGMainDisplayID(),
        config: ContinuousRecordingConfig = ContinuousRecordingConfig()
        ) throws {
        self.screenId = screenId
        self.config = config
        self.fragmentManager = RecordingFragmentManager(
            retention: config.retention,
            interval: config.fragmentInterval)
    }
    
    func start(onStartCallback: @escaping (() -> Void)) {
        if !isRecording {
            self.fragmentManager.setDelegate(self)
            self.onStartCallback = onStartCallback
            self.fragmentManager.startFragmentTimer()
        }
    }
    func stop(clearFragments: Bool = false) {
        fragmentManager.invalidateFragmentTimer()

        if clearFragments {
            fragmentManager.clearAllFragments()
        }
    }
    
    var isPreparingRecording: Bool {
        return false
    }
    
    var isRecording: Bool {
        return fragmentManager.isRecording
    }
    
    func renderCurrentRetention(_ destination: URL, _ completion: @escaping ((URL?, Error?) -> Void)){
        guard let anImage = self.fragmentManager.recordingFragments[0].image else {
            completion(nil, fragmentRecorderError.couldNotExport)
            return
        }
        
        // Make sure to trim at where we are now
        fragmentManager.invalidateFragmentTimer()
        fragmentManager.startFragmentTimer()
        
        NSLog("Exporting \(fragmentManager.recordingFragments.count) fragments ")

        let queue = DispatchQueue(label:"export", qos: .utility)
        queue.async {
            var images: [CGImage] = []
            let settings = VidWriter.videoSettings(
                codec: AVVideoCodecType.h264,
                width: anImage.width,
                height: anImage.height)
            
            for fragment in self.fragmentManager.recordingFragments {
                if let image = fragment.image {
                    images.append(image)
                }
            }

            // Note: Currently we always overwrite the destination by first deleting it
            // TODO: Add more error cases? Like when writing fails?
            do {
                try FileManager.default.removeItem(at: destination)
            } catch {print(error.localizedDescription)}
            
            let vidWriter = VidWriter(url: destination, vidSettings: settings)
            vidWriter.applyTimeWith(duration: Float(self.config.fragmentInterval), frameNumber: self.fragmentManager.recordingFragments.count)
            
            vidWriter.createMovieFrom(images: images, completion: { (destination) in
                completion(destination, nil)
                NSLog("Exporting fragments: DONE ")
            })
        }
    }
    
}

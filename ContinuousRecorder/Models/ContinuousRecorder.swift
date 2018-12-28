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
    let retention: Double
    // Config defining in how many files to separate, defines diskspace
    let fps: Double
    // Config defining the scale in relation to the display
    let scale: Double
    
    init(
        retention: Double = 60.0,
        fps: Double = 3.0,
        scale: Double = 0.5
    ) {
        self.retention = retention
        self.fps = fps
        self.scale = scale
    }
    
    var fragmentInterval: Double {
        return 1.0 / fps
    }
}

class TimeStamped: NSObject {
    public let creationDate: Date = Date()
    public var modificationDate: Date = Date()
}

class ScaledRecordingFragment: TimeStamped {
    private let scale: Double
    public var mousePoint: CGPoint?
    public var image: CGImage?
    
    override var description: String {
        return "RecordingFragment"
    }
    
    init(scale: Double = 1.0) {
        self.scale = scale
        super.init()
        self.capture()
    }
    
    func capture() {
        // Only record the display with menu bar
        if let screenWithMenuBarId = CGDirectDisplayID.withMenuBar {
            self.image = scaleImage(CGWindowListCreateImage(  // lower impact than CGDisplayCreateImage(delegate.screenId)
                CGDisplayBounds(screenWithMenuBarId),
                .optionOnScreenOnly,
                kCGNullWindowID,
                .nominalResolution))
            
            let fakeEvent = CGEvent(source: nil)
            if let fakeEvent = fakeEvent {
                self.mousePoint = scaleMousePoint(fakeEvent.location)
            }
        }
    }
    
    // Use CGContext: Energy impact: LOW + ~9 wakes, 12.3RAM AFTER EXPORT: 26,8MB RAM
    func scaleImage(_ cgImage: CGImage?) -> CGImage? {
        guard cgImage != nil && scale != 1.0  else {
            return cgImage
        }

        let scaledWidth = Int(Double(cgImage!.width) * scale)
        let scaledHeight = Int(Double(cgImage!.height) * scale)

        let context: CGContext = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: cgImage!.bitsPerComponent,
            bytesPerRow: cgImage!.bytesPerRow,
            space: cgImage!.colorSpace!,
            bitmapInfo: cgImage!.bitmapInfo.rawValue)!
        
        // Make me a setting as well
        context.interpolationQuality = .high
        
        context.draw(cgImage!, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        if let scaledImage: CGImage = context.makeImage() {
            return scaledImage
        }
        return cgImage
    }
    
    func scaleMousePoint(_ point: CGPoint?) -> CGPoint? {
        guard point != nil && scale != 1.0  else {
            return point
        }
        
        return CGPoint(x: Double(point!.x) * scale, y: Double(point!.y) * scale)
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

@objcMembers class ContinuousRecording: TimeStamped {
    var config: ContinuousRecordingConfig

    var recordingFragments: [ScaledRecordingFragment] = []
    private var exportFragments: [ScaledRecordingFragment] = []
    private var fragmentTimer: RepeatingBackgroundTimer!
    private var allTimeFragmentCount = 0
    
    private let stateKey: String = "ContinuousRecording::state"
    @objc dynamic var state: RecordingState = .idle {
        didSet {
            UserDefaults.standard.set(state.rawValue, forKey: stateKey)
        }
    }
    
    init(
        config: ContinuousRecordingConfig = ContinuousRecordingConfig()
        ) throws {
        self.config = config

        super.init()

        recoverState()
    }
    
    // MARK: Getters

    /// Returns either the last recorded fragment, or a temporary fragment
    var aFragment: ScaledRecordingFragment {
        guard recordingFragments.count > 0 else {
            return ScaledRecordingFragment(scale: config.scale)
        }
        return recordingFragments.last!
    }
    
    /// Returns the current fragment count
    var fragmentCount: Int {
        return recordingFragments.count
    }

    /// Returns memory size of one fragment given the current config
    var fragmentSize: Int {
        let temporaryFragment = self.aFragment
        
        if let image = temporaryFragment.image {
            return image.bytesPerRow * image.height
        }
        // Or return a realistic default like: 7056000 ?
        return 0
    }


    // MARK: State transitions

    /// State transition: Start
    func start() {
        if state != .idle {
            return
        }
        startFragmentTimer()
        state = .recording
    }
    
    /// State transition: Stop
    func stop(clearFragments: Bool = false) {
        if state != .recording {
            return
        }
        invalidateFragmentTimer()

        if clearFragments {
            recordingFragments = []
        }
        state = .idle
    }
    
    /// State transition: Prep Exporting
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
    
    /// State transition: Cancel Prepped Export
    func cancelExport() -> Bool {
        if state != .preppedExport {
            return false
        }
        // move back fragments that would be exported
        recordingFragments = recordingFragments + exportFragments
        
        state = .recording
        return true
    }
    
    /// State transition: Perform export
    func exportCurrentRetention(_ destination: URL, _ completion: @escaping ((URL?, Error?) -> Void)){
        // you can only export if it's prepped
        if state != .preppedExport {
            completion(nil, fragmentRecorderError.couldNotExport)
            return
        }
        // Calculate maximum recorded screen size
        var width = 0
        var height = 0
        for fragment in self.exportFragments {
            if let image = fragment.image {
                width = image.width > width ? image.width : width
                height = image.height > height ? image.height : height
            }
        }
        if width == 0 || height == 0 {
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
                width: width,
                height:height)

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
    
    /// State transition: Update config
    func update(newConfig: ContinuousRecordingConfig) {
        if state == .preppedExport || state == .exporting {
            return
        }
        recordingFragments = []
        config = newConfig
        
        // Not really changing state, staying in .idle or .recording depending on where we were
    }
    
    // MARK: Private fragment management

    @objc private func fragmentTimerFired() {
        nextFragment()
        vacuumFragments()
    }
    
    /**
     Initiates a new fragment and appends to recordingFragments
     */
    private func nextFragment() {
        let next = ScaledRecordingFragment(scale: config.scale)
        
        recordingFragments.append(next)
        // Keep track of amount of fragments created during complete session
        allTimeFragmentCount += 1
    }
    
    /**
     Release references to old fragments so their deinit is called
     */
    private func vacuumFragments() {
        let minRetentionDate = Date().addingTimeInterval(-config.retention)
        recordingFragments = recordingFragments.filter{$0.creationDate > minRetentionDate}
    }
    
    private func startFragmentTimer() {
        // first fire immediatly
        fragmentTimerFired()
        
        fragmentTimer = RepeatingBackgroundTimer(timeInterval: config.fragmentInterval)
        fragmentTimer.eventHandler = {
            self.fragmentTimerFired()
        }
        fragmentTimer.resume()
    }
    
    private func invalidateFragmentTimer() {
        if let timer = fragmentTimer {
            timer.suspend()
        }
    }
    
    // MARK: Private state management
    private func recoverState() {
        let recoveredState = RecordingState(rawValue: UserDefaults.standard.integer(forKey: stateKey))
        
        // Restart recording if it wasn't idle before
        if (recoveredState != .idle) {
            start()
        }
    }

}

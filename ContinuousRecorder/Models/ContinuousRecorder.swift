//
//  ContinuousRecorder.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 24/08/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//
import AVFoundation


/**
 * What happens if;
 * - Disk is full?
 * - Computer goes to sleep?
 * - A recording session crashes?
 * - The fps/ quality is changed (while recording)?
 *
 * Additions:
 * - Make the separate methods unit-testable
 * - Make all idempotent
 */


enum fragmentRecorderError: Error {
    case invalidAudioDevice
    case couldNotAddScreen
    case couldNotAddMic
    case couldNotAddOutput
    case couldNotSetPreset
    case couldNotExport
}

struct ContinuousRecordingConfig {
    // How long do we retain recordings for? (seconds)
    let retention: Double = 300.0
    // Config defining quality & size
    let capturePreset: AVCaptureSession.Preset = .qHD960x540
    let framesPerSecond: Int32 = 5
    // Config defining in how many files to separate, defines diskspace
    let fragmentInterval: Double = 30.0
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
            "\(fileNamePrefix)\(manager.sharedUniqueString)\(index).mp4"
            ])!
    }
    
    deinit {
        print("\(self.description)::\(#function)")
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {print(error.localizedDescription)}
    }
    
    func start() {
        delegate.output.startRecording(to: fileURL, recordingDelegate: delegate)
    }
    
    var videoAssetTrack: AVAssetTrack? {
        // Don't try to return a track that is currently being written to
        if (isCurrentFragment) { return nil }
        
        let videoAsset = AVAsset(url: fileURL)
        let videoAssetTracks = videoAsset.tracks(withMediaType: AVMediaType.video)
        if videoAssetTracks.count > 0 {
            return videoAssetTracks[0]
        }
        return nil
    }
    
}

class RecordingFragmentManager {
    private var delegate: ContinuousRecording!
    
    private var fragmentTimer: Timer!
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
        recordingFragments = recordingFragments.filter{$0.modificationDate > minRetentionDate}
    }
    
    private func nextFragment() {
        let next = RecordingFragment(self, delegate, nextFragmentCount)
        next.start()
        // Now that the next is started, the last is stopped, update it's modification date
        if let prev = recordingFragments.last {
            prev.modificationDate = Date()
        }
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
        fragmentTimer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(fragmentTimerFired),
            userInfo: nil,
            repeats: true)
    }
    
    func invalidateFragmentTimer() {
        if !fragmentTimer.isValid {
            fragmentTimer.invalidate()
        }
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
    private let session: AVCaptureSession
    private let input: AVCaptureScreenInput
    public let output: AVCaptureMovieFileOutput
    
    
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
        self.config = config
        self.fragmentManager = RecordingFragmentManager(
            retention: config.retention,
            interval: config.fragmentInterval)
        
        // Setup session
        session = AVCaptureSession()
        if (session.canSetSessionPreset(config.capturePreset)) {
            print(config.capturePreset.rawValue)
            session.sessionPreset = config.capturePreset
        } else { throw fragmentRecorderError.couldNotSetPreset }
        
        // Setup input
        input = AVCaptureScreenInput(displayID: screenId)
        input.cropRect = CGDisplayBounds(screenId) //CGRect(origin: CGPoint(x:0,y:0),size: CGSize(width:10,height:10))
        input.scaleFactor = 1.0
        input.capturesCursor = false
        input.capturesMouseClicks = false
        input.minFrameDuration = CMTimeMake(1, self.config.framesPerSecond)
        
        if session.canAddInput(input) {
            session.addInput(input)
        } else { throw fragmentRecorderError.couldNotAddScreen }
        
        // Setup output
        output = AVCaptureMovieFileOutput()
        // let us manage fragments ourselvels
        output.movieFragmentInterval = kCMTimeInvalid
        output.minFreeDiskSpaceLimit = 1024 * 1024
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else { throw fragmentRecorderError.couldNotAddOutput }
        
        /// Default to HEVC  when on 10.13 or newer and encoding is hardware supported?
        /// Hardware encoding is supported on 6th gen Intel processor or newer.
        output.setOutputSettings([
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: 540,
            AVVideoWidthKey: 960,
            AVVideoCompressionPropertiesKey: [
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
//                AVVideoAverageBitRateKey: 512000,
//                AVVideoMaxKeyFrameIntervalDurationKey: 5,
//                AVVideoExpectedSourceFrameRateKey: config.framesPerSecond,
            ]
        ], for: output.connection(with: .video)!)
    }
    
    func start(onStartCallback: @escaping (() -> Void)) {
        if !session.isRunning {
            fragmentManager.setDelegate(self)
            self.onStartCallback = onStartCallback
            session.startRunning()
            fragmentManager.startFragmentTimer()
        }
    }
    func stop(clearFragments: Bool = false) {
        fragmentManager.invalidateFragmentTimer()
        
        if output.isRecording {
            output.stopRecording()
        }
        if session.isRunning {
            session.stopRunning()
        }
        if clearFragments {
            fragmentManager.clearAllFragments()
        }
    }
    
    var isPreparingRecording: Bool {
        return session.isRunning && !output.isRecording
    }
    
    var isRecording:Bool {
        return output.isRecording
    }
    
    func renderCurrentRetention(_ destination: URL, _ completion: @escaping ((URL?, Error?) -> Void)){
        // Make sure to trim at where we are now
        fragmentManager.invalidateFragmentTimer()
        fragmentManager.startFragmentTimer()
        
        // Set up a mixcomposition that holds the final video
        let mixComposition = AVMutableComposition()
        var mutableCompositionVideoTrack = [AVMutableCompositionTrack]()
        let compositionAddVideo = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        mutableCompositionVideoTrack.append(compositionAddVideo!)
        
        // Combine the different fragment videos into the mixcomposition
        var lastTimeStamp = kCMTimeZero
        for fragment in fragmentManager.recordingFragments{
            if let assetTrack = fragment.videoAssetTrack {
                do {
                    try mutableCompositionVideoTrack[0].insertTimeRange(
                        CMTimeRangeMake(kCMTimeZero, assetTrack.timeRange.duration),
                        of: assetTrack,
                        at: lastTimeStamp)
                    lastTimeStamp = lastTimeStamp + assetTrack.timeRange.duration
                } catch {
                    completion(nil, error)
                    return
                }
            }
        }
        
        if (lastTimeStamp == kCMTimeZero) {
            completion(nil, fragmentRecorderError.couldNotExport)
            return
        }
        
        print("export the mixComposition and call correct callbacks")
        let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetPassthrough)!
        assetExport.outputFileType = AVFileType.mp4
        assetExport.shouldOptimizeForNetworkUse = true
        assetExport.outputURL = destination
        
        print("\(#function)::exportAsynchronously")
        assetExport.exportAsynchronously { () -> Void in
            switch assetExport.status {
            case AVAssetExportSessionStatus.completed:
                print("\(#function)::completed")
                completion(destination, nil)
            case AVAssetExportSessionStatus.failed:
                print("\(#function)::failed")
                completion(nil, assetExport.error!)
            case AVAssetExportSessionStatus.cancelled:
                print("\(#function)::cancelled")
                completion(nil, assetExport.error!)
            default:
                print("\(#function)::errored (default)")
                completion(nil, assetExport.error!)
            }
        }
    }
    
}

extension ContinuousRecording: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        didStart()
    }
    
    func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let FINISHED_RECORDING_ERROR_CODE = -11806
        if let error = error, error._code != FINISHED_RECORDING_ERROR_CODE {
            //              onError?(error)
            print("fileOutput::error: \(error.localizedDescription)")
        } else {
            print("fileOutput::finished")
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didPauseRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("fileOutput::pause")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didResumeRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("fileOutput::resume")
    }
    
    func fileOutputShouldProvideSampleAccurateRecordingStart(_ output: AVCaptureFileOutput) -> Bool {
        return true
    }
}

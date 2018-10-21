//
//  ExportEffectWindowController.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 16/09/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Foundation
import AppKit


class ExportEffectWindowController: NSWindowController {
    @objc var recording: ContinuousRecording!
    private var observers = [NSKeyValueObservation]()
    // MARK: - Public methods
    
    func show() {
        window?.setIsVisible(true)
        startAnimation()
    }
    
    func hide() {
        stopAnimation(completion: {() -> Void in
            self.window?.setIsVisible(false)
        })
    }
    
    func showFor(seconds: TimeInterval) {
        // Needs explicit delay so it's not performed immediatly in sync
        let explicitDelay: TimeInterval = 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + explicitDelay) {
            self.show()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + explicitDelay + seconds) {
            self.hide()
        }
    }
    
    // MARK: - Initialization
    private let iconLayer = CALayer()

    init(_ recording: ContinuousRecording) {
        self.recording = recording

        // settings window:nil will let super use .windowNibName
        super.init(window:nil)

        initWindowAsHiddenOverlay()
        addIconLayer()
        observeRecording()
    }
    
    private func observeRecording() {
        observers = [
            self.recording.observe(\ContinuousRecording.state) { recording, observedChange in
                switch recording.state {
                case .idle, .recording, .preppedExport:
                    self.hide()
                case .exporting:
                    self.show()
                }
            }
        ]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "ExportEffectWindow")
    }
    
    private func initWindowAsHiddenOverlay() {
        let screenWithMenuBar = NSScreen.screens.first
        if let window = self.window, let screen = screenWithMenuBar {
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
            window.isOpaque = false
            window.collectionBehavior = .canJoinAllSpaces
            window.backgroundColor = NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 0.0)
            window.ignoresMouseEvents = true
            window.setFrame(screen.visibleFrame, display: true, animate: false)
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.opacity = 0
            window.setIsVisible(false)
        }
    }
    
    private func addIconLayer() {
        let screenWithMenuBar = NSScreen.screens.first
        if let layer = window?.contentView?.layer, let image = NSApp.applicationIconImage, let screen = screenWithMenuBar {
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            iconLayer.frame = CGRect(
                x: NSMidX(screen.frame) - (image.size.width/2),
                y: NSMidY(screen.frame) - (image.size.height/2),
                width: image.size.width,
                height: image.size.height)
            iconLayer.contents = cgImage
            layer.addSublayer(iconLayer)
        }
    }
    
    // MARK: - Animation
    let timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 1.4, 1, 1)
    
    func startAnimation() {
        fade((window?.contentView?.layer)!, to: 1)
        linesAnimationTimer = Timer.scheduledTimer(
            timeInterval: self.linesAnimationInterval,
            target: self,
            selector: #selector(animateLinesBurst),
            userInfo: nil,
            repeats: true)
    }
    
    func stopAnimation(completion: (()->Void)? = nil) {
        linesAnimationTimer?.invalidate()
        fade((window?.contentView?.layer)!, to: 0, within: 1.0, completion: completion)
    }

    private func fade(_ layer: CALayer, to opacity: Float, within duration: Double = 2.0, completion: (()->Void)? = nil) {
        //print("\(#function) \(layer) from \(layer.opacity) to \(opacity)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            NSAnimationContext.runAnimationGroup({(context) in
                context.allowsImplicitAnimation = true
                context.duration = duration
                context.timingFunction = self.timingFunction
                layer.opacity = opacity
            }, completionHandler: {
                completion?()
            })
        }
    }
    
    // MARK: Lines Animation
    let linesAnimationInterval = 0.3
    let linesAnimationBurst = 3
    var linesAnimationTimer: Timer?

    @objc private func animateLinesBurst() {
        for _ in 0..<linesAnimationBurst {
            randomlyAnimateLine()
        }
    }
    
    private func randomlyAnimateLine() {
        guard let layer = window?.contentView?.layer else {
            return
        }
        
        let sub = CALayer()

        let randomSecondDelay: Double = Double(arc4random_uniform(99) + 1) / 100
        let randomSecondDuration: Double = Double(arc4random_uniform(99) + 1) / 100
        let randomOpacity: Float = Float(arc4random_uniform(99) + 1) / 100
        let direction = arc4random_uniform(2) == 0
        let horizontal = true
        var startPositionX: CGFloat = 0.0
        var startPositionY: CGFloat = 0.0
        var translationX: CGFloat = 0.0
        var translationY: CGFloat = 0.0
        var height = layer.frame.height
        var width = layer.frame.width
        
        if horizontal {
            height = layer.frame.height / 100 * CGFloat(arc4random_uniform(99) + 1)
            startPositionY = direction ? -height : layer.frame.height + height  // start offscreen
            translationY = direction ? layer.frame.height + height : -height  // end offscreen
        } else {
            width = layer.frame.width / 100 * CGFloat(arc4random_uniform(99) + 1)
            startPositionX = direction ? -width : layer.frame.width + height  // start offscreen
            translationX = direction ? layer.frame.width + width : 0 - layer.frame.width - height  // end offscreen
        }
        
        
        

        sub.backgroundColor = NSColor(
            red: CGFloat(randomSecondDelay),
            green: CGFloat(randomOpacity),
            blue: CGFloat(randomSecondDuration),
            alpha: CGFloat(randomSecondDelay)/3 ).cgColor

        sub.frame = CGRect(
            x: startPositionX,
            y: startPositionY,
            width: width,
            height: height)
        layer.insertSublayer(sub, below: iconLayer)
        
        // Allow animation to be choppy by setting low qos, it's oldskool anyways :P
        let queue = DispatchQueue(label:"exportAnimation", qos: .background)
        queue.asyncAfter(deadline: .now() + (randomSecondDelay)) {
            NSAnimationContext.runAnimationGroup({(context) in
                context.allowsImplicitAnimation = true
                context.duration = randomSecondDuration * (1+randomSecondDuration) + 0.4
                context.timingFunction = self.timingFunction

                let transform = CGAffineTransform(
                    translationX: translationX,
                    y: translationY)
                transform.scaledBy(x: CGFloat(randomSecondDuration), y: 0)
                sub.opacity = randomOpacity + 0.4
                sub.setAffineTransform(transform)
            }, completionHandler: {
                sub.removeFromSuperlayer()
            })
        }
    }
}

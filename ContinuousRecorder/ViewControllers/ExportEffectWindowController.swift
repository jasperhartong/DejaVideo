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
    
    // MARK: - Initialization
    private let iconLayer = CALayer()

    init() {
        // Use .windowNibName
        super.init(window:nil)
        initWindowAsHiddenOverlay()
        addIconLayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "ExportEffectWindow")
    }
    
    private func initWindowAsHiddenOverlay() {
        if let window = self.window, let screen = NSScreen.main {
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
        if let layer = window?.contentView?.layer, let image = NSApp.applicationIconImage, let screen = NSScreen.main {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            NSAnimationContext.runAnimationGroup({(context) in
                context.allowsImplicitAnimation = true
                context.duration = duration
                context.timingFunction = self.timingFunction
                print("Fade \(layer) from \(layer.opacity) to \(opacity)")
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
        let randomWidth = layer.frame.width / 100 * CGFloat(arc4random_uniform(99) + 1)
        let randomSecondDelay: Double = Double(arc4random_uniform(99) + 1) / 100
        let randomSecondDuration: Double = Double(arc4random_uniform(99) + 1) / 100
        let randomOpacity: Float = Float(arc4random_uniform(99) + 1) / 100
        let forward = arc4random_uniform(2) == 0
        let startPositionX = forward ? -randomWidth : layer.frame.width + randomWidth  // start offscreen
        let translationX = forward ? layer.frame.width + sub.frame.width : 0 - layer.frame.width - randomWidth

        sub.backgroundColor = NSColor(
            red: CGFloat(randomSecondDelay),
            green: CGFloat(randomOpacity),
            blue: CGFloat(randomSecondDuration),
            alpha: CGFloat(randomSecondDelay)/3 ).cgColor

        sub.frame = CGRect(
            x: startPositionX,
            y: 0,
            width: randomWidth,
            height: layer.frame.height)
        layer.insertSublayer(sub, below: iconLayer)

        DispatchQueue.main.asyncAfter(deadline: .now() + (randomSecondDelay)) {
            NSAnimationContext.runAnimationGroup({(context) in
                context.allowsImplicitAnimation = true
                context.duration = randomSecondDuration * (1+randomSecondDuration) + 0.4
                context.timingFunction = self.timingFunction

                let transform = CGAffineTransform(
                    translationX: translationX,
                    y: 0)
                transform.scaledBy(x: CGFloat(randomSecondDuration), y: 0)
                sub.opacity = randomOpacity
                sub.setAffineTransform(transform)
            }, completionHandler: {
                sub.removeFromSuperlayer()
            })
        }
    }
}

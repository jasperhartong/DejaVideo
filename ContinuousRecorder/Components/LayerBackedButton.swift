//
//  RecordingButton.swift
//  LayerBackedButton
//
//  Created by Jasper Hartong on 04/09/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Foundation
import AppKit
/**
 * LayerBackedButton are rounded animatable buttons used throughout the interface
 * Customization is allowed for the:
 * - backgroundColor
 * - textColor
 * - textColorSelected
 *
 * Animatable methods:
 * - hide
 * - show
*/

@IBDesignable
class LayerBackedButton: NSButton {
    private var cornerRadius: CGFloat {
        return bounds.height / 2
    }
    
    // MARK: Outlets
    @IBInspectable
    var backgroundColor: NSColor = NSColor.controlColor { didSet { updateLayer() } }
    
    @IBInspectable
    var textColor: NSColor = NSColor.white { didSet { updateLayer() } }
    
    @IBInspectable
    var textColorSelected: NSColor = NSColor.selectedTextColor { didSet { updateLayer() } }
    
    // MARK: Layer setup
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // Ensure this view is layer backed (sets .layer)
        self.wantsLayer = true
        // Ensure the layer is redrawn only when needed
        self.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
        // Ensure that our parentView also is a layer backed view so we can cross our bounds
        self.superview?.wantsLayer = true
        updateLayer()
    }

    /// avoids clipping the view
    override var wantsDefaultClipping:Bool{return false}
    
    override func updateLayer() {
        if let layer = self.layer {
            // Ensure animations can happen outside own mas
            layer.masksToBounds = false

            // Ensure that the layer animations are done from the center
            // Requires manually synchronizing that layer and view position
            layer.anchorPoint = CGPoint(x:0.5, y:0.5)
            layer.position = NSPoint(x: self.frame.minX + (bounds.width/2) , y: self.frame.minY  + (bounds.height/2))
            
            // Set Outlet controlled layer attributes
            layer.cornerRadius = cornerRadius
            layer.backgroundColor = backgroundColor.cgColor
        }

        // Set outlet controlled non-layer attributes
        let color = isHighlighted ? textColorSelected : textColor
        
        if let mutableAttributedTitle = attributedTitle.mutableCopy() as? NSMutableAttributedString {
            // Copies over title attributes to only change what we desire
            mutableAttributedTitle.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: mutableAttributedTitle.length))
            attributedTitle = mutableAttributedTitle
        }

        super.updateLayer()
    }
    
    
    /// Private method to animate scaling the Button
    ///
    /// - Parameters:
    ///   - theScale: towards where to scale to
    ///   - duration: how long the animation should take
    ///   - completion: callback fired on animation end
    ///   - timingFunction: the animation timing function
    private func scale (to theScale: CGFloat,
                        within duration: Double,
                        completion: (()->Void)? = nil,
                        timingFunction: CAMediaTimingFunction? = CAMediaTimingFunction(controlPoints: 0.5, 1.4, 1, 1))
    {
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.allowsImplicitAnimation = true
            NSAnimationContext.current.duration = duration
            NSAnimationContext.current.timingFunction = timingFunction
            let transform = CGAffineTransform(scaleX: theScale, y: theScale)
            self.layer?.setAffineTransform(transform)
        }, completionHandler: {
            completion?()
        })
    }
    

    // MARK: Mouse tracking
    /// Allows us to hook into trackin events like mouseEntered and mouseExited
    override func updateTrackingAreas() {
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    // Scale for hover feedback
    override func mouseEntered(with theEvent: NSEvent) { scale(to: 1.07, within: 0.2) }
    override func mouseExited(with theEvent: NSEvent) { scale(to: 1.0, within: 0.3) }
    

    // MARK: Animated public methods
    func show(animated: Bool = false) {
        if (!isHidden) {
            return
        }
        if animated {
            scale(to: 0.0, within:0.0, completion: {() -> Void in
                self.isHidden = false
                // animate in without growing too much in the timing function
                self.scale(to: 1.0, within: 0.3, timingFunction: CAMediaTimingFunction(controlPoints: 0.5, 1.3, 1, 1))
            })
        } else {
            self.isHidden = false
        }
    }
    func hide(animated: Bool = false) {
        if (isHidden) {
            return
        }
        if animated {
            scale(to: 1.0, within:0.0, completion: {() -> Void in
                self.scale(to: 0.0, within:0.3, completion: {() -> Void in
                    self.isHidden = true
                })
            })
        } else {
            self.isHidden = true
        }
    }
}

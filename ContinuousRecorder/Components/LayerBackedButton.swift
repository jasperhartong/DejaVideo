//
//  RecordingButton.swift
//  LayerBackedButton
//
//  Created by Jasper Hartong on 04/09/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Foundation
import AppKit

@IBDesignable
class LayerBackedButton: NSButton {
    
    @IBInspectable
    var backgroundColor: NSColor = NSColor.controlColor { didSet { updateLayer() } }
    
    @IBInspectable
    var textColor: NSColor = NSColor.white { didSet { updateLayer() } }
    
    @IBInspectable
    var textColorSelected: NSColor = NSColor.selectedTextColor { didSet { updateLayer() } }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
        // Ensure that our parentView also is a layer backed view so we can cross our bounds
        self.superview?.wantsLayer = true
        updateLayer()
    }
    
    override var wantsDefaultClipping:Bool{return false}//avoids clipping the view
    
    override func updateTrackingAreas() {
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    private func scale (to theScale: CGFloat, within duration: Double) {
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.allowsImplicitAnimation = true
            NSAnimationContext.current.duration = duration
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 1.8, 1, 1)
            let transform = CGAffineTransform(scaleX: theScale, y: theScale)
            self.layer?.setAffineTransform(transform)
        }, completionHandler: {
//            print("done 1")
        })
    }
    
    override func mouseEntered(with theEvent: NSEvent) {
        scale(to: 1.07, within:0.2)
    }
    
    override func mouseExited(with theEvent: NSEvent) {
        scale(to: 1.0, within:0.3)
    }
    
    private var didTranslate = false
    override func updateLayer() {

        if let layer = self.layer {
            layer.masksToBounds = false
            // Ensure that the layer animations are done from the center
            // Requires manually synchronizing that layer and view position
            layer.anchorPoint = CGPoint(x:0.5, y:0.5)
            layer.position = NSPoint(x: self.frame.minX + (bounds.width/2) , y: self.frame.minY  + (bounds.height/2))

            layer.cornerRadius = cornerRadius
            layer.backgroundColor = backgroundColor.cgColor
        }
        updateTitleAttributes()
        super.updateLayer()
    }
    
    private var cornerRadius: CGFloat {
        return bounds.height / 2
    }
    
    private func updateTitleAttributes() {
        let color = isHighlighted ? textColorSelected : textColor

        // Copies over title attributes to only change what we desire
        if let mutableAttributedTitle = attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: mutableAttributedTitle.length))
            attributedTitle = mutableAttributedTitle
        }
    }
}

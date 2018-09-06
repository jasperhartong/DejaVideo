//
//  RecordingButton.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 04/09/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Foundation
import AppKit

@IBDesignable
class RecordingButton: NSButton {
    
    @IBInspectable
    var cornerRadius: CGFloat = 0.0 { didSet { updateLayer() } }
    
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
        // self.translatesAutoresizingMaskIntoConstraints = false
        updateLayer()
    }
    
    override var wantsUpdateLayer:Bool{
        return true
    }
    
    override func updateLayer() {
        if let layer = self.layer {
            layer.frame = bounds
            layer.mask = layerMask()
            layer.cornerRadius = cornerRadius
            layer.backgroundColor = backgroundColor.cgColor
        }
        updateTitleAttributes()
        super.updateLayer()
    }
    
    private func layerMask() -> CAShapeLayer {
        let mask = CAShapeLayer()
        mask.path = CGPath(roundedRect: self.bounds,
                           cornerWidth: (layer?.cornerRadius)!,
                           cornerHeight: (layer?.cornerRadius)!,
                           transform: nil)
        return mask
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

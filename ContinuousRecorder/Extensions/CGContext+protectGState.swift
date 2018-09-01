//
//  CGContext+ protectGState.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 01/09/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import CoreGraphics

extension CGContext{
    func protectGState(_ drawStuff: () -> Void) {
        saveGState()
        drawStuff()
        restoreGState()
    }
}

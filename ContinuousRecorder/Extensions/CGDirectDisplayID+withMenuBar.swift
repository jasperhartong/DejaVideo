//
//  CGDirectDisplayID+withMenuBar.swift
//  DejaVideo
//
//  Created by Jasper Hartong on 21/10/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import CoreGraphics

extension CGDirectDisplayID {
    static var withMenuBar: CGDirectDisplayID? {
        // First in list is the screen with the menuBar
        let activeDisplay = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: 1)
        CGGetActiveDisplayList(1, activeDisplay, nil)
        if let id = Array(UnsafeBufferPointer(start: activeDisplay, count: 1)).first {
            return id
        }
        return nil
    }
}

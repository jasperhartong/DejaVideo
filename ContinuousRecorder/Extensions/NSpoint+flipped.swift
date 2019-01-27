//
//  NSpoint+flipped.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 01/09/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

import Foundation

extension NSPoint{
    func flipped(totalX: CGFloat = 0, totalY: CGFloat = 0) -> NSPoint {
        // flips x in relation to total if total is set to non-0
        return NSPoint(
            x: (totalX != 0 ? totalX - x : x),
            y: (totalY != 0 ? totalY - y : y))
    }
    func flipped(totalX: Int = 0, totalY: Int = 0) -> NSPoint {
        return flipped(totalX: CGFloat(totalX), totalY: CGFloat(totalY))
        
    }
}

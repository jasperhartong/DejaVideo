//
//  VidWriter.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 29/08/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

/**
 USAGE:
 
     let settings = VidWriter.videoSettings(width: cgImg.width, height: cgImg.height)
 
     // Note: There should be no file at the targetUrl or nothing will be written.
     self.vidWriter = VidWriter(url: targetUrl!, vidSettings: settings)
     self.vidWriter.applyTimeWith(duration: durationPerFrame, frameNumber: images.count)
 
     self.vidWriter.createMovieFrom(images: images, completion: { (finalUrl) in
        print("Completed")
     })

 */

import AVFoundation
import AppKit

class VidWriter {
    
    var assetWriter: AVAssetWriter
    var writerInput: AVAssetWriterInput
    var bufferAdapter: AVAssetWriterInputPixelBufferAdaptor!
    var videoSettings: [String : Any]
    var frameTime: CMTime!
    var fileUrl: URL!
    
    init(url: URL, vidSettings: [String : Any]) {
        self.assetWriter = try! AVAssetWriter(url: url, fileType: AVFileType.mov)
        self.fileUrl = url
        self.videoSettings = vidSettings
        self.writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: self.videoSettings)
        
        assert(self.assetWriter.canAdd(self.writerInput), "Writer cannot add input")
        
        self.assetWriter.add(self.writerInput)
        
        let bufferAttributes = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB)]
        self.bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.writerInput, sourcePixelBufferAttributes: bufferAttributes)
        self.frameTime = CMTimeMake(1, 5) // Default value, use 'applyTimeWith(duration:)' to apply specific time.
    }
    
    static func videoSettings(codec: AVVideoCodecType, width: Int, height: Int) -> [String : Any] {
        return [
            AVVideoCodecKey : codec,
            AVVideoWidthKey : width,
            AVVideoHeightKey : height
        ]
    }
    
    /**
     Update the movie time with the number of images and the duration per image.
     
     - Parameter duration: The duration per frame (image)
     - Parameter frameNumber: The number of frames (images)
     */
    func applyTimeWith(duration: Float, frameNumber: Int) {
        
        let scale = Float(frameNumber) / (Float(frameNumber) * duration)
        
        self.frameTime = CMTimeMake(1, Int32(scale))
    }
    
    func createMovieFrom(fragments: [RecordingFragment], completion: @escaping (URL) -> Void) {
        
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: kCMTimeZero)
        
        let mediaInputQueue = DispatchQueue(label: "mediaInputQueue")
        
        var i = 0
        let frameNumber = fragments.count
        
        self.writerInput.requestMediaDataWhenReady(on: mediaInputQueue) {
            
            while i < frameNumber {
                if self.writerInput.isReadyForMoreMediaData {
                    
                    var sampleBuffer: CVPixelBuffer?
                    
                    autoreleasepool(invoking: {
                        if let image = fragments[i].image, let point = fragments[i].mousePoint {
                            var prevPoints: [CGPoint] = []
                            switch i {
                            case 0:
                                break
                            case 1:
                                if let point1 = fragments[i-1].mousePoint {
                                    prevPoints = [point1]
                                }
                            default:
                                if let point1 = fragments[i-1].mousePoint, let point2 = fragments[i-2].mousePoint {
                                    prevPoints = [point2, point1]
                                }
                            }
                            sampleBuffer = self.newOverlayedPixelBufferFrom(cgImage:image, point:point, prevPoints: prevPoints)
                            
                        }
                    }) // End of autoreleasepool
                    
                    if sampleBuffer != nil {
                        if i == 0 {
                            self.bufferAdapter.append(sampleBuffer!, withPresentationTime: kCMTimeZero)
                        }
                        else {
                            let value = i - 1
                            let lastTime = CMTimeMake(Int64(value), self.frameTime.timescale)
                            let presentTime = CMTimeAdd(lastTime, self.frameTime)
                            
                            self.bufferAdapter.append(sampleBuffer!, withPresentationTime: presentTime)
                            
                        }
                        
                        i += 1
                    }
                    
                } // End of isReadyForMoreMediaData
                
            } // End of while loop
            
            self.writerInput.markAsFinished()
            self.assetWriter.finishWriting {
                DispatchQueue.main.async {
                    // At this point, the given URL will already have the ready file.
                    // You can just use the URL passed in the init.
                    completion(self.fileUrl)
                }
            }
        }
    }
    
    private let circleFill =    CGColor(red: 1.0, green: 0.0, blue: 0.5, alpha: 1.0)
    private let circleStroke =  CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
    private let lineStroke =    CGColor(red: 1.0, green: 0.0, blue: 0.5, alpha: 0.6)

    func newOverlayedPixelBufferFrom(cgImage: CGImage, point: NSPoint, prevPoints: [NSPoint]) -> CVPixelBuffer? {
        // Setup pxData based on a CVPixelBuffer
        var pxbuffer: CVPixelBuffer?

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let frameWidth = self.videoSettings[AVVideoWidthKey] as! Int
        let frameHeight = self.videoSettings[AVVideoHeightKey] as! Int
        let options: [String : Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String : true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String : true
        ]
        
        let coreVideostatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            frameWidth,
            frameHeight,
            kCVPixelFormatType_32ARGB,
            options as CFDictionary?,
            &pxbuffer)
        
        guard coreVideostatus == kCVReturnSuccess && pxbuffer != nil else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pxData = CVPixelBufferGetBaseAddress(pxbuffer!)

        // Create context and add image and mousepointer
        let context = CGContext(
            data: pxData,
            width: frameWidth,
            height: frameHeight,
            bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: CVPixelBufferGetBytesPerRow(pxbuffer!),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        let bounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let flippedPoint = point.flipped(totalY: cgImage.height)
        let pointerCircleRadius: CGFloat = 6.0
        let pointerCircle = CGRect(
            x: flippedPoint.x-pointerCircleRadius,
            y: flippedPoint.y-pointerCircleRadius,
            width: pointerCircleRadius*2,
            height: pointerCircleRadius*2)
        
        if let context = context {
            context.protectGState {
                // add image: Most heavy method based on profiling
                context.draw(cgImage, in: bounds)
                // add circle
                context.setFillColor(circleFill)
                context.fillEllipse(in: pointerCircle)
                // add circle stroke
                context.setStrokeColor(circleStroke)
                context.setLineWidth(3.0)
                context.strokeEllipse(in: pointerCircle)
                // add line
                if !prevPoints.isEmpty {
                    var flippedPrevPoints = prevPoints.map {$0.flipped(totalY: cgImage.height)}
                    flippedPrevPoints.append(flippedPoint)
                    let path = CGMutablePath()
                    path.move(to: flippedPrevPoints.first!)
                    context.setStrokeColor(lineStroke)
                    context.setLineCap(.round)
                    context.setLineDash(phase: 0, lengths: [3.0, 12.0])
                    path.addLines(between: flippedPrevPoints)
                    context.addPath(path)
                    context.strokePath()
                }
                
            }
        }
        
        // Wrap up pxbuffer
        CVPixelBufferUnlockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pxbuffer
    }
}

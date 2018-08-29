//
//  VidWriter.swift
//  ContinuousRecorder
//
//  Created by Jasper Hartong on 29/08/2018.
//  Copyright © 2018 Jasper Hartong. All rights reserved.
//

/// USAGE

//    let settings = VidWriter.videoSettings(width: cgImg.width, height: cgImg.height)
//
//    // Note: There should be no file at the targetUrl or nothing will be written.
//    self.vidWriter = VidWriter(url: targetUrl!, vidSettings: settings)
//    self.vidWriter.applyTimeWith(duration: durationPerFrame, frameNumber: images.count)
//
//    self.vidWriter.createMovieFrom(images: images, completion: { (finalUrl) in
//        print("Completed")
//    })


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
    
    func createMovieFrom(images: [CGImage], completion: @escaping (URL) -> Void) {
        
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: kCMTimeZero)
        
        let mediaInputQueue = DispatchQueue(label: "MediaInputQueu")
        
        var i = 0
        let frameNumber = images.count
        
        self.writerInput.requestMediaDataWhenReady(on: mediaInputQueue) {
            
            while i < frameNumber {
                if self.writerInput.isReadyForMoreMediaData {
                    
                    var sampleBuffer: CVPixelBuffer?
                    
                    autoreleasepool(invoking: {
                        
                        sampleBuffer = self.newPixelBufferFrom(cgImage: images[i])
                        
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
    
    func newPixelBufferFrom(cgImage: CGImage) -> CVPixelBuffer? {
        
        let options: [String : Any] = [kCVPixelBufferCGImageCompatibilityKey as String : true, kCVPixelBufferCGBitmapContextCompatibilityKey as String : true]
        
        var pxbuffer: CVPixelBuffer?
        
        let frameWidth = self.videoSettings[AVVideoWidthKey] as! Int
        let frameHeight = self.videoSettings[AVVideoHeightKey] as! Int
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, frameWidth, frameHeight, kCVPixelFormatType_32ARGB, options as CFDictionary?, &pxbuffer)
        
        assert(status == kCVReturnSuccess && pxbuffer != nil, "newPixelBuffer failed")
        CVPixelBufferLockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pxData = CVPixelBufferGetBaseAddress(pxbuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pxData, width: frameWidth, height: frameHeight, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pxbuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        assert(context != nil, "context is nil")
        
        context!.concatenate(CGAffineTransform.identity)
        context!.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pxbuffer
    }
}

//
//  BinarizedImg.swift
//  SignatureSelfiePOC
//
//  Created by Rutuja on 18/07/25.
//

import UIKit
import Accelerate

extension UIImage {
    
    func binarizedClean(threshold: Float? = nil) -> UIImage? {
        
        var actualThreshold: Float
        
        if let userThreshold = threshold {
            actualThreshold = userThreshold
        } else {
            actualThreshold = autoThreshold(for: self)// call helper function
        }
        
        guard let ciImage = CIImage(image: self) else { return nil }
        
        /// Convert to grayscale
        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.1
        ])
        
        // Custom threshold filter using CIColorKernel
        let thresholdKernel = CIColorKernel(source:
                                                "kernel vec4 thresholdFilter(__sample image, float threshold) {" +
                                            "float luma = dot(image.rgb, vec3(0.299, 0.587, 0.114));" +
                                            "return (luma < threshold) ? vec4(0.0, 0.0, 0.0, 1.0) : vec4(1.0, 1.0, 1.0, 1.0);" +
                                            "}"
        )
        
        guard let outputImage = thresholdKernel?.apply(extent: grayscale.extent, arguments: [grayscale, actualThreshold]) else {
            return nil
        }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }


    private func autoThreshold(for image: UIImage) -> Float {
        guard let ciImage = CIImage(image: image) else { return 0.5 }

        let extent = ciImage.extent
        let context = CIContext(options: nil)

        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0
        ])

        guard let cgImage = context.createCGImage(grayscale, from: extent) else {
            return 0.5
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 1
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = height * bytesPerRow

        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context2 = CGContext(data: &pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: 0)!

        context2.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let sum = pixelData.reduce(0, { $0 + Int($1) })
        let mean = Float(sum) / Float(totalBytes)

        let variance = pixelData.reduce(0, { $0 + powf(Float($1) - mean, 2.0) }) / Float(totalBytes)
        let stdDev = sqrt(variance)
        
        switch true {
        case stdDev > 30:
            return -0.01 /// real-world photo with background
        case mean > 180:
            return 0.6   /// bright paper scan
        case mean < 100:
            return 0.3   /// dark lighting on paper
        default:
            return 0.5   /// average fallback
        }
//        return stdDev > 30 ? -0.027 : 0.5
    }
    
    func toBase64(thresholded: Bool = false) -> String? {
            let processed = thresholded ? binarizedClean() : self
            return processed?.jpegData(compressionQuality: 1.0)?.base64EncodedString()
        }
}

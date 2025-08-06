//
//  BlinkDetector.swift
//  SignatureSelfiePOC
//
//  Created by Rutuja on 16/07/25.
//

import Vision

class BlinkDetector {

    private var blinkInProgress = false
    
    private var lastBlinkTime: Date?
    
    private let blinkCooldownSeconds: TimeInterval = 1.5
    
    private let eyeClosedRatioThreshold: CGFloat = 0.18  // more sensitive

    func checkBlinkAndReadyToCapture(face: VNFaceObservation) -> Bool {
        guard let landmarks = face.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return false
        }

        let leftRatio = eyeClosedRatio(for: leftEye.normalizedPoints)
        let rightRatio = eyeClosedRatio(for: rightEye.normalizedPoints)

        let leftClosed = leftRatio < eyeClosedRatioThreshold
        let rightClosed = rightRatio < eyeClosedRatioThreshold

        print("👁 Eye ratio (L): \(leftRatio), (R): \(rightRatio)")
        print("👁 Left closed: \(leftClosed), Right closed: \(rightClosed), BlinkInProgress: \(blinkInProgress)")

        // Blink starts with either eye
        if (leftClosed || rightClosed) && !blinkInProgress {
            blinkInProgress = true
            return false
        }

        // Blink ends when both eyes open again
        if blinkInProgress && !leftClosed && !rightClosed {
            blinkInProgress = false

            let now = Date()
            if let last = lastBlinkTime, now.timeIntervalSince(last) < blinkCooldownSeconds {
                return false
            }

            lastBlinkTime = now
            return true
        }

        return false
    }

    private func eyeClosedRatio(for points: [CGPoint]) -> CGFloat {
        guard points.count >= 6 else { return 1.0 }

        let top = (points[1].y + points[2].y) / 2
        let bottom = (points[4].y + points[5].y) / 2
        let vertical = abs(top - bottom)
        let horizontal = abs(points[0].x - points[3].x)
        return vertical / horizontal
    }
}

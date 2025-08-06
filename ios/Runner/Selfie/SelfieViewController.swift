//
//  SelfieViewController.swift
//  SignatureSelfiePOC
//
//  Created by Rutuja on 16/07/25.
//

import UIKit
import Vision
import AVKit
import CoreMotion

class SelfieViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    let captureSession = AVCaptureSession()
    
    var faceLandMarks:[VNFaceLandmarkRegion2D] = []
    
    var lastBlinkTime: Date?
    
    let blinkCooldown: TimeInterval = 2.0
    
    let blinkThreshold: CGFloat = 0.18 // Adjust this threshold based on testing
    
    let motionManager = CMMotionManager()
        
    private var lastPixelBuffer: CVPixelBuffer?
    
    var cameraView = UIView()
    
    var isRetakeInProgress = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        cameraView.frame = view.bounds
        view.addSubview(cameraView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
        previewLayer?.removeFromSuperlayer()
        cameraView.subviews.forEach { $0.removeFromSuperview() }
        cameraView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // Delay for smoother reset
            self.resetStateAfterRetake()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !motionManager.isAccelerometerActive {
            startMonitoringMotion()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
        motionManager.stopAccelerometerUpdates()
        if self.isMovingFromParent {
            // Back button tapped
            CaptureManager.shared.sendErrorToFlutter(
                code: "USER_CANCELLED",
                message: "User cancelled selfie capture"
            )
        }
        if navigationController?.viewControllers.first is FlutterViewController {
            navigationController?.setNavigationBarHidden(true, animated: false)
        }
    }
    
    func startMonitoringMotion() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { _, _ in }
    }
    
    func resetStateAfterRetake() {
        print("Resetting state after retake")
        // Cleanup old session fully
        captureSession.stopRunning()
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }
        
        // Remove preview and dot overlays
        previewLayer?.removeFromSuperlayer()
        
        lastBlinkTime = nil
        isRetakeInProgress = false
        
        // Add slight delay to allow full cleanup before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setupCapture()
            // Start session on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func setupCapture() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           captureSession.inputs.isEmpty {
            captureSession.addInput(input)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        captureSession.addOutput(output)
        
        //Add this after output is added
        if let connection = output.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.isVideoMirrored = true // Mirror only once
        }
        
        captureSession.commitConfiguration()
        previewLayer?.removeFromSuperlayer()
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = cameraView.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let layer = previewLayer {
            cameraView.layer.addSublayer(layer)
        }
    }
    
    func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 1. Apply orientation + mirroring
        let orientedImage = ciImage
            .oriented(forExifOrientation: 9)  // 9 = rotate right (landscape camera)
            .transformed(by: CGAffineTransform(scaleX: -1, y: 1))  // mirror horizontally
        
        // 2. Render to CGImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(orientedImage, from: orientedImage.extent) else {
            return UIImage()
        }
        
        // 3. Wrap as UIImage
        return UIImage(cgImage: cgImage)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastPixelBuffer = buffer
        
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .leftMirrored)
        let request = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let self = self, let results = request.results as? [VNFaceObservation] else { return }
            DispatchQueue.main.async {
                self.processLandmarks(faces: results)
            }
        }
        try? handler.perform([request])
    }
    
    func processLandmarks(faces: [VNFaceObservation]) {
        cameraView.subviews.forEach { $0.removeFromSuperview() }
        
        guard let face = faces.first else { return }
        
        guard let leftEye = face.landmarks?.leftEye, let rightEye = face.landmarks?.rightEye, leftEye.pointCount >= 6, rightEye.pointCount >= 6 else { return }
        
        for eye in [leftEye, rightEye] {
            for point in eye.normalizedPoints {
                // Convert to full image normalized coordinates
                let x = face.boundingBox.origin.x + point.x * face.boundingBox.size.width
                let y = face.boundingBox.origin.y + point.y * face.boundingBox.size.height
                
                // Flip Y-axis (Vision vs UIKit)
                let flippedY = 1 - y
                
                // Convert to screen coordinates
                let screenPoint = previewLayer!.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: x, y: flippedY))
                
                // Draw dot
                let dot = UIView(frame: CGRect(x: screenPoint.x - 1.5, y: screenPoint.y - 1.5, width: 3, height: 3))
                dot.backgroundColor = .white
                dot.layer.cornerRadius = 1.5
                cameraView.addSubview(dot)
            }
        }
        
        let leftEAR = computeEAR(for: leftEye)
        let rightEAR = computeEAR(for: rightEye)
        let avgEAR = (leftEAR + rightEAR) / 2.0
        
        print("********** Blinked threshold is: \(blinkThreshold) and average EAR is: \(avgEAR) ************")
        
        if avgEAR < blinkThreshold && !isRetakeInProgress {
            print("Blinked — triggering selfie capture!") // Add this
            let now = Date()
            if let last = lastBlinkTime, now.timeIntervalSince(last) < blinkCooldown {
                return
            }
            lastBlinkTime = now
            isRetakeInProgress = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let buffer = self.lastPixelBuffer else { return }
                let selfie = self.pixelBufferToUIImage(buffer)
                let previewVC = SelfiePreviewViewController(image: selfie)
                self.navigationController?.pushViewController(previewVC, animated: true)
            }
        }
    }
    
    func computeEAR(for eye: VNFaceLandmarkRegion2D) -> CGFloat {
        let p = eye.normalizedPoints
        let v1 = abs(p[1].y - p[5].y)
        let v2 = abs(p[2].y - p[4].y)
        let h = abs(p[0].x - p[3].x)
        return (v1 + v2) / (2.0 * h)
    }
    
    //buffer -> UIImage
    func convert(buffer:CVPixelBuffer) -> UIImage {
        let ciimage: CIImage = CIImage(cvPixelBuffer: buffer)
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(ciimage, from: ciimage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    //MARK: Direction
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait]
    }
}

extension UIView {
    func snapshotImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}


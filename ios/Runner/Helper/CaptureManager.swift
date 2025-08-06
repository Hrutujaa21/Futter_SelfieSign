//
//  CaptureManager.swift
//  SignatureSelfiePOC
//
//  Created by Rutuja on 04/08/25.
//

import Foundation
import UIKit
import VisionKit

enum CameraMode {
    case selfie, singleSignature, dualSignature
}

class CaptureManager: UIViewController {
    
    static let shared = CaptureManager()
    
    private init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var resultCallback: FlutterResult?
    
    private var currentSignatureMode: SignatureMode = .single
    
    var viewControllerToPresent: UIViewController?
    
    func startCapture(mode: CameraMode, flutterResult: @escaping FlutterResult) {
        guard let rootVC = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController as? UINavigationController else {
            flutterResult(FlutterError(code: "NO_NAV", message: "NavigationController not found", details: nil))
            return
        }
        
        resultCallback = flutterResult
        
        switch mode {
        case .selfie:
            let selfieVC = SelfieViewController()
            rootVC.pushViewController(selfieVC, animated: true)
            
        case .singleSignature:
            currentSignatureMode = .single
                   DispatchQueue.main.async {
                       self.presentDocumentScanner(from: rootVC)
                   }            
        case .dualSignature:
            currentSignatureMode = .dual
            DispatchQueue.main.async {
                self.presentDocumentScanner(from: rootVC)
            }
        }
    }
    
    private func presentDocumentScanner(from vc: UIViewController) {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = self
        scanner.modalPresentationStyle = .fullScreen
        vc.present(scanner, animated: true)
    }
    
    func returnResultToFlutter(result: Any?) {
        resultCallback?(result)
        resultCallback = nil
    }
    
    func returnErrorToFlutter(message: String) {
        resultCallback?(FlutterError(code: "CAMERA_ERROR", message: message, details: nil))
        resultCallback = nil
    }
    
    private func navigateToCrop(documentImage: UIImage) {
        DispatchQueue.main.async {
            let cropVC = SignatureCropVC(sourceImage: documentImage, mode: self.currentSignatureMode)
            cropVC.modalPresentationStyle = .fullScreen

            guard let topVC = CaptureManager.topMostViewController() else {
                return
            }

            if let nav = topVC.navigationController {
                nav.pushViewController(cropVC, animated: true)
            } else {
                topVC.present(cropVC, animated: true)
            }
        }
    }
    
    static func topMostViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController

        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

extension CaptureManager {
    func sendResultToFlutter(base64String: String) {
        resultCallback?(base64String)
        resultCallback = nil
    }
    
    func sendResultToFlutter(jsonDict: [String: String]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
            let jsonString = String(data: data, encoding: .utf8)
            resultCallback?(jsonString)
        } catch {
            resultCallback?(FlutterError(code: "json_error", message: "Failed to encode result", details: nil))
        }
        resultCallback = nil
    }
    
    func sendErrorToFlutter(code: String, message: String) {
        if let result = resultCallback {
            result(FlutterError(code: code, message: message, details: nil))
            resultCallback = nil
        }
    }
}

extension CaptureManager: VNDocumentCameraViewControllerDelegate {

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        guard scan.pageCount > 0 else {
            controller.dismiss(animated: true)
            return
        }
        
        let scannedImage = scan.imageOfPage(at: 0)
        
        // Get the presenter before dismiss
        guard let presentingVC = controller.presentingViewController else {
            controller.dismiss(animated: true)
            return
        }
        
        controller.dismiss(animated: true) {
            let cropVC = SignatureCropVC(sourceImage: scannedImage, mode: self.currentSignatureMode)
                   cropVC.modalPresentationStyle = .fullScreen
                   presentingVC.present(cropVC, animated: true)
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) {
            CaptureManager.shared.sendErrorToFlutter(
                code: "USER_CANCELLED",
                message: "User cancelled document scan"
            )
            self.navigationController?.popToRootViewController(animated: true)
        }
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print("Scan failed: \(error.localizedDescription)")
        controller.dismiss(animated: true) {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}


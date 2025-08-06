//
//  SignatureCropViewController.swift
//  SignatureSelfiePOC
//
//  Created by Rutuja on 17/07/25.
//

import UIKit
import TOCropViewController

enum SignatureMode {
    case single
    case dual
}

class SignatureCropVC: UIViewController {
    
    let sourceImage: UIImage
    
    let mode: SignatureMode
        
    private var firstSignatureImage: UIImage?
    
    private var didStartCropping = false
    
    let fixedWidth: CGFloat = 100
    
    let fixedHeight: CGFloat = 50
    
    private var didSetFixedCrop = false
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Processing Data..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    init(sourceImage: UIImage, mode: SignatureMode) {
        self.sourceImage = sourceImage
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        self.title = "Crop Signature"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
   
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupActivityIndicator()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !didStartCropping {
            didStartCropping = true
            startCropping(image: sourceImage)
        }
    }

    private func startCropping(image: UIImage) {
        let cropVC = TOCropViewController(croppingStyle: .default, image: image)
        cropVC.delegate = self
        present(cropVC, animated: true)
    }
    
    private func startSecondCrop() {
        let secondCropVC = TOCropViewController(croppingStyle: .default, image: sourceImage)
        secondCropVC.delegate = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.present(secondCropVC, animated: true)
        }
    }
    
    private func dismissToFlutterScreen() {
        if let nav = self.navigationController {
            nav.popToRootViewController(animated: true)
        } else {
            self.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    private func setupActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .systemGray
        view.addSubview(activityIndicator)
        view.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}

extension SignatureCropVC: TOCropViewControllerDelegate {
    
    func cropViewController(_ cropVC: TOCropViewController, didFinishCancelled cancelled: Bool) {
        cropVC.dismiss(animated: true) {
            let alert = UIAlertController(title: "Crop Cancelled",
                                          message: "Would you like to continue cropping?",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                self.startCropping(image: self.sourceImage)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.dismissToFlutterScreen()
            })
            self.present(alert, animated: true)
        }
    }
    
    func cropViewController(_ cropVC: TOCropViewController, didCropTo image: UIImage, with rect: CGRect, angle: Int) {
        cropVC.dismiss(animated: true) {
            // If it's dual mode and this is the first crop → store and trigger second crop
            if self.mode == .dual && self.firstSignatureImage == nil {
                self.firstSignatureImage = image
                self.startSecondCrop()
                return
            }
            self.activityIndicator.startAnimating()
            
            self.loadingLabel.isHidden = false
            
            DispatchQueue.global(qos: .userInitiated).async {
                guard let documentBase64 = self.sourceImage.toBase64(thresholded: true) else { return }
                
                let signature1Base64 = self.mode == .dual
                ? self.firstSignatureImage?.toBase64(thresholded: true)
                : image.toBase64(thresholded: true)
                
                let signature2Base64 = self.mode == .dual
                ? image.toBase64(thresholded: true)
                : nil
                
                let result: [String: String] = {
                    if self.mode == .single {
                        return [
                            "document": documentBase64,
                            "signature": signature1Base64 ?? ""
                        ]
                    } else {
                        return [
                            "document": documentBase64,
                            "signature1": signature1Base64 ?? "",
                            "signature2": signature2Base64 ?? ""
                        ]
                    }
                }()
                
                // Return result to Flutter on main thread
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.loadingLabel.isHidden = true
                    CaptureManager.shared.sendResultToFlutter(jsonDict: result)
                    self.dismissToFlutterScreen()
                }
            }
        }
    }
}

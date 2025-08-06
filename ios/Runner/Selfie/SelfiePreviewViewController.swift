//
//  SelfiePreviewViewController.swift
//  SignatureSelfiePOC
//
//  Created by Rutuja on 19/07/25.
//

import UIKit

class SelfiePreviewViewController: UIViewController {
    
    private let imageView = UIImageView()
    
    private let retakeButton = UIButton(type: .system)
    
    private let proceedButton = UIButton(type: .system)
    
    private let capturedImage: UIImage
    
    init(image: UIImage) {
        self.capturedImage = image
        super.init(nibName: nil, bundle: nil)
        self.title = "Preview Selfie"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        self.navigationItem.hidesBackButton = true
        setupUI()
    }

    private func setupUI() {
        imageView.image = capturedImage
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        retakeButton.setTitle("Retake", for: .normal)
        proceedButton.setTitle("Proceed", for: .normal)

        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        proceedButton.addTarget(self, action: #selector(proceedTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [retakeButton, proceedButton])
        stack.axis = .horizontal
        stack.spacing = 40
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(imageView)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 4/3),

            stack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 40),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.heightAnchor.constraint(equalToConstant: 44),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6)
        ])
    }

    @objc private func retakeTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func proceedTapped() {
        guard let jpegData = capturedImage.jpegData(compressionQuality: 0.8) else { return }
        let base64 = jpegData.base64EncodedString()
        DispatchQueue.main.async {
            // Send base64 back to Flutter
            CaptureManager.shared.sendResultToFlutter(base64String: base64)
        }
        self.navigationController?.popToRootViewController(animated: true)
    }
}


//
//  QRScannerView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
@preconcurrency import AVFoundation

/// Delegate protocol to handle QR scan results and errors.
protocol QRScannerDelegate: AnyObject {
    func didScan(code: String)
    func didFailWithError(error: Error)
}

/// SwiftUI view that integrates a QR code scanner using AVFoundation.
struct QRScannerView: UIViewControllerRepresentable {
    weak var delegate: QRScannerDelegate?

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = delegate
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.delegate = delegate
    }
}

/// ViewController for QR Scanner functionality.
class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let overlayView = UIView()
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermission()
        setupOverlay()
    }

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            // Permission already granted, setup camera
            setupCamera()

        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        let error = NSError(domain: "QRScanner", code: -4, userInfo: [NSLocalizedDescriptionKey: "Camera permission denied"])
                        self?.delegate?.didFailWithError(error: error)
                    }
                }
            }

        case .denied, .restricted:
            // Permission denied
            let error = NSError(domain: "QRScanner", code: -4, userInfo: [NSLocalizedDescriptionKey: "Camera permission denied. Please enable camera access in Settings."])
            delegate?.didFailWithError(error: error)

        @unknown default:
            let error = NSError(domain: "QRScanner", code: -5, userInfo: [NSLocalizedDescriptionKey: "Unknown camera permission status"])
            delegate?.didFailWithError(error: error)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        if let captureSession = captureSession, !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let captureSession = captureSession, captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        overlayView.frame = view.bounds
        updateOverlayMask()
    }
    
    private func updateOverlayMask() {
        let path = UIBezierPath(rect: overlayView.bounds)
        let scanAreaPath = UIBezierPath(roundedRect: CGRect(x: overlayView.bounds.midX - 125, y: overlayView.bounds.midY - 125, width: 250, height: 250), cornerRadius: 12)
        path.append(scanAreaPath)
        path.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()

        guard let captureSession = captureSession else { return }
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            let error = NSError(domain: "QRScanner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera not available"])
            delegate?.didFailWithError(error: error)
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFailWithError(error: error)
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            let error = NSError(domain: "QRScanner", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not add video input"])
            delegate?.didFailWithError(error: error)
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            let error = NSError(domain: "QRScanner", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not add metadata output"])
            delegate?.didFailWithError(error: error)
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill

        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }

    private func setupOverlay() {
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.addSubview(overlayView)

        let scanArea = UIView()
        scanArea.translatesAutoresizingMaskIntoConstraints = false
        scanArea.layer.borderColor = UIColor.white.cgColor
        scanArea.layer.borderWidth = 2
        scanArea.layer.cornerRadius = 12
        overlayView.addSubview(scanArea)

        NSLayoutConstraint.activate([
            scanArea.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            scanArea.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            scanArea.widthAnchor.constraint(equalToConstant: 250),
            scanArea.heightAnchor.constraint(equalToConstant: 250)
        ])

        updateOverlayMask()

        let label = UILabel()
        label.text = "Scan QR Code"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: scanArea.topAnchor, constant: -30)
        ])
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else { return }

        Task { @MainActor [weak self] in
            guard let self, !self.hasScanned else { return }
            self.hasScanned = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            self.delegate?.didScan(code: stringValue)
        }
    }
}

import AVFoundation
import SwiftUI
import UIKit

/// AVFoundation-backed barcode scanner for EAN/UPC food barcodes, wrapped for
/// SwiftUI. Camera permission is requested only when this view first appears —
/// i.e. only when the user actually opens the scanner.
struct BarcodeCameraView: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeCameraViewController {
        let controller = BarcodeCameraViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeCameraViewController, context: Context) {}
}

final class BarcodeCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDelivered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasDelivered = false
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning { session.stopRunning() }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasDelivered,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue, !value.isEmpty else {
            return
        }
        hasDelivered = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScan?(value)
    }
}

/// Observable camera-permission state for the scanner screen.
@MainActor
@Observable
final class CameraPermission {
    enum Status {
        case notDetermined
        case authorized
        case denied
    }

    var status: Status = .notDetermined

    init() {
        refresh()
    }

    func refresh() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: status = .authorized
        case .notDetermined: status = .notDetermined
        default: status = .denied
        }
    }

    func request() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        status = granted ? .authorized : .denied
    }
}

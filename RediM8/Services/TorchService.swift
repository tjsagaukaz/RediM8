import AVFoundation
import Foundation

@MainActor
final class TorchService: ObservableObject {
    @Published private(set) var isTorchOn = false

    func toggleTorch() {
        setTorch(on: !isTorchOn)
    }

    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            return
        }

        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            isTorchOn = on
        } catch {
            isTorchOn = false
        }
    }
}

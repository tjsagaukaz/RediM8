import AudioToolbox
import AVFoundation
import CoreLocation
import Foundation
import UIKit

enum AnalogSignalPattern: String, CaseIterable, Identifiable {
    case sos
    case help
    case stayAway
    case safe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sos:
            "SOS"
        case .help:
            "Help"
        case .stayAway:
            "Stay Away"
        case .safe:
            "Safe"
        }
    }

    var subtitle: String {
        switch self {
        case .sos:
            "Universal distress beacon"
        case .help:
            "Need assistance at this location"
        case .stayAway:
            "Unsafe area or immediate hazard"
        case .safe:
            "Safe here and conscious"
        }
    }

    var screenLines: [String] {
        switch self {
        case .sos:
            ["SOS"]
        case .help:
            ["HELP", "INJURED"]
        case .stayAway:
            ["STAY", "AWAY"]
        case .safe:
            ["SAFE", "HERE"]
        }
    }

    var flashSteps: [AnalogFlashStep] {
        switch self {
        case .sos:
            return [
                .on(0.18), .off(0.12), .on(0.18), .off(0.12), .on(0.18), .off(0.24),
                .on(0.52), .off(0.16), .on(0.52), .off(0.16), .on(0.52), .off(0.24),
                .on(0.18), .off(0.12), .on(0.18), .off(0.12), .on(0.18), .off(0.9)
            ]
        case .help:
            return [
                .on(0.26), .off(0.18), .on(0.26), .off(0.18), .on(0.26), .off(0.72)
            ]
        case .stayAway:
            return [
                .on(0.1), .off(0.1), .on(0.1), .off(0.1), .on(0.1), .off(0.1),
                .on(0.1), .off(0.45)
            ]
        case .safe:
            return [
                .on(0.42), .off(0.24), .on(0.42), .off(1.0)
            ]
        }
    }
}

enum AnalogSignalPulseInterval: String, CaseIterable, Identifiable {
    case off
    case fiveSeconds
    case thirtySeconds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            "Off"
        case .fiveSeconds:
            "5 sec"
        case .thirtySeconds:
            "30 sec"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .off:
            nil
        case .fiveSeconds:
            5
        case .thirtySeconds:
            30
        }
    }
}

struct AnalogRescueSnapshot: Equatable {
    struct ContactLine: Identifiable, Equatable {
        let id: UUID
        let name: String
        let phone: String
    }

    let ownerName: String
    let coordinatesText: String?
    let bloodType: String?
    let allergies: String?
    let medication: String?
    let conditionSummary: String?
    let contacts: [ContactLine]

    init(profile: UserProfile, fallbackOwnerName: String, location: CLLocation?) {
        let resolvedOwnerName = profile.familyMembers.first(where: \.isPrimaryUser)?.name.nilIfBlank
            ?? profile.familyMembers.first?.name.nilIfBlank
            ?? fallbackOwnerName.nilIfBlank
            ?? "RediM8 user"
        let medicalInfo = profile.emergencyMedicalInfo
        let filteredContacts = profile.emergencyContacts.compactMap { contact -> ContactLine? in
            guard let name = contact.name.nilIfBlank, let phone = contact.phone.nilIfBlank else {
                return nil
            }
            return ContactLine(id: contact.id, name: name, phone: phone)
        }

        ownerName = resolvedOwnerName
        coordinatesText = location.map {
            String(format: "%.4f, %.4f", $0.coordinate.latitude, $0.coordinate.longitude)
        }
        bloodType = medicalInfo.bloodType.nilIfBlank
        allergies = medicalInfo.severeAllergies.nilIfBlank
        medication = medicalInfo.emergencyMedication.nilIfBlank
        conditionSummary = medicalInfo.displayLines.first(where: { !$0.hasPrefix("Allergies:") && !$0.hasPrefix("Medication:") && !$0.hasPrefix("Blood type:") })
        contacts = filteredContacts
    }

    var hasAnyMedicalInfo: Bool {
        bloodType != nil || allergies != nil || medication != nil || conditionSummary != nil
    }
}

struct AnalogFlashStep: Equatable {
    let isOn: Bool
    let duration: TimeInterval

    static func on(_ duration: TimeInterval) -> AnalogFlashStep {
        AnalogFlashStep(isOn: true, duration: duration)
    }

    static func off(_ duration: TimeInterval) -> AnalogFlashStep {
        AnalogFlashStep(isOn: false, duration: duration)
    }
}

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

@MainActor
final class AnalogSignalService: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var lastErrorMessage: String?
    @Published var selectedPattern: AnalogSignalPattern = .sos {
        didSet {
            guard selectedPattern != oldValue else { return }
            restartTorchLoopIfNeeded()
        }
    }
    @Published var isTorchPatternEnabled = true {
        didSet {
            guard isTorchPatternEnabled != oldValue else { return }
            restartTorchLoopIfNeeded()
        }
    }
    @Published var isAudiblePingEnabled = false {
        didSet {
            guard isAudiblePingEnabled != oldValue else { return }
            restartPulseLoopIfNeeded()
        }
    }
    @Published var isVibrationPingEnabled = true {
        didSet {
            guard isVibrationPingEnabled != oldValue else { return }
            restartPulseLoopIfNeeded()
        }
    }
    @Published var pulseInterval: AnalogSignalPulseInterval = .thirtySeconds {
        didSet {
            guard pulseInterval != oldValue else { return }
            restartPulseLoopIfNeeded()
        }
    }

    let isTorchAvailable: Bool

    private let torchService: TorchService
    private var torchLoopTask: Task<Void, Never>?
    private var pulseLoopTask: Task<Void, Never>?
    private var beepPlayer: AVAudioPlayer?
    private var storedScreenBrightness: CGFloat?
    private var storedIdleTimerDisabled: Bool?

    init(torchService: TorchService) {
        self.torchService = torchService
        isTorchAvailable = AVCaptureDevice.default(for: .video)?.hasTorch == true
    }

    func activate() {
        guard !isActive else {
            restartTorchLoopIfNeeded()
            restartPulseLoopIfNeeded()
            return
        }

        isActive = true
        lastErrorMessage = nil
        activateEmergencyPresentation()
        restartTorchLoopIfNeeded()
        restartPulseLoopIfNeeded()
    }

    func deactivate() {
        torchLoopTask?.cancel()
        torchLoopTask = nil
        pulseLoopTask?.cancel()
        pulseLoopTask = nil
        torchService.setTorch(on: false)
        deactivateAudioSession()
        deactivateEmergencyPresentation()
        isActive = false
    }

    func triggerManualPing() {
        Task { [weak self] in
            await self?.runPulseBurst()
        }
    }

    private func restartTorchLoopIfNeeded() {
        torchLoopTask?.cancel()
        torchLoopTask = nil
        torchService.setTorch(on: false)

        guard isActive, isTorchPatternEnabled else {
            return
        }

        guard isTorchAvailable else {
            lastErrorMessage = "Flashlight is unavailable on this device."
            return
        }

        let flashSteps = selectedPattern.flashSteps
        torchLoopTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                for step in flashSteps {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        self.torchService.setTorch(on: step.isOn)
                    }
                    try? await Task.sleep(nanoseconds: UInt64(step.duration * 1_000_000_000))
                }
            }

            await MainActor.run {
                self.torchService.setTorch(on: false)
            }
        }
    }

    private func restartPulseLoopIfNeeded() {
        pulseLoopTask?.cancel()
        pulseLoopTask = nil

        guard isActive,
              let interval = pulseInterval.seconds,
              (isAudiblePingEnabled || isVibrationPingEnabled) else {
            if !isAudiblePingEnabled {
                deactivateAudioSession()
            }
            return
        }

        pulseLoopTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self.runPulseBurst()
            }
        }
    }

    private func runPulseBurst() async {
        guard isActive else { return }

        if isVibrationPingEnabled {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }

        guard isAudiblePingEnabled else { return }
        guard prepareAudioPlayerIfNeeded() else { return }

        for index in 0..<3 {
            guard isActive, isAudiblePingEnabled else { break }
            playBeep()
            if index < 2 {
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
        }
    }

    private func prepareAudioPlayerIfNeeded() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)

            if beepPlayer == nil {
                beepPlayer = try AVAudioPlayer(data: Self.beepWaveData())
                beepPlayer?.prepareToPlay()
                beepPlayer?.volume = 1
            }

            lastErrorMessage = nil
            return beepPlayer != nil
        } catch {
            lastErrorMessage = "Audible beacon unavailable right now."
            return false
        }
    }

    private func playBeep() {
        guard let beepPlayer else { return }
        beepPlayer.currentTime = 0
        beepPlayer.play()
    }

    private func deactivateAudioSession() {
        beepPlayer?.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            return
        }
    }

    private func activateEmergencyPresentation() {
        let application = UIApplication.shared

        if storedIdleTimerDisabled == nil {
            storedIdleTimerDisabled = application.isIdleTimerDisabled
        }
        application.isIdleTimerDisabled = true

        let currentBrightness = UIScreen.main.brightness
        if storedScreenBrightness == nil {
            storedScreenBrightness = currentBrightness
        }
        UIScreen.main.brightness = max(currentBrightness, 0.96)
    }

    private func deactivateEmergencyPresentation() {
        let application = UIApplication.shared

        if let storedIdleTimerDisabled {
            application.isIdleTimerDisabled = storedIdleTimerDisabled
            self.storedIdleTimerDisabled = nil
        } else {
            application.isIdleTimerDisabled = false
        }

        if let storedScreenBrightness {
            UIScreen.main.brightness = storedScreenBrightness
            self.storedScreenBrightness = nil
        }
    }

    private static func beepWaveData() -> Data {
        let sampleRate = 44_100
        let duration = 0.12
        let frequency = 880.0
        let frameCount = Int(Double(sampleRate) * duration)
        var pcm = Data(capacity: frameCount * 2)

        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(max(frameCount - 1, 1))
            let envelope: Double
            switch progress {
            case ..<0.08:
                envelope = progress / 0.08
            case 0.78...:
                envelope = max((1 - progress) / 0.22, 0)
            default:
                envelope = 1
            }

            let sample = sin(2 * Double.pi * frequency * Double(frame) / Double(sampleRate)) * 0.45 * envelope
            var pcmSample = Int16(sample * Double(Int16.max)).littleEndian
            pcm.append(Data(bytes: &pcmSample, count: MemoryLayout<Int16>.size))
        }

        let dataSize = UInt32(pcm.count)
        let riffSize = 36 + dataSize
        let byteRate = UInt32(sampleRate * 2)
        let blockAlign = UInt16(2)
        let bitsPerSample = UInt16(16)
        let formatChunkSize = UInt32(16)
        let audioFormat = UInt16(1)
        let channelCount = UInt16(1)
        let sampleRate32 = UInt32(sampleRate)

        var wave = Data()
        wave.append("RIFF".data(using: .ascii)!)
        wave.append(Self.bytes(of: riffSize))
        wave.append("WAVE".data(using: .ascii)!)
        wave.append("fmt ".data(using: .ascii)!)
        wave.append(Self.bytes(of: formatChunkSize))
        wave.append(Self.bytes(of: audioFormat))
        wave.append(Self.bytes(of: channelCount))
        wave.append(Self.bytes(of: sampleRate32))
        wave.append(Self.bytes(of: byteRate))
        wave.append(Self.bytes(of: blockAlign))
        wave.append(Self.bytes(of: bitsPerSample))
        wave.append("data".data(using: .ascii)!)
        wave.append(Self.bytes(of: dataSize))
        wave.append(pcm)
        return wave
    }

    private static func bytes<T>(of value: T) -> Data {
        var mutableValue = value
        return withUnsafeBytes(of: &mutableValue) { Data($0) }
    }
}

import SwiftUI

// MARK: - Analog Signal Mode (Full-Screen)

struct AnalogSignalModeView: View {
    @ObservedObject var viewModel: SignalViewModel

    private var snapshot: AnalogRescueSnapshot {
        viewModel.analogRescueSnapshot
    }

    private var torchBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAnalogTorchPatternEnabled },
            set: { viewModel.setAnalogTorchPatternEnabled($0) }
        )
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAnalogAudiblePingEnabled },
            set: { viewModel.setAnalogAudiblePingEnabled($0) }
        )
    }

    private var vibrationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAnalogVibrationPingEnabled },
            set: { viewModel.setAnalogVibrationPingEnabled($0) }
        )
    }

    private var pulseIntervalBinding: Binding<AnalogSignalPulseInterval> {
        Binding(
            get: { viewModel.analogSignalPulseInterval },
            set: { viewModel.setAnalogSignalPulseInterval($0) }
        )
    }

    var body: some View {
        ZStack {
            ColorTheme.panel
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Spacer(minLength: 18)

                signalHero
                    .padding(.horizontal, 20)

                Spacer(minLength: 18)

                ScrollView {
                    VStack(spacing: 16) {
                        controlsCard
                        rescueCard
                        analogCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Offline Hardware Beacon")
                                    .font(RediTypography.heading)
                                    .foregroundStyle(ColorTheme.text)

                                Text("This mode uses the screen, flashlight, speaker, vibration motor, and saved emergency profile on this phone only. It does not require internet, servers, or nearby RediM8 users.")
                                    .font(RediTypography.body)
                                    .foregroundStyle(ColorTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .interactiveDismissDisabled()
        .onDisappear {
            if viewModel.isAnalogSignalActive {
                viewModel.closeAnalogSignalMode()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Analog Survival Mode")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white)

                Text("Battery + hardware only")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent.opacity(0.92))
            }

            Spacer(minLength: 12)

            Button {
                viewModel.closeAnalogSignalMode()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Stop")
                        .font(RediTypography.bodyStrong)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var signalHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(viewModel.analogSignalPattern.screenLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(RediTypography.display)
                        .foregroundStyle(Color.white)
                        .tracking(1.2)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 10) {
                Text(viewModel.analogSignalPattern.subtitle.uppercased())
                    .font(RediTypography.caption)
                    .foregroundStyle(accent)

                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)

                Text("SCREEN SIGNAL ACTIVE")
                    .font(RediTypography.caption)
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            if let coordinatesText = snapshot.coordinatesText {
                Text("GPS \(coordinatesText)")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(Color.white.opacity(0.82))
            } else {
                Text("GPS location still resolving")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: accent.opacity(0.18), radius: 18, y: 10)
    }

    private var controlsCard: some View {
        analogCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signal Controls")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        Text("Change the beacon type, then decide whether flashlight, sound, and vibration should run with it.")
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Button {
                        viewModel.triggerAnalogManualPing()
                    } label: {
                        Label("Manual Ping", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(AnalogSignalPattern.allCases) { pattern in
                        Button {
                            viewModel.setAnalogSignalPattern(pattern)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(pattern.title.uppercased())
                                    .font(RediTypography.label)
                                    .tracking(1.2)
                                    .foregroundStyle(viewModel.analogSignalPattern == pattern ? accent : ColorTheme.textSecondary)
                                Text(pattern.subtitle)
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                                    .fill(ColorTheme.panelElevated.opacity(0.86))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                                            .stroke(
                                                (viewModel.analogSignalPattern == pattern ? accent : ColorTheme.dividerStrong).opacity(viewModel.analogSignalPattern == pattern ? 0.46 : 0.18),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle("Flashlight beacon", isOn: torchBinding)
                    .toggleStyle(.switch)
                    .foregroundStyle(viewModel.isAnalogTorchAvailable ? ColorTheme.text : ColorTheme.textTertiary)
                    .disabled(!viewModel.isAnalogTorchAvailable)

                if !viewModel.isAnalogTorchAvailable {
                    Text("This device does not expose a usable torch, so the screen, sound, vibration, and rescue card remain active instead.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }

                Toggle("Audible ping", isOn: soundBinding)
                    .toggleStyle(.switch)
                    .foregroundStyle(ColorTheme.text)

                Toggle("Vibration ping", isOn: vibrationBinding)
                    .toggleStyle(.switch)
                    .foregroundStyle(ColorTheme.text)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pulse interval")
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)

                    Picker("Pulse interval", selection: pulseIntervalBinding) {
                        ForEach(AnalogSignalPulseInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let analogSignalLastErrorMessage = viewModel.analogSignalLastErrorMessage {
                    Text(analogSignalLastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }
            }
        }
    }

    private var rescueCard: some View {
        analogCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Rescue Card")
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)

                rescueRow(label: "Owner", value: snapshot.ownerName)
                rescueRow(label: "GPS", value: snapshot.coordinatesText ?? "Waiting for current location")

                if let bloodType = snapshot.bloodType {
                    rescueRow(label: "Blood Type", value: bloodType)
                }

                if let allergies = snapshot.allergies {
                    rescueRow(label: "Allergies", value: allergies)
                }

                if let medication = snapshot.medication {
                    rescueRow(label: "Medication", value: medication)
                }

                if let conditionSummary = snapshot.conditionSummary {
                    rescueRow(label: "Condition", value: conditionSummary)
                }

                if !snapshot.contacts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Contacts")
                            .font(RediTypography.bodyStrong)
                            .foregroundStyle(ColorTheme.text)

                        ForEach(snapshot.contacts.prefix(3), id: \.id) { contact in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "person.crop.circle.badge.phone")
                                    .foregroundStyle(accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.name)
                                        .font(RediTypography.bodyStrong)
                                        .foregroundStyle(ColorTheme.text)
                                    Text(contact.phone)
                                        .font(RediTypography.body)
                                        .foregroundStyle(ColorTheme.textSecondary)
                                }
                            }
                        }
                    }
                } else {
                    Text("No emergency contacts saved yet. Add them in Settings or Plan so rescuers have someone to call.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }
            }
        }
    }

    private func analogCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                .fill(ColorTheme.panelRaised.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func rescueRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(accent)
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accent: Color {
        switch viewModel.analogSignalPattern {
        case .sos:
            ColorTheme.warning
        case .help:
            ColorTheme.danger
        case .stayAway:
            Color(red: 0.97, green: 0.38, blue: 0.34)
        case .safe:
            ColorTheme.ready
        }
    }

    private var backgroundTop: Color {
        switch viewModel.analogSignalPattern {
        case .sos:
            Color(red: 0.25, green: 0.14, blue: 0.02)
        case .help:
            Color(red: 0.26, green: 0.05, blue: 0.05)
        case .stayAway:
            Color(red: 0.22, green: 0.03, blue: 0.04)
        case .safe:
            Color(red: 0.06, green: 0.19, blue: 0.12)
        }
    }

    private var backgroundBottom: Color {
        switch viewModel.analogSignalPattern {
        case .sos:
            Color.black
        case .help:
            Color(red: 0.08, green: 0.01, blue: 0.01)
        case .stayAway:
            Color.black
        case .safe:
            Color.black
        }
    }
}

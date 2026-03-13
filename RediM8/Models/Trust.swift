import Foundation

enum GuideTrustProfile: Equatable {
    case generalSafety
    case generalFirstAid

    var title: String {
        "Preparedness Guide"
    }

    var summary: String {
        switch self {
        case .generalSafety:
            "General safety guidance"
        case .generalFirstAid:
            "General first aid guidance"
        }
    }
}

struct EmergencyQuickContact: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let phoneNumber: String?
    let displayNumber: String?
    let systemImage: String

    var isAvailable: Bool {
        phoneNumber?.nilIfBlank != nil
    }

    var dialURL: URL? {
        guard let phoneNumber = phoneNumber?.dialablePhoneNumber else {
            return nil
        }
        return URL(string: "tel://\(phoneNumber)")
    }
}

enum TrustLayer {
    static let safetyLimitationsLines = [
        "RediM8 is an assistive preparedness and emergency information tool.",
        "It does not replace emergency services, government alerts, or professional medical advice.",
        "Information shown in RediM8 can be incomplete, delayed, or outdated in rapidly changing situations.",
        "Always follow instructions from official authorities and contact emergency services when possible."
    ]

    static let safetyDisclaimerLines = [
        "RediM8 provides general preparedness information.",
        "It does not replace official emergency services or professional medical advice.",
        "Always follow instructions from emergency authorities and call emergency services when necessary."
    ]

    static let privacyTransparencyLines = [
        "RediM8 stores data locally on your device.",
        "Location is only used for map features and nearby communication.",
        "No personal data is sent to external servers."
    ]

    static let beaconVerificationReminder = "Information shared through community reports may not be verified. Always confirm when possible."
    static let blackoutSafetyReminder = "If you are in immediate danger, contact emergency services."
    static let fireTrailSafetyReminder = "Fire trails may not be safe evacuation routes. Always follow instructions from emergency services."
    static let shelterAvailabilityReminder = "Shelter availability may change during emergencies. Always follow instructions from emergency services."
    static let signalAssistiveReminder = "Signal and Community Reports are assistive short-range tools. They are not a substitute for mobile coverage, satellite devices, or official radio."
    static let signalDeliveryNotice = "Delivery is not guaranteed. Nearby devices, battery state, Bluetooth, Wi-Fi, terrain, and congestion all affect what gets through."
    static let signalConstraintNotice = "Treat every mesh message or community report as local, delay-prone, and potentially stale until you confirm it."
    static let emergencyMedicalInfoPrivacyNotice = "This information stays on your device. It is only shared if you choose to include it in a Need Help or Medical Emergency report."
    static let emergencyMedicalInfoScopeNotice = "Keep only severe allergies, critical conditions, blood type, and medication details that matter if someone is helping you urgently."
    static let guideAttribution = "Based on common emergency preparedness guidance used by emergency management agencies."
    static let guideEndorsementNotice = "RediM8 does not claim official agency endorsement."
    static let librarySourceTransparencyNotice = "Guides can include official references, public-domain material, and original RediM8 diagrams. RediM8 does not reproduce copyrighted survival books."
    static let mapFreshnessNotice = "Offline resource, track, water-point, and evacuation-point maps are reference data and may not reflect live hazards, closures, shelter activation, or water availability."
    static let mapDataUnavailableMessage = "Unable to load map data. Offline resources may be limited."
    static let mapCoverageNotice = "Coverage stops at installed pack boundaries. If RediM8 has no local layer data, it keeps the basemap and any saved markers visible while the missing layer falls back."
    static let trustLabelLegendLines = [
        "Verified: sourced from curated or official data RediM8 bundles or mirrors.",
        "Community-reported: shared by nearby users and not independently verified by RediM8.",
        "Approximate: intended to guide nearby search, not precise navigation.",
        "Offline only: visible from local cached or bundled data without live confirmation.",
        "Last updated: shows when RediM8 last reviewed or mirrored the information."
    ]

    static let emergencyCallNumber = "000"
    static let sesNumber = "132500"
    static let sesDisplayNumber = "132 500"

    static func freshnessLabel(for date: Date, reference: Date = .now) -> String {
        date.rediM8FreshnessLabel(reference: reference)
    }

    static func quickContacts(for profile: UserProfile) -> [EmergencyQuickContact] {
        let localContact = profile.emergencyContacts.first { $0.phone.nilIfBlank != nil }
        let familyContact = profile.familyMembers.first { $0.phone.nilIfBlank != nil }

        return [
            EmergencyQuickContact(
                id: "emergency_services",
                title: "Emergency Call",
                subtitle: "Police, fire, or ambulance",
                phoneNumber: emergencyCallNumber,
                displayNumber: emergencyCallNumber,
                systemImage: "phone.connection.fill"
            ),
            EmergencyQuickContact(
                id: "ses",
                title: "SES",
                subtitle: "State Emergency Service assistance",
                phoneNumber: sesNumber,
                displayNumber: sesDisplayNumber,
                systemImage: "waveform.path.ecg"
            ),
            EmergencyQuickContact(
                id: "local_contact",
                title: "Local emergency contact",
                subtitle: localContact?.name.nilIfBlank ?? "Add a saved local contact in Plan",
                phoneNumber: localContact?.phone.nilIfBlank,
                displayNumber: localContact?.phone.nilIfBlank,
                systemImage: "person.crop.circle.badge.exclamationmark"
            ),
            EmergencyQuickContact(
                id: "family_contact",
                title: "Family emergency contact",
                subtitle: familyContact?.name.nilIfBlank ?? "Add a family phone number in Plan",
                phoneNumber: familyContact?.phone.nilIfBlank,
                displayNumber: familyContact?.phone.nilIfBlank,
                systemImage: "person.2.fill"
            )
        ]
    }
}

extension Guide {
    var trustProfile: GuideTrustProfile {
        switch category {
        case .firstAid, .medical:
            .generalFirstAid
        case .disasterResponse, .bushcraft, .navigation, .waterSafety, .fireSafety, .heatSafety, .stormSafety, .floodSafety, .foodCooking, .foodGrowing:
            .generalSafety
        }
    }

    var confidenceTitle: String {
        trustProfile.title
    }

    var confidenceSummary: String {
        trustProfile.summary
    }
}

private extension String {
    var dialablePhoneNumber: String? {
        let filtered = filter { $0.isWholeNumber || $0 == "+" }
        return filtered.nilIfBlank
    }
}

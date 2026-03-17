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

    static let privacyPolicyURL = URL(string: "https://redim8.com.au/privacy")!
    static let termsOfUseURL = URL(string: "https://redim8.com.au/terms")!
    static let supportURL = URL(string: "mailto:support@redim8.com.au")!

    static let fullPrivacyPolicyLines = [
        "PRIVACY POLICY",
        "Effective date: 18 March 2026",
        "",
        "RediM8 Pty Ltd (ABN pending) (\"we\", \"us\", \"our\") operates the RediM8 mobile application. This policy explains how we handle your information.",
        "",
        "1. INFORMATION WE COLLECT",
        "",
        "1.1 Information You Provide",
        "Household profiles, emergency contacts, preparedness checklists, go-bag inventories, and documents you store in Secure Vault are created and stored entirely on your device. We do not have access to this data.",
        "",
        "1.2 Location Data",
        "RediM8 accesses your location only while the app is in use, for map features, compass heading, nearby resource discovery, and mesh peer positioning. Location data is never transmitted to our servers.",
        "",
        "1.3 Bluetooth & Local Network",
        "RediM8 uses Bluetooth and local Wi-Fi to discover nearby devices for offline emergency mesh messaging. Your chosen display name is shared with nearby peers during mesh sessions. No other personal data is transmitted.",
        "",
        "1.4 Camera & Photo Library",
        "Camera access is used for the torch in Blackout Mode and to scan documents into Secure Vault. Photo Library access lets you import photos of IDs and documents. These files are encrypted and stored locally.",
        "",
        "1.5 Motion Data",
        "Device motion is used solely to stabilise compass and blackout tools. Motion data is not stored or transmitted.",
        "",
        "2. INFORMATION WE DO NOT COLLECT",
        "",
        "We do not collect analytics, crash reports, advertising identifiers, IP addresses, device fingerprints, or usage telemetry. RediM8 contains no third-party analytics SDKs, no tracking pixels, and no advertising frameworks.",
        "",
        "3. DATA STORAGE & SECURITY",
        "",
        "All user data is stored on-device using SQLite with iOS Data Protection. Secure Vault documents are encrypted with AES-256-GCM using keys stored in the device Keychain with biometric or passcode protection. Vault data is excluded from iCloud backup.",
        "",
        "4. THIRD-PARTY SERVICES",
        "",
        "RediM8 fetches publicly available emergency alert feeds from Australian government agencies (BOM, RFS, SES, ESA) over HTTPS. RediM8 queries the OpenStreetMap Overpass API for water and shelter point-of-interest data. No personal information is included in these requests.",
        "",
        "5. IN-APP PURCHASES",
        "",
        "RediM8 Pro subscriptions are processed by Apple through StoreKit. We do not receive or store your payment details. Purchase history is managed by your Apple ID.",
        "",
        "6. CHILDREN'S PRIVACY",
        "",
        "RediM8 is not directed at children under 13. We do not knowingly collect personal information from children.",
        "",
        "7. DATA RETENTION & DELETION",
        "",
        "Since all data is stored locally, deleting the app removes all your data. There is no server-side data to request deletion of.",
        "",
        "8. CHANGES TO THIS POLICY",
        "",
        "We may update this policy from time to time. Changes will be reflected in the app and on our website.",
        "",
        "9. CONTACT US",
        "",
        "If you have questions about this policy, contact us at support@redim8.com.au.",
        "",
        "RediM8 Pty Ltd, Australia."
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
        case .wildlife, .trapping, .toolcraft, .fieldComms, .sanitation,
             .psychology, .security, .vehicleSurvival, .waterSourcing,
             .shelterBuilding, .firecraft, .navigationAdvanced:
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

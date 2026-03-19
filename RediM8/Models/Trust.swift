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

struct TrustReferenceSection: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let lines: [String]
    let linkTitle: String?
    let linkURL: URL?
}

struct TrustPolicySection: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let lines: [String]
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
        "Location is used for map features, nearby communication, and nearby resource searches.",
        "RediM8 sends precise coordinates to trusted third-party map data services only when you request nearby live results."
    ]

    static let privacyPolicyURL = URL(string: "https://redim8.com.au/privacy")!
    static let termsOfUseURL = URL(string: "https://redim8.com.au/terms")!
    static let supportURL = URL(string: "mailto:support@redim8.com.au")!
    static let mapLibreURL = URL(string: "https://github.com/maplibre/maplibre-gl-native-distribution")!
    static let openStreetMapCopyrightURL = URL(string: "https://www.openstreetmap.org/copyright")!

    static let attributionSections = [
        TrustReferenceSection(
            id: "map_rendering",
            title: "Map Rendering",
            subtitle: "Offline tactical map rendering and local basemap display",
            lines: [
                "RediM8 uses MapLibre Native Distribution for map rendering.",
                "MapLibre Native Distribution is bundled under the BSD 2-Clause License."
            ],
            linkTitle: "View MapLibre project",
            linkURL: mapLibreURL
        ),
        TrustReferenceSection(
            id: "open_map_data",
            title: "Open Map Data",
            subtitle: "Bundled starter datasets, routing source material, and nearby live lookups",
            lines: [
                "Bundled starter tracks, fire trails, and water points in RediM8 include OpenStreetMap-derived source data.",
                "Live nearby shelter and water searches query the OpenStreetMap Overpass API.",
                "Open map data attribution: OpenStreetMap contributors."
            ],
            linkTitle: "OpenStreetMap attribution and licence",
            linkURL: openStreetMapCopyrightURL
        ),
        TrustReferenceSection(
            id: "official_warning_sources",
            title: "Official Warning Sources",
            subtitle: "Readable summaries of public agency feeds",
            lines: [
                "RediM8 mirrors public warning feeds from BOM, ACT ESA, NSW RFS, Queensland public alerts, South Australia Alert SA / CFS, Tasmania Alert, Victoria Emergency, and Emergency WA.",
                "Alert content, agency names, and trademarks remain the property of the issuing organisations.",
                "RediM8 does not claim government endorsement and always asks users to confirm official instructions first."
            ],
            linkTitle: nil,
            linkURL: nil
        ),
        TrustReferenceSection(
            id: "guide_sources",
            title: "Guide Sources",
            subtitle: "Original RediM8 content plus source notes where provided",
            lines: [
                "Guide-specific source and licence notes appear inside each guide when available.",
                "Original RediM8 guide copy, diagrams, and artwork remain copyright RediM8."
            ],
            linkTitle: nil,
            linkURL: nil
        )
    ]

    static let privacyAtAGlanceLines = [
        "Your data stays on this device.",
        "We do not track you or collect analytics.",
        "We do not sell or share personal data.",
        "Location is never sent to RediM8 servers.",
        "Live nearby searches send coordinates only to the map service needed to return local results.",
        "You control what nearby users see, if anything."
    ]

    static let privacyWhyDifferentLines = [
        "Most apps rely on cloud servers and track usage behind the scenes.",
        "RediM8 is designed to work without internet and without collecting your personal data.",
        "Your plans, documents, and emergency information stay on your device and are never accessible to us."
    ]

    static let privacyPolicySections = [
        TrustPolicySection(
            id: "data_stays_local",
            title: "Data stays on your device",
            subtitle: "Preparedness data is local-first by default.",
            systemImage: "lock.shield",
            lines: [
                "Household profiles, emergency contacts, preparedness checklists, and go-bag inventories are stored on this device.",
                "Secure Vault files are encrypted locally and we cannot access them.",
                "RediM8 does not operate a cloud account system for your personal emergency data."
            ]
        ),
        TrustPolicySection(
            id: "location_usage",
            title: "Location usage",
            subtitle: "Used only while you are actively using RediM8.",
            systemImage: "location.viewfinder",
            lines: [
                "We only use your location while you are actively using the app.",
                "Your location is never stored or sent to RediM8 servers.",
                "If you request nearby live shelter or water results, RediM8 sends search coordinates to the OpenStreetMap Overpass API so it can return local map data."
            ]
        ),
        TrustPolicySection(
            id: "local_communication",
            title: "Local communication",
            subtitle: "Bluetooth and local Wi-Fi support nearby mesh awareness.",
            systemImage: "antenna.radiowaves.left.and.right",
            lines: [
                "Bluetooth and local Wi-Fi help RediM8 discover nearby devices when networks fail.",
                "Your chosen display name can be shared with nearby peers during mesh sessions.",
                "No analytics, advertising identifiers, or hidden telemetry are attached to those local exchanges."
            ]
        ),
        TrustPolicySection(
            id: "camera_documents",
            title: "Camera and documents",
            subtitle: "Used for torch, scanning, and secure local storage.",
            systemImage: "camera.viewfinder",
            lines: [
                "Camera access supports Blackout Mode torch tools and document scanning.",
                "Photo Library access lets you import images of IDs and records.",
                "Imported files are encrypted and stored locally."
            ]
        ),
        TrustPolicySection(
            id: "what_we_do_not_collect",
            title: "What we do not collect",
            subtitle: "No tracking stack, ads, or hidden profiling.",
            systemImage: "hand.raised.slash",
            lines: [
                "We do not collect analytics, crash reports, advertising identifiers, IP addresses, device fingerprints, or usage telemetry.",
                "RediM8 contains no third-party analytics SDKs, no tracking pixels, and no advertising frameworks.",
                "We do not sell data, build marketing profiles, or share personal information with data brokers."
            ]
        ),
        TrustPolicySection(
            id: "third_party_services",
            title: "Third-party services",
            subtitle: "Only the services required to provide alerts, maps, and purchases.",
            systemImage: "externaldrive.connected.to.line.below",
            lines: [
                "RediM8 fetches public emergency alert feeds from Australian agencies over HTTPS.",
                "Nearby live shelter and water searches use the OpenStreetMap Overpass API.",
                "In-app purchases are handled by Apple through StoreKit, and we do not receive your payment details."
            ]
        ),
        TrustPolicySection(
            id: "security_and_deletion",
            title: "Security and deletion",
            subtitle: "Protected on device, removable by you.",
            systemImage: "key.fill",
            lines: [
                "All user data is stored on-device using SQLite with iOS Data Protection.",
                "Vault documents use AES-256-GCM encryption with Keychain-backed keys and biometric or passcode protection.",
                "Deleting the app removes your local data. There is no server-side personal dataset to request deletion of."
            ]
        ),
        TrustPolicySection(
            id: "policy_admin",
            title: "Policy details",
            subtitle: "Updates, children, and contact.",
            systemImage: "doc.text.magnifyingglass",
            lines: [
                "RediM8 is not directed at children under 13, and we do not knowingly collect personal information from children.",
                "We may update this policy over time, with changes reflected in the app and on our website.",
                "Questions about privacy can be sent to support@redim8.com.au."
            ]
        )
    ]

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
        "RediM8 accesses your location only while the app is in use, for map features, compass heading, nearby resource discovery, and mesh peer positioning. Location data is never transmitted to our servers. When you request nearby live shelter or water results, RediM8 sends your search coordinates to the OpenStreetMap Overpass API to fetch local open map data.",
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
        "RediM8 fetches publicly available emergency alert feeds from Australian government agencies (BOM, RFS, SES, ESA) over HTTPS. RediM8 queries the OpenStreetMap Overpass API for water and shelter point-of-interest data. Nearby Overpass searches include the map coordinates needed to return local results.",
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

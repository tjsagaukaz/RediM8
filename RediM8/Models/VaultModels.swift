import Foundation
import UniformTypeIdentifiers

enum VaultCategory: String, CaseIterable, Codable, Identifiable {
    case identity
    case insurance
    case medical
    case property
    case vehicle
    case pets
    case emergencyContacts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .identity:
            "Identity"
        case .insurance:
            "Insurance"
        case .medical:
            "Medical"
        case .property:
            "Property"
        case .vehicle:
            "Vehicle"
        case .pets:
            "Pets"
        case .emergencyContacts:
            "Emergency Contacts"
        }
    }

    var subtitle: String {
        switch self {
        case .identity:
            "ID, passport, and licences"
        case .insurance:
            "Policies and claim details"
        case .medical:
            "Prescriptions and care records"
        case .property:
            "Deeds, utilities, and house records"
        case .vehicle:
            "Registration, roadside, and service records"
        case .pets:
            "Vaccinations, microchips, and vet notes"
        case .emergencyContacts:
            "Printed contacts and household call trees"
        }
    }

    var iconName: String {
        switch self {
        case .identity:
            "documents"
        case .insurance:
            "shield"
        case .medical:
            "first_aid"
        case .property:
            "home"
        case .vehicle:
            "four_wd"
        case .pets:
            "pets"
        case .emergencyContacts:
            "family"
        }
    }

    var supportsEmergencyQuickAccess: Bool {
        switch self {
        case .identity, .insurance, .medical, .emergencyContacts:
            true
        case .property, .vehicle, .pets:
            false
        }
    }
}

enum VaultDocumentSource: String, Codable, CaseIterable {
    case scan
    case pdfImport
    case photoImport
    case fileImport

    var title: String {
        switch self {
        case .scan:
            "Scanned"
        case .pdfImport:
            "Imported PDF"
        case .photoImport:
            "Imported photo"
        case .fileImport:
            "Imported file"
        }
    }
}

struct VaultDocument: Identifiable, Codable, Equatable {
    let id: UUID
    var category: VaultCategory
    var displayName: String
    var originalFilename: String
    var fileExtension: String
    var contentTypeIdentifier: String
    var source: VaultDocumentSource
    var byteCount: Int
    var pageCount: Int?
    var createdAt: Date
    var updatedAt: Date

    var contentType: UTType {
        UTType(contentTypeIdentifier) ?? .data
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    var quickAccessEligible: Bool {
        category.supportsEmergencyQuickAccess
    }
}

struct EmergencyInfoCard: Codable, Equatable {
    var bloodType: String
    var allergies: String
    var medications: String
    var emergencyContacts: String
    var medicalNotes: String

    static let empty = EmergencyInfoCard(
        bloodType: "",
        allergies: "",
        medications: "",
        emergencyContacts: "",
        medicalNotes: ""
    )

    var hasAnyContent: Bool {
        [bloodType, allergies, medications, emergencyContacts, medicalNotes]
            .contains { $0.nilIfBlank != nil }
    }
}

struct VaultState: Codable, Equatable {
    var documents: [VaultDocument]
    var emergencyInfo: EmergencyInfoCard

    static let empty = VaultState(documents: [], emergencyInfo: .empty)
}

struct VaultImportPayload {
    let data: Data
    let displayName: String
    let filename: String
    let contentType: UTType
    let source: VaultDocumentSource
    let pageCount: Int?
}

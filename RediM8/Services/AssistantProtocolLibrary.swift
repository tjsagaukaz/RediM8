import Foundation

enum AssistantProtocolLibrary {
    static let medicalProtocols: [AssistantProtocolDefinition] = AssistantMedicalProtocolCatalog.build()
    static let survivalProtocols: [AssistantProtocolDefinition] = AssistantSurvivalProtocolCatalog.build()
    static let all: [AssistantProtocolDefinition] = medicalProtocols + survivalProtocols

    static func protocolDefinition(id: String) -> AssistantProtocolDefinition? {
        all.first(where: { $0.id == id })
    }
}

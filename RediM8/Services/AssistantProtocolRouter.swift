import Foundation

final class AssistantProtocolRouter {
    private struct IndexedProtocol {
        let definition: AssistantProtocolDefinition
        let normalizedTriggerTerms: [String]
        let normalizedAlternatePhrases: [String]
        let tokenGroups: [Set<String>]
        let lexicon: Set<String>
    }

    private let indexedProtocols: [IndexedProtocol]

    init(protocols: [AssistantProtocolDefinition] = AssistantProtocolLibrary.all) {
        indexedProtocols = protocols.map { definition in
            let triggerTerms = definition.triggerTerms.map(AssistantIntentClassifier.normalize)
            let alternatePhrases = definition.alternateTriggerPhrases.map(AssistantIntentClassifier.normalize)
            let tokenGroups = definition.triggerTokenGroups.map { Set($0.map(AssistantIntentClassifier.normalize)) }
            let lexicon = Set(
                (triggerTerms + alternatePhrases)
                    .flatMap { Self.tokens(in: $0) }
            )

            return IndexedProtocol(
                definition: definition,
                normalizedTriggerTerms: triggerTerms,
                normalizedAlternatePhrases: alternatePhrases,
                tokenGroups: tokenGroups,
                lexicon: lexicon
            )
        }
    }

    func queryContext(
        for query: String,
        snapshot: AssistantSituationSnapshot?
    ) -> AssistantProtocolQueryContext {
        let normalizedQuery = AssistantIntentClassifier.normalize(query)
        let tokens = Self.tokens(in: normalizedQuery)
        var flags = Set<AssistantProtocolQueryFlag>()

        if normalizedQuery.containsAny(Self.bystanderFragments) || !Set(tokens).isDisjoint(with: Self.bystanderTokens) {
            flags.insert(.bystander)
        }

        if normalizedQuery.containsAny(Self.childFragments) || !Set(tokens).isDisjoint(with: Self.childTokens) {
            flags.insert(.child)
            flags.insert(.dependents)
        }

        if normalizedQuery.containsAny(Self.dependentFragments) || !Set(tokens).isDisjoint(with: Self.dependentTokens) {
            flags.insert(.dependents)
        }

        if normalizedQuery.containsAny(Self.petFragments) || !Set(tokens).isDisjoint(with: Self.petTokens) {
            flags.insert(.pets)
        }

        if normalizedQuery.containsAny(Self.multipleCasualtyFragments) {
            flags.insert(.multipleCasualties)
        }

        if normalizedQuery.containsAny(Self.noSignalFragments) {
            flags.insert(.noSignal)
        }

        if normalizedQuery.containsAny(Self.noGPSFragments) {
            flags.insert(.noGPS)
        }

        if normalizedQuery.containsAny(Self.noPowerFragments) {
            flags.insert(.noPower)
        }

        if normalizedQuery.containsAny(Self.noEquipmentFragments) {
            flags.insert(.noEquipment)
        }

        if normalizedQuery.containsAny(Self.aedFragments) {
            flags.insert(.hasAED)
        }

        if normalizedQuery.containsAny(Self.inhalerFragments) {
            flags.insert(.hasInhaler)
        }

        if normalizedQuery.containsAny(Self.spacerFragments) {
            flags.insert(.hasSpacer)
        }

        if normalizedQuery.containsAny(Self.epipenFragments) {
            flags.insert(.hasEpiPen)
        }

        if normalizedQuery.containsAny(Self.naloxoneFragments) {
            flags.insert(.hasNaloxone)
        }

        if normalizedQuery.containsAny(Self.smokeFragments) {
            flags.insert(.smoke)
        }

        if normalizedQuery.containsAny(Self.heatFragments) {
            flags.insert(.heat)
        }

        if normalizedQuery.containsAny(Self.coldFragments) {
            flags.insert(.cold)
        }

        if normalizedQuery.containsAny(Self.vehicleFragments) {
            flags.insert(.vehicle)
        }

        if normalizedQuery.containsAny(Self.waterExposureFragments) {
            flags.insert(.waterExposure)
        }

        if normalizedQuery.containsAny(Self.poisoningFragments) {
            flags.insert(.poisoning)
        }

        if normalizedQuery.containsAny(Self.swallowedSubstanceFragments) {
            flags.insert(.swallowedSubstance)
            flags.insert(.poisoning)
        }

        if normalizedQuery.containsAny(Self.chemicalExposureFragments) {
            flags.insert(.chemicalExposure)
            flags.insert(.poisoning)
        }

        if Self.loneUserFragments.contains(normalizedQuery) {
            flags.insert(.loneUser)
        }

        if snapshot?.routeStatus == .atRisk {
            flags.insert(.routeRisk)
        }

        if snapshot?.routeStatus == .blocked {
            flags.insert(.routeBlocked)
        }

        return AssistantProtocolQueryContext(
            normalizedQuery: normalizedQuery,
            tokens: tokens,
            tokenSet: Set(tokens),
            flags: flags
        )
    }

    func fastPathMatch(
        query: String,
        snapshot: AssistantSituationSnapshot?
    ) -> AssistantProtocolMatch? {
        let context = queryContext(for: query, snapshot: snapshot)

        guard shouldConsiderFastPath(queryContext: context, snapshot: snapshot) else {
            return nil
        }

        return bestMatch(
            from: indexedProtocols.filter { $0.definition.fastPathEligible },
            queryContext: context,
            snapshot: snapshot,
            minimumScore: 2.4
        )
    }

    func overrideMatch(
        query: String,
        classification: AssistantIntentClassification,
        guides: [Guide],
        snapshot: AssistantSituationSnapshot?
    ) -> AssistantProtocolMatch? {
        let context = queryContext(for: query, snapshot: snapshot)
        let weakRetrieval = guides.isEmpty || classification.topic == .unknown || classification.confidence < 0.52
        let shouldOverride = weakRetrieval
            || context.isGenericHighRisk
            || context.isMovementDecision
            || context.flags.contains(.bystander)
            || snapshot?.mode == .elevated
            || snapshot?.mode == .crisis

        guard shouldOverride else {
            return nil
        }

        let match = bestMatch(
            from: indexedProtocols,
            queryContext: context,
            snapshot: snapshot,
            minimumScore: context.isEducationalPrompt ? 3.4 : 2.2
        )

        guard let match else {
            return nil
        }

        if classification.topic != .unknown,
           classification.confidence >= 0.72,
           !context.isGenericHighRisk,
           !context.flags.contains(.bystander),
           match.definition.urgency == .planning {
            return nil
        }

        return match
    }

    private func shouldConsiderFastPath(
        queryContext: AssistantProtocolQueryContext,
        snapshot: AssistantSituationSnapshot?
    ) -> Bool {
        if snapshot?.mode == .elevated || snapshot?.mode == .crisis {
            return true
        }

        if queryContext.isGenericHighRisk || queryContext.isMovementDecision {
            return true
        }

        if !queryContext.flags.isDisjoint(with: [
            .bystander,
            .child,
            .multipleCasualties,
            .poisoning,
            .chemicalExposure,
            .swallowedSubstance,
            .waterExposure
        ]) {
            return true
        }

        guard !queryContext.isEducationalPrompt else {
            return false
        }

        if queryContext.normalizedQuery.containsAny(Self.fastPathFragments) {
            return true
        }

        return hasFuzzyFastPathSignal(queryContext)
    }

    private func bestMatch(
        from protocols: [IndexedProtocol],
        queryContext: AssistantProtocolQueryContext,
        snapshot: AssistantSituationSnapshot?,
        minimumScore: Double
    ) -> AssistantProtocolMatch? {
        protocols
            .compactMap { protocolEntry -> AssistantProtocolMatch? in
                let score = score(
                    protocolEntry,
                    queryContext: queryContext,
                    snapshot: snapshot
                )

                guard score.score >= minimumScore else {
                    return nil
                }

                return AssistantProtocolMatch(
                    definition: protocolEntry.definition,
                    score: score.score,
                    matchedTerms: Array(score.matchedTerms).sorted(),
                    queryContext: queryContext
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }

                if lhs.definition.urgency != rhs.definition.urgency {
                    return urgencyRank(lhs.definition.urgency) > urgencyRank(rhs.definition.urgency)
                }

                return lhs.definition.displayName < rhs.definition.displayName
            }
            .first
    }

    private func score(
        _ protocolEntry: IndexedProtocol,
        queryContext: AssistantProtocolQueryContext,
        snapshot: AssistantSituationSnapshot?
    ) -> (score: Double, matchedTerms: Set<String>) {
        var matchedTerms = Set<String>()
        var score = 0.0

        for phrase in protocolEntry.normalizedTriggerTerms where queryContext.normalizedQuery.contains(phrase) {
            matchedTerms.insert(phrase)
            score += phrase.contains(" ") ? 2.3 : 1.9
        }

        for phrase in protocolEntry.normalizedTriggerTerms
        where !matchedTerms.contains(phrase) && fuzzyPhraseMatch(phrase, queryContext: queryContext) {
            matchedTerms.insert(phrase)
            score += phrase.contains(" ") ? 1.95 : 2.1
        }

        for phrase in protocolEntry.normalizedAlternatePhrases where queryContext.normalizedQuery.contains(phrase) {
            matchedTerms.insert(phrase)
            score += phrase.contains(" ") ? 2.0 : 1.5
        }

        for phrase in protocolEntry.normalizedAlternatePhrases
        where !matchedTerms.contains(phrase) && fuzzyPhraseMatch(phrase, queryContext: queryContext) {
            matchedTerms.insert(phrase)
            score += phrase.contains(" ") ? 1.65 : 1.45
        }

        for group in protocolEntry.tokenGroups {
            if group.isSubset(of: queryContext.tokenSet) {
                matchedTerms.insert(group.sorted().joined(separator: " "))
                score += Double(max(group.count, 2))
                continue
            }

            if fuzzyMatches(group: group, tokenSet: queryContext.tokenSet) {
                matchedTerms.insert(group.sorted().joined(separator: " "))
                score += Double(max(group.count, 2)) * 0.7
            }
        }

        for token in protocolEntry.lexicon where fuzzyContains(token: token, tokenSet: queryContext.tokenSet) {
            matchedTerms.insert(token)
            score += token.count >= 6 ? 0.35 : 0.2
        }

        if protocolEntry.definition.domain == .medical,
           !queryContext.flags.isDisjoint(with: [.bystander, .child, .multipleCasualties, .poisoning, .waterExposure]) {
            score += 0.45
        }

        if queryContext.flags.contains(.routeBlocked),
           protocolEntry.definition.contextInjectors.contains(.routeBlocked) {
            score += 0.5
        } else if queryContext.flags.contains(.routeRisk),
                  protocolEntry.definition.contextInjectors.contains(.routeRisk) {
            score += 0.35
        }

        if queryContext.flags.contains(.noSignal),
           protocolEntry.definition.contextInjectors.contains(.noSignal) {
            score += 0.35
        }

        if queryContext.flags.contains(.noGPS),
           protocolEntry.definition.contextInjectors.contains(.noGPS) {
            score += 0.35
        }

        if queryContext.tokenSet.contains("lost"),
           protocolEntry.definition.id == "no_gps_or_lost" {
            score += 0.55
        }

        if queryContext.flags.contains(.noSignal),
           queryContext.tokenSet.contains("lost"),
           protocolEntry.definition.id == "no_signal" {
            score -= 0.15
        }

        if queryContext.flags.contains(.noPower),
           protocolEntry.definition.contextInjectors.contains(.noPower) {
            score += 0.35
        }

        if queryContext.flags.contains(.poisoning),
           protocolEntry.definition.contextInjectors.contains(.poisoning) {
            score += 1.0
        }

        if queryContext.flags.contains(.swallowedSubstance),
           protocolEntry.definition.contextInjectors.contains(.swallowedSubstance) {
            score += 0.95
        }

        if queryContext.flags.contains(.chemicalExposure),
           protocolEntry.definition.contextInjectors.contains(.chemicalExposure) {
            score += 0.95
        }

        if queryContext.flags.contains(.waterExposure),
           protocolEntry.definition.contextInjectors.contains(.waterExposure) {
            score += 0.45
        }

        if queryContext.flags.contains(.dependents),
           protocolEntry.definition.contextInjectors.contains(.dependents) {
            score += 0.2
        }

        if snapshot?.mode == .crisis && protocolEntry.definition.urgency == .emergency {
            score += 0.4
        } else if snapshot?.mode == .elevated && protocolEntry.definition.urgency != .planning {
            score += 0.25
        }

        if queryContext.isMovementDecision,
           protocolEntry.definition.primaryAction == .reviewRouteIfAvailable {
            score += 0.45
        }

        if queryContext.isEducationalPrompt,
           protocolEntry.definition.domain == .medical,
           protocolEntry.definition.urgency == .emergency,
           !queryContext.flags.contains(.bystander) {
            score -= 0.5
        }

        return (score, matchedTerms)
    }

    private func fuzzyMatches(group: Set<String>, tokenSet: Set<String>) -> Bool {
        group.allSatisfy { fuzzyContains(token: $0, tokenSet: tokenSet) }
    }

    private func fuzzyPhraseMatch(
        _ phrase: String,
        queryContext: AssistantProtocolQueryContext
    ) -> Bool {
        let phraseTokens = Self.tokens(in: phrase)
        guard !phraseTokens.isEmpty else {
            return false
        }

        return phraseTokens.allSatisfy { fuzzyContains(token: $0, tokenSet: queryContext.tokenSet) }
    }

    private func hasFuzzyFastPathSignal(_ queryContext: AssistantProtocolQueryContext) -> Bool {
        Self.fastPathFragments.contains { fragment in
            fuzzyPhraseMatch(fragment, queryContext: queryContext)
        }
    }

    private func fuzzyContains(token: String, tokenSet: Set<String>) -> Bool {
        if tokenSet.contains(token) {
            return true
        }

        let variants = tokenVariants(for: token)
        if !variants.isDisjoint(with: tokenSet) {
            return true
        }

        guard token.count >= 4 else {
            return false
        }

        let maxDistance = token.count >= 9 ? 2 : 1

        for candidate in tokenSet where abs(candidate.count - token.count) <= maxDistance {
            if Self.editDistance(token, candidate) <= maxDistance {
                return true
            }

            for variant in variants where abs(candidate.count - variant.count) <= maxDistance {
                if Self.editDistance(variant, candidate) <= maxDistance {
                    return true
                }
            }
        }

        return false
    }

    private func tokenVariants(for token: String) -> Set<String> {
        var variants = Set([token])

        if token.hasSuffix("s"), token.count > 4 {
            variants.insert(String(token.dropLast()))
        }

        if token.hasSuffix("es"), token.count > 5 {
            variants.insert(String(token.dropLast(2)))
        }

        if token.hasSuffix("ing"), token.count > 6 {
            variants.insert(String(token.dropLast(3)))
        }

        if token.hasSuffix("ed"), token.count > 5 {
            variants.insert(String(token.dropLast(2)))
        }

        return variants
    }

    private func urgencyRank(_ urgency: AssistantProtocolUrgency) -> Int {
        switch urgency {
        case .emergency:
            3
        case .urgent:
            2
        case .planning:
            1
        }
    }

    private static func tokens(in normalizedQuery: String) -> [String] {
        normalizedQuery
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        if lhs == rhs {
            return 0
        }

        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)
        var distances = Array(0 ... rhsCharacters.count)

        for (lhsIndex, lhsCharacter) in lhsCharacters.enumerated() {
            var previousDistance = distances[0]
            distances[0] = lhsIndex + 1

            for (rhsIndex, rhsCharacter) in rhsCharacters.enumerated() {
                let currentDistance = distances[rhsIndex + 1]
                if lhsCharacter == rhsCharacter {
                    distances[rhsIndex + 1] = previousDistance
                } else {
                    distances[rhsIndex + 1] = min(
                        distances[rhsIndex] + 1,
                        currentDistance + 1,
                        previousDistance + 1
                    )
                }
                previousDistance = currentDistance
            }
        }

        return distances[rhsCharacters.count]
    }

    private static let bystanderFragments = [
        "someone",
        "somebody",
        "this person",
        "a person",
        "my friend",
        "my partner",
        "my dad",
        "my mum",
        "my mom",
        "my child",
        "my kid",
        "he s",
        "she s",
        "they re",
        "person not breathing",
        "person collapsed"
    ]
    private static let bystanderTokens = Set(["someone", "somebody", "person", "stranger", "friend", "partner"])
    private static let childFragments = ["child", "kid", "baby", "toddler", "infant", "newborn"]
    private static let childTokens = Set(["child", "kid", "baby", "toddler", "infant", "newborn", "teen"])
    private static let dependentFragments = ["elderly parent", "older person", "pregnant", "dependent", "family member"]
    private static let dependentTokens = Set(["dependent", "dependents", "elderly", "older", "pregnant", "disabled"])
    private static let petFragments = ["dog", "cat", "pet", "pets", "puppy", "kitten"]
    private static let petTokens = Set(["dog", "dogs", "cat", "cats", "pet", "pets", "puppy", "kitten"])
    private static let multipleCasualtyFragments = ["multiple casualties", "two injured", "several injured", "more than one person"]
    private static let noSignalFragments = ["no signal", "no phone service", "cant get signal", "can t get signal", "service down", "no reception"]
    private static let noGPSFragments = ["no gps", "gps not working", "without gps", "cant navigate", "can t navigate"]
    private static let noPowerFragments = ["power out", "power outage", "no power", "blackout", "power cut"]
    private static let noEquipmentFragments = ["no equipment", "dont have anything", "do not have anything", "nothing with me", "no kit", "no aed", "no epipen", "no inhaler"]
    private static let aedFragments = ["aed", "defibrillator"]
    private static let inhalerFragments = ["inhaler", "puffer"]
    private static let spacerFragments = ["spacer"]
    private static let epipenFragments = ["epipen", "epi pen", "adrenaline injector", "anapen"]
    private static let naloxoneFragments = ["naloxone", "narcan"]
    private static let smokeFragments = ["smoke", "ash", "embers", "can t breathe", "cant breathe"]
    private static let heatFragments = ["heat", "hot", "overheated", "heatstroke", "heat stroke", "heat exhaustion", "dehydrated"]
    private static let coldFragments = ["cold", "freezing", "hypothermia", "shivering"]
    private static let vehicleFragments = ["car", "vehicle", "ute", "truck", "breakdown", "stuck in car"]
    private static let waterExposureFragments = ["drowning", "pulled from water", "near water", "flood water", "jellyfish", "blue ringed", "octopus", "cone shell"]
    private static let poisoningFragments = ["poison", "overdose", "swallowed", "chemical", "drug", "tablets", "pills", "bitten by unknown"]
    private static let swallowedSubstanceFragments = ["swallowed", "ate", "drank chemical", "ingested", "took too many", "took extra"]
    private static let chemicalExposureFragments = ["chemical in eye", "chemical on skin", "chemical exposure", "bleach", "petrol", "gasoline"]
    private static let loneUserFragments: Set<String> = ["alone", "on my own", "by myself"]
    private static let fastPathFragments = [
        "not breathing",
        "unresponsive",
        "collapsed",
        "choking",
        "severe bleeding",
        "bleeding badly",
        "asthma attack",
        "anaphylaxis",
        "stroke",
        "heart attack",
        "overdose",
        "snake bite",
        "jellyfish",
        "drowning",
        "heat stroke",
        "water entering house",
        "flood water",
        "smoke everywhere",
        "stuck in car",
        "no gps"
    ]
}

private extension AssistantProtocolQueryContext {
    var isEducationalPrompt: Bool {
        let planningLeads = [
            "how do i",
            "how to",
            "show me",
            "teach me",
            "what are the steps for"
        ]

        return planningLeads.contains { normalizedQuery.hasPrefix($0) }
            && !flags.contains(.bystander)
            && !isGenericHighRisk
    }

    var isGenericHighRisk: Bool {
        normalizedQuery.containsAny([
            "what do i do",
            "what should i do",
            "help me",
            "help",
            "what now",
            "something feels wrong",
            "need help now",
            "right now"
        ])
    }

    var isMovementDecision: Bool {
        normalizedQuery.containsAny([
            "should i leave",
            "do i need to leave",
            "is it safe to leave",
            "leave or stay",
            "should we leave",
            "should we evacuate"
        ])
    }
}

private extension String {
    func containsAny(_ fragments: [String]) -> Bool {
        fragments.contains(where: contains)
    }
}

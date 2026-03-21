import Foundation

enum AssistantMedicalProtocolCatalog {
    static func build() -> [AssistantProtocolDefinition] {
        [
            medical(
                id: "cpr_not_breathing",
                displayName: "CPR / not breathing",
                topic: .cpr,
                urgency: .emergency,
                triggerTerms: [
                    "not breathing", "not responding", "unresponsive", "unconscious", "cpr",
                    "collapsed not breathing", "person not breathing", "someone collapsed"
                ],
                alternateTriggerPhrases: [
                    "stopped breathing", "no pulse", "not waking up", "not breathing after collapse"
                ],
                triggerTokenGroups: [
                    ["not", "breathing"],
                    ["person", "collapsed"],
                    ["unresponsive"],
                    ["start", "cpr"]
                ],
                summary: "A person who is unresponsive and not breathing normally needs emergency help and CPR now.",
                whatMatters: "If the person is not responding and is not breathing normally, start CPR immediately and send for an AED if one is nearby.",
                steps: [
                    "Call 000 now or send someone to call and bring an AED if available.",
                    "Place the person flat on their back and start chest compressions in the centre of the chest.",
                    "Use the AED as soon as it arrives and follow its voice prompts."
                ],
                avoid: [
                    "Do not delay CPR while checking for detailed signs or searching for equipment."
                ],
                emergencyEscalation: "Continue CPR until the person responds, an AED tells you to pause, or emergency services take over.",
                confidenceBoundary: "Treat this as a recognition-based emergency response. If you are not sure, follow the CPR path and call 000.",
                disclaimers: [
                    "Rescue breaths should only be added if you are trained and willing.",
                    "If the scene is unsafe, move only enough to reach safety."
                ],
                equipmentReferences: [
                    equipment("AED", "Use it as soon as it arrives and follow the voice prompts.")
                ],
                childNote: "If the patient is a child or infant and you know child-specific CPR, use it. If you do not, start standard CPR and call 000.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child, .multipleCasualties],
                safeFallbackPolicy: .emergencyEscalationOnly,
                relatedGuideIDs: ["cpr_basics"],
                groundingGuideID: "cpr_basics",
                verificationStatus: .guideGrounded,
                reviewSources: [.anzcor, .australianResuscitationCouncil, .stJohnAustralia],
                regionScope: .australia
            ),
            medical(
                id: "choking",
                displayName: "Choking",
                topic: .medicalEmergency,
                urgency: .emergency,
                triggerTerms: ["choking", "cant breathe food", "airway blocked", "child choking"],
                alternateTriggerPhrases: ["something stuck in throat", "cant cough", "cannot breathe"],
                triggerTokenGroups: [["child", "choking"], ["airway", "blocked"], ["cant", "breathe"]],
                summary: "Complete choking can stop breathing within minutes.",
                whatMatters: "If the person cannot cough, speak, or breathe properly, treat it as severe choking and act now.",
                steps: [
                    "Call 000 if the blockage does not clear immediately or the person is getting weaker.",
                    "Encourage coughing if they can still cough or speak. If the airway is completely blocked, give back blows and chest thrusts following current Australian first-aid guidance.",
                    "If the person becomes unresponsive, start CPR."
                ],
                avoid: [
                    "Do not give food or drink while the airway may still be blocked.",
                    "Do not leave the person alone."
                ],
                emergencyEscalation: "Call 000 immediately if the person becomes unresponsive, blue, or cannot move air.",
                confidenceBoundary: "If you are not sure whether this is severe choking, treat inability to cough or speak as an emergency.",
                disclaimers: [
                    "Counts and technique must be verified against current ANZCOR choking guidance before release."
                ],
                childNote: "For infants and children, use child-specific choking technique if you know it. If you do not, call 000 and follow dispatcher instructions.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.anzcor, .stJohnAustralia],
                regionScope: .australia
            ),
            medical(
                id: "severe_bleeding",
                displayName: "Severe bleeding",
                topic: .majorBleeding,
                urgency: .emergency,
                triggerTerms: ["bleeding badly", "severe bleeding", "hemorrhage", "bleeding out", "blood everywhere"],
                alternateTriggerPhrases: ["major bleeding", "wont stop bleeding", "won't stop bleeding"],
                triggerTokenGroups: [["bleeding", "badly"], ["severe", "bleeding"], ["bleeding", "out"]],
                summary: "Heavy bleeding can become life-threatening very quickly.",
                whatMatters: "Control the bleeding first and call 000 if it is severe, spurting, or not stopping.",
                steps: [
                    "Apply firm direct pressure over the wound with a dressing or the cleanest cloth you have.",
                    "Add more padding on top if blood soaks through and keep pressure in place.",
                    "Secure the dressing and call 000 if the bleeding is severe or does not stop."
                ],
                avoid: [
                    "Do not remove the first dressing just to check the wound if bleeding is still active."
                ],
                emergencyEscalation: "Call 000 if the bleeding is heavy, spurting, or the person becomes pale, confused, or weak.",
                confidenceBoundary: "If bleeding looks severe or you are unsure, treat it as a life-threatening bleed until emergency services say otherwise.",
                equipmentReferences: [
                    equipment("Gloves", "Use gloves if available, but do not delay pressure if bleeding is severe.")
                ],
                childNote: "Children can deteriorate quickly. Escalate early if bleeding is hard to control.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .multipleCasualties, .child, .noEquipment],
                safeFallbackPolicy: .emergencyEscalationOnly,
                relatedGuideIDs: ["major_bleeding_control"],
                groundingGuideID: "major_bleeding_control",
                verificationStatus: .guideGrounded,
                reviewSources: [.anzcor, .stJohnAustralia],
                regionScope: .australia
            ),
            medical(
                id: "asthma_attack",
                displayName: "Asthma attack",
                topic: .asthmaAttack,
                urgency: .emergency,
                triggerTerms: ["asthma attack", "cant breathe asthma", "wheezing", "inhaler not helping"],
                alternateTriggerPhrases: ["short of breath asthma", "tight chest asthma"],
                triggerTokenGroups: [["asthma", "attack"], ["wheezing"], ["tight", "chest"]],
                summary: "A severe asthma attack can become life-threatening quickly.",
                whatMatters: "Sit the person upright, help with their reliever medicine if they have it, and call 000 if they are struggling to breathe or not improving.",
                steps: [
                    "Sit the person upright and keep them as calm as possible.",
                    "Help them use their reliever inhaler and spacer if it is their prescribed medicine and they have it with them.",
                    "Call 000 if breathing is hard work, speech is limited, lips are blue, or the reliever is not helping."
                ],
                avoid: [
                    "Do not force the person to lie flat.",
                    "Do not leave them alone if breathing is worsening."
                ],
                emergencyEscalation: "Call 000 immediately if the person is exhausted, cannot speak in full sentences, turns blue, or stops improving.",
                confidenceBoundary: "If you are unsure whether this is asthma or another breathing emergency, call 000 and follow dispatcher instructions.",
                equipmentReferences: [
                    equipment("Reliever inhaler", "Use only the person's own reliever medicine if available."),
                    equipment("Spacer", "Use a spacer if one is available.")
                ],
                childNote: "Children can worsen quickly. Escalate early if a child is struggling to breathe.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                relatedGuideIDs: ["asthma_attack_response"],
                groundingGuideID: "asthma_attack_response",
                verificationStatus: .guideGrounded,
                reviewSources: [.anzcor, .stJohnAustralia],
                regionScope: .australia
            ),
            medical(
                id: "anaphylaxis",
                displayName: "Anaphylaxis / severe allergic reaction",
                topic: .medicalEmergency,
                urgency: .emergency,
                triggerTerms: ["anaphylaxis", "allergic reaction", "epi pen", "epipen", "throat swelling allergy"],
                alternateTriggerPhrases: ["face swelling allergy", "severe allergy", "cant breathe allergic reaction"],
                triggerTokenGroups: [["severe", "allergy"], ["allergic", "reaction"], ["throat", "swelling"]],
                summary: "Anaphylaxis is a medical emergency that can worsen very quickly.",
                whatMatters: "If the person has breathing trouble, throat swelling, collapse, or widespread allergy symptoms, call 000 and use their adrenaline auto-injector if available.",
                steps: [
                    "Call 000 immediately and tell them you suspect anaphylaxis.",
                    "Help the person use their adrenaline auto-injector if it is available and prescribed for them.",
                    "Keep them lying flat if possible and be ready to start CPR if they stop breathing normally."
                ],
                avoid: [
                    "Do not let the person walk around if they feel faint.",
                    "Do not delay emergency help while looking for the trigger."
                ],
                emergencyEscalation: "Call 000 now. If symptoms are severe or getting worse, treat this as time-critical.",
                confidenceBoundary: "If you are not sure whether it is anaphylaxis, act on severe breathing trouble, throat swelling, or collapse and call 000.",
                equipmentReferences: [
                    equipment("Adrenaline auto-injector", "Use the person's prescribed device if available.")
                ],
                childNote: "For children, treat severe swelling, wheeze, or sudden collapse as urgent and call 000.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.anzcor, .stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "seizure",
                displayName: "Seizure",
                topic: .medicalEmergency,
                urgency: .urgent,
                triggerTerms: ["seizure", "fit", "convulsing", "shaking and unresponsive"],
                alternateTriggerPhrases: ["having a fit", "jerking movements"],
                triggerTokenGroups: [["having", "fit"], ["jerking", "movements"], ["shaking", "unresponsive"]],
                summary: "Protect the person from injury and watch their breathing.",
                whatMatters: "Most seizures stop on their own, but you need to protect the person, time it, and call 000 if it is prolonged, repeated, or followed by breathing trouble.",
                steps: [
                    "Move dangers away, cushion the head, and time the seizure.",
                    "Do not restrain the person or put anything in their mouth.",
                    "When the jerking stops and they are breathing, place them on their side and call 000 if the seizure is prolonged, repeated, or the first known seizure."
                ],
                avoid: [
                    "Do not try to hold them still.",
                    "Do not put food, drink, or objects in their mouth."
                ],
                emergencyEscalation: "Call 000 if the seizure lasts a long time, repeats, happens in water, follows an injury, or the person is not breathing normally afterwards.",
                confidenceBoundary: "If the person is not recovering or you are unsure what caused the collapse, escalate to 000 early.",
                childNote: "Children with seizures can deteriorate quickly if breathing is affected. Escalate early if you are worried.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "heart_attack",
                displayName: "Heart attack symptoms",
                topic: .medicalEmergency,
                urgency: .emergency,
                triggerTerms: ["heart attack", "chest pain", "crushing chest pain", "pain down arm", "tight chest and sweating"],
                alternateTriggerPhrases: ["heart pain", "chest pressure", "cardiac symptoms"],
                triggerTokenGroups: [["chest", "pain"], ["pain", "arm"], ["chest", "pressure"]],
                summary: "Chest pain with sweating, nausea, or arm/jaw pain may be a heart attack.",
                whatMatters: "Call 000 early, keep the person resting, and watch for collapse or breathing changes.",
                steps: [
                    "Call 000 immediately if you suspect a heart attack.",
                    "Sit the person at rest and reassure them while waiting for help.",
                    "If they collapse and stop breathing normally, start CPR and use an AED if one is available."
                ],
                avoid: [
                    "Do not let the person push through the pain or walk around.",
                    "Do not give food or drink if they feel unwell."
                ],
                emergencyEscalation: "Call 000 now. Time matters with suspected heart attack.",
                confidenceBoundary: "Do not wait for certainty. Treat persistent chest pain with other warning signs as a medical emergency.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "stroke",
                displayName: "Stroke signs",
                topic: .medicalEmergency,
                urgency: .emergency,
                triggerTerms: ["stroke", "face droop", "slurred speech", "arm weakness", "fast stroke"],
                alternateTriggerPhrases: ["possible stroke", "cant smile one side", "speech suddenly slurred"],
                triggerTokenGroups: [["slurred", "speech"], ["arm", "weakness"], ["face", "droop"]],
                summary: "Sudden face droop, arm weakness, or speech change may be a stroke.",
                whatMatters: "Call 000 immediately and note when the signs started.",
                steps: [
                    "Call 000 and say you suspect a stroke.",
                    "Note the time the symptoms were first noticed and keep the person at rest.",
                    "Do not give food or drink while speech or swallowing may be affected."
                ],
                avoid: [
                    "Do not wait to see if the symptoms pass."
                ],
                emergencyEscalation: "Call 000 now. Fast treatment matters with suspected stroke.",
                confidenceBoundary: "If stroke signs appeared suddenly, treat it as urgent even if you are not certain.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "opioid_overdose",
                displayName: "Opioid overdose / unresponsive after drugs",
                topic: .poisoningExposure,
                urgency: .emergency,
                triggerTerms: ["overdose", "opiod overdose", "opioid overdose", "unresponsive after drugs", "not breathing after drugs"],
                alternateTriggerPhrases: ["took too many pills", "heroin overdose", "drug overdose"],
                triggerTokenGroups: [["after", "drugs"], ["drug", "overdose"], ["not", "breathing"]],
                summary: "Unresponsiveness, slow breathing, or blue lips after drug use is a medical emergency.",
                whatMatters: "Call 000, support breathing, and use naloxone if it is available and you know how to use it.",
                steps: [
                    "Call 000 immediately and say the person may have overdosed.",
                    "If the person is not breathing normally, start CPR.",
                    "Use naloxone if it is available and you know how to use that product."
                ],
                avoid: [
                    "Do not leave the person alone or assume they will sleep it off."
                ],
                emergencyEscalation: "Call 000 now. Slow or absent breathing after drugs is time-critical.",
                confidenceBoundary: "If the person is hard to wake, breathing slowly, or blue around the lips, treat it as an overdose emergency.",
                equipmentReferences: [
                    equipment("Naloxone", "Use it if it is available and you know how to use that product.")
                ],
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "drowning_not_breathing",
                displayName: "Pulled from water / not breathing",
                topic: .medicalEmergency,
                urgency: .emergency,
                triggerTerms: ["drowning", "pulled from water", "not breathing after water", "water rescue not breathing"],
                alternateTriggerPhrases: ["near drowning", "rescued from water"],
                triggerTokenGroups: [["pulled", "water"], ["water", "rescue"], ["not", "breathing"]],
                summary: "Someone pulled from water who is not breathing normally needs CPR and emergency help now.",
                whatMatters: "Call 000, start CPR if the person is not breathing normally, and use an AED if available.",
                steps: [
                    "Call 000 immediately and move to the safest place you can reach them.",
                    "If the person is not breathing normally, start CPR straight away.",
                    "Use an AED if one is available and follow its prompts."
                ],
                avoid: [
                    "Do not delay CPR while trying to clear large amounts of water."
                ],
                emergencyEscalation: "Call 000 now and continue care until emergency services take over.",
                confidenceBoundary: "If you cannot confirm normal breathing after a water incident, follow the CPR path and call 000.",
                equipmentReferences: [
                    equipment("AED", "Use it as soon as possible if it is available.")
                ],
                childNote: "Children pulled from water need urgent escalation even if they seem to recover.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child, .waterExposure],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.anzcor, .stJohnAustralia, .surfLifeSavingAustralia],
                regionScope: .australia
            ),
            medical(
                id: "diabetic_emergency",
                displayName: "Diabetic emergency / suspected low blood sugar",
                topic: .medicalEmergency,
                urgency: .urgent,
                triggerTerms: ["diabetic emergency", "low blood sugar", "hypo", "blood sugar low", "diabetic collapsed"],
                alternateTriggerPhrases: ["sugar low diabetes", "confused diabetic"],
                triggerTokenGroups: [["low", "blood", "sugar"], ["diabetic", "collapsed"]],
                summary: "Confusion, shakiness, or collapse in a person with diabetes can be urgent.",
                whatMatters: "If the person is awake and can swallow, treat possible low blood sugar early. If they are drowsy, not swallowing, or collapse, call 000.",
                steps: [
                    "If the person is awake and can swallow safely, give a fast-acting sugary drink or food.",
                    "Stay with them and watch for improvement.",
                    "Call 000 if they are not improving, become drowsy, or cannot swallow."
                ],
                avoid: [
                    "Do not give food or drink if the person is unconscious or cannot swallow safely."
                ],
                emergencyEscalation: "Call 000 if the person becomes less responsive, has a seizure, or cannot swallow.",
                confidenceBoundary: "If you are not sure whether it is diabetes or another cause of collapse, escalate early to 000.",
                childNote: "Children with diabetes can worsen quickly. Escalate early if symptoms are severe.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "shock_seriously_ill_person",
                displayName: "Shock / seriously ill person",
                topic: .medicalEmergency,
                urgency: .urgent,
                triggerTerms: ["shock", "pale clammy", "seriously ill person", "cold clammy weak"],
                alternateTriggerPhrases: ["faint pale weak", "after serious injury pale"],
                triggerTokenGroups: [["pale", "clammy"], ["cold", "clammy"], ["seriously", "ill"]],
                summary: "Shock can follow serious injury, bleeding, burns, infection, or medical collapse.",
                whatMatters: "Treat the cause you can see, keep the person at rest, and call 000 if they are getting weaker or seriously unwell.",
                steps: [
                    "Call 000 if the person is seriously ill, confused, or getting weaker.",
                    "Lay the person flat if safe, control bleeding if present, and keep them warm.",
                    "Watch their breathing and be ready to start CPR if they stop breathing normally."
                ],
                avoid: [
                    "Do not give food or drink to a seriously ill or injured person."
                ],
                emergencyEscalation: "Call 000 if the person is weak, confused, pale, clammy, or deteriorating after illness or injury.",
                confidenceBoundary: "If the person looks seriously unwell and you cannot explain it, escalate early to 000.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .multipleCasualties],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "burns_scalds",
                displayName: "Burns / scalds",
                topic: .burns,
                urgency: .urgent,
                triggerTerms: ["burn", "burned", "burnt", "scald", "hot water burn"],
                alternateTriggerPhrases: ["flame burn", "steam burn"],
                triggerTokenGroups: [["hot", "water", "burn"], ["burn"]],
                summary: "Burns need cooling early to limit damage.",
                whatMatters: "Cool the burn under cool running water and seek help early for large, deep, airway, facial, chemical, or electrical burns.",
                steps: [
                    "Cool the burn under cool running water for 20 minutes if possible.",
                    "Remove jewellery and tight clothing unless it is stuck to the burn.",
                    "Cover it loosely with a clean non-stick dressing and seek medical care if the burn is serious."
                ],
                avoid: [
                    "Do not use ice, butter, creams, or home remedies on a fresh burn."
                ],
                emergencyEscalation: "Call 000 for airway burns, major burns, or electrical burns.",
                confidenceBoundary: "If the burn is large, deep, on the face, hands, genitals, or affects breathing, escalate early.",
                shouldPrioritizePrimaryAction: false,
                primaryAction: .none,
                contextInjectors: [.bystander, .child, .noWater],
                safeFallbackPolicy: .contextDriven,
                relatedGuideIDs: ["burns_first_aid"],
                groundingGuideID: "burns_first_aid",
                verificationStatus: .guideGrounded,
                reviewSources: [.anzcor, .stJohnAustralia],
                regionScope: .australia
            ),
            medical(
                id: "fracture_suspected",
                displayName: "Suspected fracture",
                topic: .traumaInjury,
                urgency: .urgent,
                triggerTerms: ["fracture", "broken bone", "suspected broken bone", "cant move arm after fall", "bone injury"],
                alternateTriggerPhrases: ["might be broken", "deformed limb"],
                triggerTokenGroups: [["broken", "bone"], ["suspected", "fracture"], ["deformed", "limb"]],
                summary: "Suspected fractures need rest and support so the injury does not worsen.",
                whatMatters: "Support the injured area, keep movement low, and seek urgent help for deformity, severe pain, or circulation problems.",
                steps: [
                    "Support the injured limb in the position found.",
                    "Immobilise it with a sling, padding, or support if you can do so gently.",
                    "Seek urgent medical help if the limb is badly deformed, numb, or the pain is severe."
                ],
                avoid: [
                    "Do not force the limb straight."
                ],
                emergencyEscalation: "Call 000 if there is heavy bleeding, major deformity, loss of feeling, or other serious injuries.",
                confidenceBoundary: "If you suspect a fracture, treat it gently as broken until medical assessment says otherwise.",
                shouldPrioritizePrimaryAction: false,
                primaryAction: .none,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .contextDriven,
                relatedGuideIDs: ["fracture_immobilisation"],
                groundingGuideID: "fracture_immobilisation",
                verificationStatus: .guideGrounded,
                reviewSources: [.stJohnAustralia],
                regionScope: .australia
            ),
            medical(
                id: "sprain_strain",
                displayName: "Sprain / strain",
                topic: .traumaInjury,
                urgency: .urgent,
                triggerTerms: ["sprain", "strain", "rolled ankle", "twisted knee", "pulled muscle"],
                alternateTriggerPhrases: ["twisted ankle", "soft tissue injury"],
                triggerTokenGroups: [["rolled", "ankle"], ["twisted", "ankle"], ["pulled", "muscle"]],
                summary: "Support the injury and reduce movement early.",
                whatMatters: "Rest and support the injured area, use cold wrapped in cloth, and seek assessment if the person cannot bear weight or the injury looks severe.",
                steps: [
                    "Rest the injured area and stop the activity.",
                    "Apply a cold pack wrapped in cloth and support the joint or muscle.",
                    "Seek medical assessment if there is severe swelling, deformity, or the person cannot use the limb."
                ],
                avoid: [
                    "Do not force painful movement."
                ],
                emergencyEscalation: nil,
                confidenceBoundary: "If the joint looks deformed or the person cannot use it, treat it like a fracture and escalate care.",
                shouldPrioritizePrimaryAction: false,
                primaryAction: .none,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .contextDriven,
                reviewSources: [.stJohnAustralia],
                regionScope: .general
            ),
            medical(
                id: "head_injury",
                displayName: "Head injury",
                topic: .traumaInjury,
                urgency: .urgent,
                triggerTerms: ["head injury", "hit head", "concussion", "head knock", "head trauma"],
                alternateTriggerPhrases: ["fell and hit head", "bumped head and vomiting"],
                triggerTokenGroups: [["hit", "head"], ["head", "injury"], ["head", "trauma"]],
                summary: "Any significant head injury needs careful observation and early escalation if symptoms worsen.",
                whatMatters: "Keep the person resting and call 000 if there is loss of consciousness, seizure, repeated vomiting, worsening headache, or confusion.",
                steps: [
                    "Stop activity and keep the person resting.",
                    "Watch for confusion, vomiting, worsening headache, seizure, or unusual drowsiness.",
                    "Call 000 if the person was knocked unconscious or any serious symptoms are present."
                ],
                avoid: [
                    "Do not send the person back to sport, work, or driving if symptoms are ongoing."
                ],
                emergencyEscalation: "Call 000 for unconsciousness, seizure, repeated vomiting, worsening confusion, or severe mechanism of injury.",
                confidenceBoundary: "If the person is getting worse or you are worried, escalate early.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .general
            ),
            medical(
                id: "spinal_injury_suspicion",
                displayName: "Spinal injury suspicion",
                topic: .traumaInjury,
                urgency: .emergency,
                triggerTerms: ["spinal injury", "neck injury", "back injury after fall", "cant feel legs", "suspected spine"],
                alternateTriggerPhrases: ["high fall neck pain", "crash neck pain"],
                triggerTokenGroups: [["spinal", "injury"], ["neck", "injury"], ["cant", "feel", "legs"]],
                summary: "Possible spinal injury means movement should be kept to an absolute minimum.",
                whatMatters: "Call 000, keep the person still, and support the head and neck in the position found unless the scene is unsafe.",
                steps: [
                    "Call 000 immediately.",
                    "Tell the person not to move and support the head and neck gently in the position found.",
                    "Only move them if there is immediate danger and you have no safer option."
                ],
                avoid: [
                    "Do not twist, sit up, or roll the person unless you must for immediate danger or airway needs."
                ],
                emergencyEscalation: "Call 000 now for suspected spinal injury, numbness, weakness, or major mechanism of injury.",
                confidenceBoundary: "If there is serious neck or back pain after a crash, fall, dive, or collapse, treat it as possible spinal injury.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .multipleCasualties],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .general
            ),
            medical(
                id: "crush_injury_suspicion",
                displayName: "Crush injury suspicion",
                topic: .traumaInjury,
                urgency: .emergency,
                triggerTerms: ["crush injury", "pinned under", "heavy object on leg", "trapped under"],
                alternateTriggerPhrases: ["crushed limb", "vehicle crush"],
                triggerTokenGroups: [["crush", "injury"], ["heavy", "object"], ["trapped", "under"]],
                summary: "Crush injury can be serious even when the wound is not obvious.",
                whatMatters: "Call 000, keep the person still, and do not remove a heavy object unless it is needed for immediate safety.",
                steps: [
                    "Call 000 immediately.",
                    "Do not move the heavy object unless leaving it in place creates greater danger.",
                    "Control external bleeding you can see and keep the person still and warm while waiting for help."
                ],
                avoid: [
                    "Do not pull a trapped person free without emergency support unless the scene is immediately life-threatening."
                ],
                emergencyEscalation: "Call 000 now for any trapped or heavily crushed limb, chest, abdomen, or pelvis.",
                confidenceBoundary: "If someone has been pinned or crushed and you are unsure how badly, treat it as a serious trauma emergency.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .multipleCasualties, .vehicle],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .general
            ),
            medical(
                id: "eye_injury_or_chemical_exposure",
                displayName: "Eye injury / chemical in eye",
                topic: .traumaInjury,
                urgency: .urgent,
                triggerTerms: ["eye injury", "chemical in eye", "something in eye", "acid in eye", "eye splashed"],
                alternateTriggerPhrases: ["foreign body eye", "eye burn", "chemical splash eye"],
                triggerTokenGroups: [["chemical", "eye"], ["something", "eye"], ["eye", "splashed"]],
                summary: "Eye injuries can worsen quickly, especially with chemicals or embedded objects.",
                whatMatters: "Flush chemicals with clean running water and get urgent medical help. If an object is stuck in the eye, do not remove it.",
                steps: [
                    "If there is chemical exposure, flush the eye continuously with clean running water.",
                    "If an object is embedded, do not remove it. Cover the eye lightly without pressure.",
                    "Seek urgent medical help or call 000 if the injury is severe, the pain is intense, or vision is affected."
                ],
                avoid: [
                    "Do not rub the eye.",
                    "Do not try to remove an embedded object."
                ],
                emergencyEscalation: "Call 000 for severe eye trauma, significant chemical exposure, or sudden loss of vision.",
                confidenceBoundary: "When vision changes, severe pain, or chemical exposure are present, treat the eye injury as urgent.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .chemicalExposure],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia, .poisonsInformationCentre],
                regionScope: .australia
            ),
            medical(
                id: "nosebleed",
                displayName: "Nosebleed",
                topic: .traumaInjury,
                urgency: .urgent,
                triggerTerms: ["nosebleed", "nose bleed", "bleeding nose"],
                alternateTriggerPhrases: ["blood from nose"],
                triggerTokenGroups: [["nose", "bleed"], ["bleeding", "nose"]],
                summary: "Most nosebleeds can be controlled with simple pressure.",
                whatMatters: "Sit the person leaning forward and pinch the soft part of the nose continuously.",
                steps: [
                    "Sit the person leaning forward.",
                    "Pinch the soft part of the nose and hold steady pressure.",
                    "Seek medical help if the bleeding is heavy, follows major trauma, or does not settle."
                ],
                avoid: [
                    "Do not tilt the head back."
                ],
                emergencyEscalation: "Call 000 if there is major trauma, collapse, or bleeding that is severe and ongoing.",
                confidenceBoundary: "Treat nosebleeds after significant facial injury more cautiously than simple spontaneous bleeding.",
                shouldPrioritizePrimaryAction: false,
                primaryAction: .none,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .contextDriven,
                reviewSources: [.stJohnAustralia],
                regionScope: .general
            ),
            medical(
                id: "embedded_or_impaled_object",
                displayName: "Embedded / impaled object",
                topic: .traumaInjury,
                urgency: .emergency,
                triggerTerms: ["impaled", "embedded object", "object stuck in", "knife in", "metal in leg"],
                alternateTriggerPhrases: ["stick through arm", "object lodged in wound"],
                triggerTokenGroups: [["embedded", "object"], ["object", "stuck"], ["knife", "in"]],
                summary: "An embedded object can worsen bleeding if it is removed.",
                whatMatters: "Do not remove the object. Control bleeding around it, stabilise it, and call 000.",
                steps: [
                    "Call 000 if the object is deeply embedded or the wound is severe.",
                    "Do not remove the object.",
                    "Control bleeding around the object and support it so it does not move."
                ],
                avoid: [
                    "Do not pull out the object."
                ],
                emergencyEscalation: "Call 000 for deep, large, or chest, neck, abdomen, or eye impalements.",
                confidenceBoundary: "If the object is deeply embedded or you cannot control bleeding around it, treat it as an emergency.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .multipleCasualties],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia],
                regionScope: .general
            ),
            medical(
                id: "snake_bite_australia",
                displayName: "Snake bite (Australia)",
                topic: .snakeBite,
                urgency: .emergency,
                triggerTerms: ["snake bite", "bit by snake", "venomous snake", "snakebite"],
                alternateTriggerPhrases: ["snake got him", "snake got her"],
                triggerTokenGroups: [["snake", "bite"], ["bit", "snake"]],
                summary: "Suspected snake bite in Australia needs pressure immobilisation and urgent help.",
                whatMatters: "Keep the person still, apply pressure immobilisation, and call 000.",
                steps: [
                    "Keep the person lying still and calm.",
                    "Apply a pressure bandage over the bite and up the whole limb if you can.",
                    "Immobilise the limb and call 000."
                ],
                avoid: [
                    "Do not wash the bite, cut it, suck it, or apply a tourniquet.",
                    "Do not let the person walk."
                ],
                emergencyEscalation: "Call 000 now for any suspected venomous snake bite in Australia.",
                confidenceBoundary: "If you are not sure what bit the person but snake bite is possible, use the snake-bite pathway and call 000.",
                childNote: "Children can deteriorate quickly after snake bite. Keep them still and escalate immediately.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                relatedGuideIDs: ["snake_bite_first_aid"],
                groundingGuideID: "snake_bite_first_aid",
                verificationStatus: .guideGrounded,
                reviewSources: [.anzcor, .stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "spider_bite_australia",
                displayName: "Spider bite (Australia)",
                topic: .biteStingToxin,
                urgency: .urgent,
                triggerTerms: ["spider bite", "bit by spider", "funnel web bite", "redback bite"],
                alternateTriggerPhrases: ["spider got me", "spider got him"],
                triggerTokenGroups: [["spider", "bite"], ["bit", "spider"]],
                summary: "Most spider bites need symptom watching, but some Australian bites need urgent escalation.",
                whatMatters: "Wash the area, use a cold pack for pain, and call 000 if there is collapse, breathing trouble, severe pain, or concern for funnel-web spider.",
                steps: [
                    "Wash the bite site if it is safe to do so.",
                    "Use a cold pack wrapped in cloth for pain and swelling.",
                    "Call 000 if there are severe symptoms, collapse, breathing trouble, or concern about a funnel-web bite."
                ],
                avoid: [
                    "Do not cut the bite or apply a tourniquet."
                ],
                emergencyEscalation: "Call 000 immediately for severe symptoms or suspected funnel-web bite.",
                confidenceBoundary: "If you cannot identify the spider and symptoms are severe, escalate early.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "tick_bite",
                displayName: "Tick bite",
                topic: .biteStingToxin,
                urgency: .urgent,
                triggerTerms: ["tick bite", "tick on skin", "paralysis tick"],
                alternateTriggerPhrases: ["tick attached", "found a tick"],
                triggerTokenGroups: [["tick", "bite"], ["paralysis", "tick"]],
                summary: "Tick bites can trigger allergy or serious illness in some people.",
                whatMatters: "Avoid disturbing the tick, watch for allergy symptoms, and get urgent help if breathing trouble or collapse occurs.",
                steps: [
                    "Do not squeeze, scratch, or pull at the tick roughly.",
                    "Watch for swelling, breathing trouble, or collapse and call 000 if those occur.",
                    "Seek local medical advice for safe removal or management, especially in paralysis tick areas."
                ],
                avoid: [
                    "Do not squeeze the tick's body or apply rough force."
                ],
                emergencyEscalation: "Call 000 for breathing trouble, collapse, or severe allergy symptoms after a tick bite.",
                confidenceBoundary: "Tick management varies with allergy risk and location. If symptoms are severe, escalate rather than improvising.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.healthdirectAustralia, .stJohnAustralia],
                regionScope: .australia
            ),
            medical(
                id: "bee_wasp_ant_sting",
                displayName: "Bee / wasp / ant sting",
                topic: .biteStingToxin,
                urgency: .urgent,
                triggerTerms: ["bee sting", "wasp sting", "ant sting", "stung by bee", "stung by wasp"],
                alternateTriggerPhrases: ["insect sting", "stung by ant"],
                triggerTokenGroups: [["bee", "sting"], ["wasp", "sting"], ["ant", "sting"]],
                summary: "Most insect stings are minor, but severe allergy can escalate quickly.",
                whatMatters: "Remove the sting if you can do it quickly, use a cold pack, and watch for anaphylaxis.",
                steps: [
                    "If a sting is visible, remove it quickly by brushing or scraping it away.",
                    "Use a cold pack wrapped in cloth for pain and swelling.",
                    "Call 000 if there is breathing trouble, throat swelling, collapse, or other severe allergic symptoms."
                ],
                avoid: [
                    "Do not ignore signs of severe allergy after a sting."
                ],
                emergencyEscalation: "Call 000 for severe allergy symptoms or if the person has anaphylaxis.",
                confidenceBoundary: "If breathing or throat symptoms appear, switch immediately to the anaphylaxis pathway.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .general
            ),
            medical(
                id: "jellyfish_sting",
                displayName: "Jellyfish sting",
                topic: .biteStingToxin,
                urgency: .urgent,
                triggerTerms: ["jellyfish sting", "stung by jellyfish", "marine sting tentacles"],
                alternateTriggerPhrases: ["bluebottle sting", "box jellyfish sting"],
                triggerTokenGroups: [["jellyfish", "sting"], ["stung", "jellyfish"]],
                summary: "Marine stings can range from painful to life-threatening.",
                whatMatters: "Get out of the water, call 000 if there is collapse or breathing trouble, and follow local marine-sting first-aid guidance if lifeguards or signage are present.",
                steps: [
                    "Move the person out of the water and call 000 for collapse, breathing trouble, or severe pain.",
                    "Avoid rubbing the sting area.",
                    "Use local beach or emergency guidance for the specific marine sting if known."
                ],
                avoid: [
                    "Do not rub the area or use random home remedies."
                ],
                emergencyEscalation: "Call 000 for collapse, breathing trouble, extensive stings, or severe pain.",
                confidenceBoundary: "Marine sting treatment varies by species. If the species is unknown and symptoms are significant, escalate early.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child, .waterExposure],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia, .surfLifeSavingAustralia],
                regionScope: .australia
            ),
            medical(
                id: "blue_ringed_octopus_or_cone_shell",
                displayName: "Blue-ringed octopus / cone shell",
                topic: .biteStingToxin,
                urgency: .emergency,
                triggerTerms: ["blue ringed octopus", "blue-ringed octopus", "cone shell", "cone snail"],
                alternateTriggerPhrases: ["bitten by blue ringed octopus", "cone shell sting"],
                triggerTokenGroups: [["blue", "ringed", "octopus"], ["cone", "shell"]],
                summary: "Blue-ringed octopus and cone shell stings are medical emergencies in Australia.",
                whatMatters: "Call 000, keep the person still, and use pressure immobilisation if possible.",
                steps: [
                    "Call 000 immediately.",
                    "Keep the person still and calm.",
                    "Apply pressure immobilisation to the affected limb if it is practical and safe to do so."
                ],
                avoid: [
                    "Do not let the person walk around."
                ],
                emergencyEscalation: "Call 000 now and be ready to start CPR if breathing stops.",
                confidenceBoundary: "If blue-ringed octopus or cone shell exposure is possible, treat it as urgent even if symptoms are not yet severe.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .waterExposure, .beach],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia, .surfLifeSavingAustralia],
                regionScope: .australia
            ),
            medical(
                id: "fish_or_marine_sting",
                displayName: "Fish sting / marine sting",
                topic: .biteStingToxin,
                urgency: .urgent,
                triggerTerms: ["fish sting", "stonefish", "stingray", "marine sting fish"],
                alternateTriggerPhrases: ["stepped on something in water", "spine in foot from fish"],
                triggerTokenGroups: [["fish", "sting"], ["stingray"], ["stonefish"]],
                summary: "Some fish and marine stings are very painful and can be serious.",
                whatMatters: "Call 000 for severe pain, collapse, or breathing trouble. Otherwise seek urgent medical help and follow local marine-sting guidance.",
                steps: [
                    "Get the person out of the water and into a safe place.",
                    "Call 000 if there is collapse, breathing trouble, or severe worsening pain.",
                    "Seek urgent medical help and follow local marine-sting guidance if available."
                ],
                avoid: [
                    "Do not ignore severe pain or worsening symptoms after a marine sting."
                ],
                emergencyEscalation: "Call 000 for breathing trouble, collapse, or severe systemic symptoms.",
                confidenceBoundary: "Marine sting treatment varies by species. Escalate early when severe pain or systemic symptoms are present.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .waterExposure, .beach],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia, .surfLifeSavingAustralia],
                regionScope: .australia
            ),
            medical(
                id: "poisoning_or_chemical_exposure",
                displayName: "Poisoning / swallowed substance / chemical exposure",
                topic: .poisoningExposure,
                urgency: .emergency,
                triggerTerms: ["poisoning", "swallowed chemical", "drank cleaner", "ate poison", "poisoned"],
                alternateTriggerPhrases: ["chemical exposure", "poison swallowed", "ingested cleaner"],
                triggerTokenGroups: [["swallowed", "chemical"], ["poison", "swallowed"], ["chemical", "exposure"]],
                summary: "Possible poisoning needs fast, source-specific advice.",
                whatMatters: "Call the Poisons Information Centre quickly and call 000 for collapse, seizure, breathing trouble, or severe symptoms.",
                steps: [
                    "Call the Poisons Information Centre on 13 11 26 as soon as possible.",
                    "Keep the product, plant, or container with you if you can do so safely.",
                    "Call 000 immediately if the person has breathing trouble, seizures, collapse, or is becoming less responsive."
                ],
                avoid: [
                    "Do not make the person vomit unless a clinician tells you to."
                ],
                emergencyEscalation: "Call 000 for collapse, seizures, breathing trouble, major chemical burns, or reduced consciousness.",
                confidenceBoundary: "If you are not sure what was swallowed or exposed, use the poisons pathway rather than guessing.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callPoisonsInformation,
                contextInjectors: [.bystander, .child, .chemicalExposure, .swallowedSubstance, .poisoning],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.poisonsInformationCentre, .stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "heat_illness",
                displayName: "Heat exhaustion / heat stroke",
                topic: .heatIllness,
                urgency: .emergency,
                triggerTerms: ["heat stroke", "heatstroke", "heat exhaustion", "overheated", "too hot and collapsed"],
                alternateTriggerPhrases: ["hot weather collapse", "exertional heat illness"],
                triggerTokenGroups: [["heat", "stroke"], ["heat", "exhaustion"], ["hot", "collapsed"]],
                summary: "Heat illness can progress from exhaustion to a medical emergency.",
                whatMatters: "Move the person to a cooler place, cool them, and call 000 if they are confused, collapse, stop sweating, or are not improving quickly.",
                steps: [
                    "Move the person to shade or a cooler place.",
                    "Start active cooling with cool water, wet cloths, and airflow if available.",
                    "Call 000 if the person is confused, collapsed, very hot, or not improving quickly."
                ],
                avoid: [
                    "Do not push the person to keep working or walking."
                ],
                emergencyEscalation: "Call 000 for suspected heat stroke, confusion, collapse, seizures, or reduced responsiveness.",
                confidenceBoundary: "If the person is confused, collapsed, or very hot, treat it as a heat-stroke emergency.",
                childNote: "Children and older adults can worsen quickly in heat. Escalate early if you are worried.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child, .heat],
                safeFallbackPolicy: .emergencyEscalationOnly,
                relatedGuideIDs: ["heat_exhaustion_vs_heatstroke", "prevent_dehydration_in_extreme_heat"],
                groundingGuideID: "heat_exhaustion_vs_heatstroke",
                verificationStatus: .guideGrounded,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "hypothermia",
                displayName: "Hypothermia / cold exposure",
                topic: .environmentalExposure,
                urgency: .urgent,
                triggerTerms: ["hypothermia", "too cold", "cold exposure", "shivering uncontrollably"],
                alternateTriggerPhrases: ["cold and confused", "wet and freezing"],
                triggerTokenGroups: [["cold", "exposure"], ["too", "cold"], ["wet", "freezing"]],
                summary: "Cold exposure can become serious when shivering, confusion, or drowsiness develop.",
                whatMatters: "Move the person to shelter, remove wet clothing, warm gradually, and call 000 if they are confused, drowsy, or not improving.",
                steps: [
                    "Move the person out of wind, rain, or cold water and remove wet clothing if you can do so safely.",
                    "Warm them gradually with dry layers and blankets.",
                    "Call 000 if they are confused, drowsy, not improving, or becoming less responsive."
                ],
                avoid: [
                    "Do not use extreme direct heat on a very cold person."
                ],
                emergencyEscalation: "Call 000 for confusion, reduced responsiveness, or severe cold exposure.",
                confidenceBoundary: "If the person is cold and mentally altered, treat it as urgent hypothermia until proved otherwise.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child, .cold, .waterExposure],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .general
            ),
            medical(
                id: "smoke_inhalation",
                displayName: "Smoke inhalation",
                topic: .environmentalExposure,
                urgency: .emergency,
                triggerTerms: ["smoke inhalation", "cant breathe smoke", "smoke everywhere", "breathing smoke"],
                alternateTriggerPhrases: ["inhaled smoke", "smoke exposure breathing"],
                triggerTokenGroups: [["smoke", "inhalation"], ["breathing", "smoke"], ["smoke", "everywhere"]],
                summary: "Breathing smoke can become serious quickly, especially with asthma, fire exposure, or enclosed spaces.",
                whatMatters: "Move to cleaner air if it is safe, call 000 for breathing trouble, and treat it as urgent if the person is getting worse.",
                steps: [
                    "Move the person away from smoke to the safest cleaner air you can reach.",
                    "Call 000 if breathing is hard work, noisy, worsening, or the person becomes confused.",
                    "If the person stops breathing normally, start CPR."
                ],
                avoid: [
                    "Do not send someone back through smoke for belongings."
                ],
                emergencyEscalation: "Call 000 for breathing trouble, collapse, facial burns, or severe smoke exposure.",
                confidenceBoundary: "If smoke exposure happened in an enclosed space or breathing is worsening, escalate early.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child, .smoke],
                safeFallbackPolicy: .emergencyEscalationOnly,
                relatedGuideIDs: ["smoke_exposure_reduction"],
                groundingGuideID: "smoke_exposure_reduction",
                verificationStatus: .guideGrounded,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .australia
            ),
            medical(
                id: "dehydration_medical",
                displayName: "Dehydration",
                topic: .environmentalExposure,
                urgency: .urgent,
                triggerTerms: ["dehydrated", "dehydration", "not enough water", "dry mouth dizzy", "cant keep fluids down"],
                alternateTriggerPhrases: ["very thirsty dizzy", "weak from no water"],
                triggerTokenGroups: [["dry", "mouth"], ["keep", "fluids"], ["no", "water"]],
                summary: "Dehydration can worsen quickly in heat, illness, and remote travel.",
                whatMatters: "Rest the person, cool them if needed, and give small drinks if they are awake and can swallow. Escalate if they are confused, collapsing, or not keeping fluids down.",
                steps: [
                    "Move the person to shade or a cooler place if heat is involved.",
                    "Give small sips of safe fluid if they are awake and can swallow.",
                    "Call 000 or seek urgent medical help if the person is confused, collapsing, or cannot keep fluids down."
                ],
                avoid: [
                    "Do not force fluids into someone who is vomiting, drowsy, or not swallowing safely."
                ],
                emergencyEscalation: "Call 000 for confusion, collapse, seizures, or inability to keep fluids down.",
                confidenceBoundary: "If dehydration is mixed with heat illness, collapse, or confusion, treat it as an emergency rather than simple thirst.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .child, .heat, .noWater],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .general
            ),
            medical(
                id: "hot_weather_collapse",
                displayName: "Exhaustion / collapse in hot weather",
                topic: .environmentalExposure,
                urgency: .emergency,
                triggerTerms: ["collapsed in heat", "collapsed in hot weather", "fainted in heat", "exhausted and collapsed"],
                alternateTriggerPhrases: ["collapsed after exertion in heat", "passed out in heat"],
                triggerTokenGroups: [["collapsed", "heat"], ["hot", "weather", "collapse"], ["passed", "out", "heat"]],
                summary: "Collapse in heat or after exertion can be life-threatening.",
                whatMatters: "Move the person out of heat, cool them, and call 000 early.",
                steps: [
                    "Move the person to shade or a cooler place and start active cooling.",
                    "Call 000 if the person collapsed, is confused, or is not recovering quickly.",
                    "Be ready to start CPR if normal breathing stops."
                ],
                avoid: [
                    "Do not send them back into heat or exertion."
                ],
                emergencyEscalation: "Call 000 for collapse, confusion, seizure, or reduced responsiveness in hot weather.",
                confidenceBoundary: "When someone collapses in heat, treat it as more serious than ordinary tiredness.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .callEmergency,
                contextInjectors: [.bystander, .heat],
                safeFallbackPolicy: .emergencyEscalationOnly,
                reviewSources: [.stJohnAustralia, .healthdirectAustralia],
                regionScope: .general
            )
        ]
    }
}

private extension AssistantMedicalProtocolCatalog {
    static func medical(
        id: String,
        displayName: String,
        topic: AssistantIntentTopic,
        urgency: AssistantProtocolUrgency,
        triggerTerms: [String],
        alternateTriggerPhrases: [String] = [],
        triggerTokenGroups: [[String]] = [],
        summary: String,
        whatMatters: String,
        steps: [String],
        avoid: [String],
        emergencyEscalation: String?,
        confidenceBoundary: String,
        disclaimers: [String] = [],
        equipmentReferences: [AssistantProtocolEquipmentReference] = [],
        childNote: String? = nil,
        suppressClarification: Bool = true,
        shouldPrioritizePrimaryAction: Bool = false,
        fastPathEligible: Bool = true,
        primaryAction: AssistantProtocolPrimaryAction = .none,
        contextInjectors: [AssistantProtocolContextInjector] = [],
        safeFallbackPolicy: AssistantProtocolFallbackPolicy = .contextDriven,
        relatedGuideIDs: [String] = [],
        groundingGuideID: String? = nil,
        verificationStatus: AssistantProtocolVerificationStatus = .sourceReviewRequired,
        reviewSources: [AssistantProtocolReviewSource] = [.anzcor, .stJohnAustralia],
        regionScope: AssistantRegionScope = .general
    ) -> AssistantProtocolDefinition {
        AssistantProtocolDefinition(
            id: id,
            displayName: displayName,
            domain: .medical,
            topic: topic,
            urgency: urgency,
            triggerTerms: triggerTerms,
            alternateTriggerPhrases: alternateTriggerPhrases,
            triggerTokenGroups: triggerTokenGroups,
            summary: summary,
            whatMatters: whatMatters,
            steps: steps,
            avoid: avoid,
            emergencyEscalation: emergencyEscalation,
            confidenceBoundary: confidenceBoundary,
            disclaimers: disclaimers,
            equipmentReferences: equipmentReferences,
            childNote: childNote,
            suppressClarification: suppressClarification,
            shouldPrioritizePrimaryAction: shouldPrioritizePrimaryAction,
            fastPathEligible: fastPathEligible,
            primaryAction: primaryAction,
            contextInjectors: contextInjectors,
            safeFallbackPolicy: safeFallbackPolicy,
            relatedGuideIDs: relatedGuideIDs,
            groundingGuideID: groundingGuideID,
            verificationStatus: verificationStatus,
            reviewSources: reviewSources,
            regionScope: regionScope
        )
    }

    static func equipment(_ label: String, _ note: String) -> AssistantProtocolEquipmentReference {
        AssistantProtocolEquipmentReference(label: label, note: note)
    }
}

import Foundation

enum AssistantSurvivalProtocolCatalog {
    static func build() -> [AssistantProtocolDefinition] {
        [
            // Water
            survival(
                id: "water_storage",
                displayName: "Drinking water storage",
                topic: .waterPlanning,
                urgency: .planning,
                triggerTerms: ["store water", "water storage", "drinking water storage"],
                alternateTriggerPhrases: ["keep water safely", "store water in heat"],
                triggerTokenGroups: [["water", "storage"], ["store", "water"]],
                summary: "Stored water is the first line of resilience when services fail.",
                whatMatters: "Store water early, keep it clean, and rotate it before quality drops.",
                steps: [
                    "Store potable water in clean food-grade containers.",
                    "Keep stored water out of direct heat and sunlight if you can.",
                    "Label and rotate stored water so older supplies are used first."
                ],
                avoid: ["Do not store drinking water in unclean or unknown containers."],
                confidenceBoundary: "Water storage advice depends on container hygiene and local heat conditions. If water looks or smells unsafe, treat it before use.",
                relatedGuideIDs: ["store_water_safely_in_heat"],
                groundingGuideID: "store_water_safely_in_heat",
                fastPathEligible: false,
                contextInjectors: [.dependents, .heat, .noWater]
            ),
            survival(
                id: "water_purification",
                displayName: "Water purification",
                topic: .waterPurification,
                urgency: .urgent,
                triggerTerms: ["purify water", "clean dirty water", "safe water now"],
                alternateTriggerPhrases: ["make water safe", "dirty creek water", "treat water"],
                triggerTokenGroups: [["purify", "water"], ["dirty", "water"]],
                summary: "Unsafe water can make an emergency worse very quickly.",
                whatMatters: "Use the safest purification method available and treat suspicious water before drinking.",
                steps: [
                    "If water is cloudy, let debris settle and remove what you can first.",
                    "Use boiling, filtration, or approved chemical treatment based on the equipment you have.",
                    "Store treated water in the cleanest container available."
                ],
                avoid: ["Do not assume clear water is safe to drink."],
                confidenceBoundary: "If you cannot treat the water properly, use the safest stored or known safe source instead.",
                relatedGuideIDs: ["boil_filter_disinfect_water", "after_flood_drinking_water_checks"],
                groundingGuideID: "boil_filter_disinfect_water",
                contextInjectors: [.noWater, .noPower],
                regionScope: .general
            ),
            survival(
                id: "boiling_water",
                displayName: "Boiling water",
                topic: .survivalWater,
                urgency: .urgent,
                triggerTerms: ["boil water", "boiling water safe", "can i boil water"],
                alternateTriggerPhrases: ["make water safe by boiling"],
                triggerTokenGroups: [["boil", "water"]],
                summary: "Boiling is a strong option when fuel and a safe heat source are available.",
                whatMatters: "Use boiling when you can do it safely and you have enough fuel and time.",
                steps: [
                    "Filter or settle cloudy water first if possible.",
                    "Bring the water to a rolling boil using a safe heat source.",
                    "Let it cool in a clean covered container before drinking."
                ],
                avoid: ["Do not waste scarce fuel boiling obviously contaminated water if a safer source is available."],
                confidenceBoundary: "Boiling does not remove all chemical contamination. If chemical pollution is possible, use a safer source.",
                relatedGuideIDs: ["boil_filter_disinfect_water"],
                groundingGuideID: "boil_filter_disinfect_water",
                contextInjectors: [.noPower]
            ),
            survival(
                id: "filtering_water",
                displayName: "Filtering water",
                topic: .survivalWater,
                urgency: .urgent,
                triggerTerms: ["filter water", "water filter", "can i filter water"],
                alternateTriggerPhrases: ["use filter on creek water"],
                triggerTokenGroups: [["filter", "water"]],
                summary: "Filtering can remove sediment and some biological risk when the filter is appropriate.",
                whatMatters: "Use only filters suitable for drinking water and treat water further if your system requires it.",
                steps: [
                    "Remove larger debris first so the filter does not clog quickly.",
                    "Use the cleanest working filter you have according to its instructions.",
                    "If your filter is not enough on its own, add boiling or approved chemical treatment."
                ],
                avoid: ["Do not assume any improvised filter makes water fully safe on its own."],
                confidenceBoundary: "If you cannot confirm what the filter removes, combine it with another treatment method.",
                relatedGuideIDs: ["boil_filter_disinfect_water"],
                groundingGuideID: "boil_filter_disinfect_water"
            ),
            survival(
                id: "chemical_disinfection",
                displayName: "Chemical disinfection",
                topic: .survivalWater,
                urgency: .urgent,
                triggerTerms: ["water tablets", "chemical disinfection water", "disinfect water chemically"],
                alternateTriggerPhrases: ["purification tablets", "chlorine water treatment"],
                triggerTokenGroups: [["chemical", "water"], ["water", "tablets"]],
                summary: "Approved chemical treatment can help when boiling is not practical.",
                whatMatters: "Use only approved water-treatment products and follow the product directions exactly.",
                steps: [
                    "Remove visible debris first if the water is cloudy.",
                    "Use only approved water-treatment chemicals or tablets.",
                    "Follow the product directions for dose and wait time."
                ],
                avoid: ["Do not guess the dose with household chemicals."],
                confidenceBoundary: "If you do not know the product or dose, do not improvise. Use a safer treatment method.",
                relatedGuideIDs: ["boil_filter_disinfect_water"],
                groundingGuideID: "boil_filter_disinfect_water"
            ),
            survival(
                id: "water_rationing",
                displayName: "Water rationing",
                topic: .waterPlanning,
                urgency: .urgent,
                triggerTerms: ["ration water", "water running low", "not much water left"],
                alternateTriggerPhrases: ["stretch water", "low on water"],
                triggerTokenGroups: [["ration", "water"], ["water", "left"]],
                summary: "Rationing should reduce waste without pushing the household into dehydration.",
                whatMatters: "Track what you have, reduce waste early, and protect the people who need water most.",
                steps: [
                    "Measure or count the water you still have.",
                    "Reduce non-essential use before drinking water becomes critical.",
                    "Prioritise drinking water for children, older adults, sick people, and anyone working in heat."
                ],
                avoid: ["Do not cut drinking water so hard that people stop urinating or become confused."],
                confidenceBoundary: "If someone shows dehydration or heat illness signs, shift from rationing to urgent medical or water-response guidance.",
                relatedGuideIDs: ["ration_water_without_dehydration"],
                groundingGuideID: "ration_water_without_dehydration",
                contextInjectors: [.dependents, .heat, .noWater]
            ),
            survival(
                id: "unsafe_water_warning",
                displayName: "Unsafe water warnings",
                topic: .waterPurification,
                urgency: .urgent,
                triggerTerms: ["unsafe water", "water smells bad", "dirty tap water", "flood water drinking"],
                alternateTriggerPhrases: ["contaminated water", "water looks unsafe"],
                triggerTokenGroups: [["unsafe", "water"], ["dirty", "water"], ["flood", "water"]],
                summary: "Water that looks, smells, or may be contaminated should not be treated as safe by default.",
                whatMatters: "If contamination is possible, stop drinking that source until it has been checked or treated safely.",
                steps: [
                    "Stop using suspicious water for drinking until it is checked or treated safely.",
                    "Use stored or known safe water first if available.",
                    "Treat the water only if the contamination risk fits a method you can use safely."
                ],
                avoid: ["Do not rely on appearance alone to judge safety."],
                confidenceBoundary: "Chemical contamination, sewage, or industrial runoff need more than basic filtering. Use a safer source when possible.",
                relatedGuideIDs: ["after_flood_drinking_water_checks"],
                groundingGuideID: "after_flood_drinking_water_checks",
                contextInjectors: [.noWater]
            ),
            survival(
                id: "collect_water_safely",
                displayName: "Collect water safely",
                topic: .survivalWater,
                urgency: .planning,
                triggerTerms: ["collect water", "gather rainwater", "find safe water source"],
                alternateTriggerPhrases: ["collect rainwater", "collecting water safely"],
                triggerTokenGroups: [["collect", "water"], ["collect", "rainwater"]],
                summary: "Collected water still needs contamination control and treatment.",
                whatMatters: "Choose the cleanest source you can and collect it into the cleanest container you have.",
                steps: [
                    "Use the cleanest available catchment surface or source.",
                    "Keep dirty runoff separate from the cleanest water you can save.",
                    "Treat collected water before drinking unless it is already known safe."
                ],
                avoid: ["Do not treat floodwater or obvious runoff as safe just because you collected it."],
                confidenceBoundary: "Collected water still needs treatment unless you know it is already potable.",
                relatedGuideIDs: ["collect_rainwater_safely"],
                groundingGuideID: "collect_rainwater_safely",
                fastPathEligible: false
            ),
            survival(
                id: "dehydration_survival",
                displayName: "Dehydration response",
                topic: .survivalWater,
                urgency: .urgent,
                triggerTerms: ["dehydrated in bush", "no water dizzy", "thirsty and weak", "dehydration response"],
                alternateTriggerPhrases: ["we are dehydrated", "running out of water and dizzy"],
                triggerTokenGroups: [["no", "water"], ["dizzy"], ["dehydration"]],
                summary: "Dehydration in the field can combine quickly with heat and poor decision-making.",
                whatMatters: "Stop activity, reduce heat load, and use safe fluids early if the person can drink.",
                steps: [
                    "Stop exertion and move to shade or shelter if possible.",
                    "Use safe fluids in small steady amounts if the person is awake and can swallow.",
                    "Escalate to medical help if the person is confused, collapsing, or cannot keep fluids down."
                ],
                avoid: ["Do not keep pushing through heat and dehydration."],
                confidenceBoundary: "If dehydration signs are mixed with confusion, collapse, or heat stress, switch to the medical emergency pathway.",
                relatedGuideIDs: ["ration_water_without_dehydration", "prevent_dehydration_in_extreme_heat"],
                contextInjectors: [.heat, .noWater]
            ),

            // Food
            survival(
                id: "emergency_food_storage",
                displayName: "Emergency food storage",
                topic: .survivalFood,
                urgency: .planning,
                triggerTerms: ["emergency food storage", "store food emergency", "food for blackout"],
                alternateTriggerPhrases: ["food prep", "store emergency food"],
                triggerTokenGroups: [["food", "storage"], ["store", "food"]],
                summary: "Food planning works best before the outage or evacuation starts.",
                whatMatters: "Choose food that is shelf-stable, familiar, and easy to use without full kitchen services.",
                steps: [
                    "Store shelf-stable food the household will actually eat.",
                    "Rotate stock so older items are used first.",
                    "Keep manual opening, simple cooking, and clean-water needs in mind."
                ],
                avoid: ["Do not build a food plan around items you cannot safely cook, open, or digest."],
                confidenceBoundary: "Food planning still depends on water, power, and household medical needs.",
                fastPathEligible: false
            ),
            survival(
                id: "no_power_food_safety",
                displayName: "No-power food safety",
                topic: .survivalFood,
                urgency: .urgent,
                triggerTerms: ["fridge off food", "no power food safety", "blackout food safe"],
                alternateTriggerPhrases: ["power out fridge", "freezer power out"],
                triggerTokenGroups: [["no", "power"], ["fridge", "off"], ["food", "safe"]],
                summary: "Food safety changes fast once refrigeration is lost.",
                whatMatters: "Keep cold storage closed, protect medicines first, and throw out unsafe food rather than gambling on it.",
                steps: [
                    "Keep fridges and freezers closed as much as possible.",
                    "Prioritise medicines and critical cold-chain items before ordinary food.",
                    "Discard food that is clearly unsafe or has been warm too long."
                ],
                avoid: ["Do not taste food to decide whether it is safe."],
                confidenceBoundary: "Exact discard timing depends on temperature and duration. If you are unsure, treat risky food as unsafe.",
                contextInjectors: [.noPower, .dependents]
            ),
            survival(
                id: "food_rationing_basics",
                displayName: "Food rationing basics",
                topic: .survivalFood,
                urgency: .planning,
                triggerTerms: ["ration food", "food running low", "stretch food"],
                alternateTriggerPhrases: ["less food left", "short on food"],
                triggerTokenGroups: [["ration", "food"], ["food", "running"]],
                summary: "Rationing works best when it starts early and stays realistic.",
                whatMatters: "Measure what is left, prioritise nutrition, and protect the people who need food most.",
                steps: [
                    "Count what food is left and plan by days, not guesses.",
                    "Use perishable and high-risk items first if they are still safe.",
                    "Prioritise children, older adults, and anyone with medical needs."
                ],
                avoid: ["Do not cut food so hard that children, sick people, or workers in heat are left unsupported."],
                confidenceBoundary: "Food rationing must still fit medical needs, hydration, and safe cooking limits.",
                fastPathEligible: false,
                contextInjectors: [.dependents]
            ),
            survival(
                id: "cooking_without_mains_power",
                displayName: "Cooking without mains power",
                topic: .survivalFood,
                urgency: .urgent,
                triggerTerms: ["cook without power", "no mains cooking", "blackout cooking"],
                alternateTriggerPhrases: ["cook during blackout", "cook off grid"],
                triggerTokenGroups: [["cook", "without", "power"], ["blackout", "cooking"]],
                summary: "Simple low-risk cooking beats complicated setups during outages.",
                whatMatters: "Use the safest cooking method you already know, with ventilation, fuel control, and burn safety.",
                steps: [
                    "Use the safest working stove or heat source you already know how to use.",
                    "Keep ventilation and fire safety in mind before lighting anything indoors.",
                    "Choose simple meals that use little water, fuel, and cleanup."
                ],
                avoid: ["Do not improvise indoor flames or unvented fuel use in enclosed spaces."],
                confidenceBoundary: "Cooking advice changes with fuel type and ventilation. If the setup is not safe, switch to ready-to-eat food.",
                relatedGuideIDs: ["campfire_safety_without_mains"],
                groundingGuideID: "campfire_safety_without_mains",
                contextInjectors: [.noPower]
            ),
            survival(
                id: "food_contamination_avoidance",
                displayName: "Food contamination avoidance",
                topic: .survivalFood,
                urgency: .urgent,
                triggerTerms: ["food contamination", "unsafe food handling", "keep food safe"],
                alternateTriggerPhrases: ["avoid contamination food", "food hygiene emergency"],
                triggerTokenGroups: [["food", "contamination"], ["food", "hygiene"]],
                summary: "Safe food handling matters more when water, refrigeration, and cleanup are limited.",
                whatMatters: "Keep hands, tools, and surfaces as clean as conditions allow and separate dirty items from ready-to-eat food.",
                steps: [
                    "Keep raw and ready-to-eat food separate.",
                    "Use the cleanest hands, water, and tools available.",
                    "Discard food that may have been contaminated by floodwater, sewage, or pests."
                ],
                avoid: ["Do not rely on smell alone to judge contamination."],
                confidenceBoundary: "If contamination is likely and you cannot clean effectively, discard the food.",
                relatedGuideIDs: ["field_food_hygiene"],
                groundingGuideID: "field_food_hygiene",
                contextInjectors: [.noWater]
            ),

            // Shelter
            survival(
                id: "temporary_shelter",
                displayName: "Temporary shelter",
                topic: .survivalShelter,
                urgency: .urgent,
                triggerTerms: ["temporary shelter", "build shelter", "need shelter now"],
                alternateTriggerPhrases: ["survival shelter", "make shelter"],
                triggerTokenGroups: [["build", "shelter"], ["need", "shelter"]],
                summary: "Shelter is about exposure control before comfort.",
                whatMatters: "Get out of wind, rain, and direct sun first. A simple stable shelter beats a complicated one.",
                steps: [
                    "Choose the safest available site out of wind, falling branches, rising water, and traffic.",
                    "Use the simplest stable shelter you can build with the materials you have.",
                    "Prioritise insulation from wind, rain, and ground exposure."
                ],
                avoid: ["Do not build in flood paths, under damaged trees, or close to unstable fire."],
                confidenceBoundary: "If the site is unsafe, movement to a better location matters more than building speed.",
                relatedGuideIDs: ["safe_tarp_shelter_setup"],
                groundingGuideID: "safe_tarp_shelter_setup",
                contextInjectors: [.cold, .heat, .night]
            ),
            survival(
                id: "shelter_in_place",
                displayName: "Shelter in place",
                topic: .survivalShelter,
                urgency: .urgent,
                triggerTerms: ["shelter in place", "stay inside", "shelter at home"],
                alternateTriggerPhrases: ["stay put at home", "shelter inside"],
                triggerTokenGroups: [["shelter", "place"], ["stay", "inside"]],
                summary: "Sheltering works when the inside space is safer than movement outside.",
                whatMatters: "Choose the safest room, bring essentials in with you, and reduce exposure to smoke, glass, and debris.",
                steps: [
                    "Move to the safest internal room away from windows if the hazard fits sheltering.",
                    "Bring water, lights, radio, chargers, medicines, and dependent needs with you.",
                    "Stay updated and be ready to leave if official advice changes."
                ],
                avoid: ["Do not spread the household across multiple unsafe rooms."],
                confidenceBoundary: "Sheltering is not always the right option. If official evacuation advice is active, follow that first.",
                relatedGuideIDs: ["shelter_in_place_steps"],
                groundingGuideID: "shelter_in_place_steps",
                contextInjectors: [.dependents, .pets, .smoke]
            ),
            survival(
                id: "room_sealing_smoke_reduction",
                displayName: "Room sealing / smoke reduction",
                topic: .survivalShelter,
                urgency: .urgent,
                triggerTerms: ["seal room smoke", "smoke getting inside", "reduce smoke inside"],
                alternateTriggerPhrases: ["close smoke gaps", "ash getting inside"],
                triggerTokenGroups: [["seal", "room"], ["smoke", "inside"]],
                summary: "Smoke reduction is about cleaner air and lower exposure, not perfect sealing.",
                whatMatters: "Close outside air leaks you can manage safely and protect the cleanest room you have.",
                steps: [
                    "Close windows, doors, and obvious gaps if it is safe to do so.",
                    "Move the household into the cleanest room available.",
                    "Limit unnecessary trips outside while smoke is heavy."
                ],
                avoid: ["Do not burn candles, incense, or extra flames inside a smoke-control room."],
                confidenceBoundary: "If indoor air is still causing breathing trouble, escalate to cleaner air and medical help.",
                relatedGuideIDs: ["smoke_exposure_reduction"],
                groundingGuideID: "smoke_exposure_reduction",
                contextInjectors: [.smoke, .dependents, .noPower]
            ),
            survival(
                id: "cold_weather_shelter",
                displayName: "Cold-weather shelter",
                topic: .survivalShelter,
                urgency: .urgent,
                triggerTerms: ["cold shelter", "stay warm shelter", "shelter in cold"],
                alternateTriggerPhrases: ["cold weather shelter", "freezing shelter"],
                triggerTokenGroups: [["cold", "shelter"], ["stay", "warm"]],
                summary: "In cold conditions, blocking wind and insulating from the ground matter first.",
                whatMatters: "Prioritise wind protection, dry layers, and insulation from cold surfaces.",
                steps: [
                    "Get out of wind and rain first.",
                    "Use dry layers, blankets, and insulation between people and the ground.",
                    "Keep wet clothing and wet gear away from the main sleeping area if possible."
                ],
                avoid: ["Do not sleep directly on cold ground if you can insulate first."],
                confidenceBoundary: "If someone is confused, drowsy, or very cold, switch to the hypothermia pathway.",
                contextInjectors: [.cold, .night]
            ),
            survival(
                id: "heat_shelter",
                displayName: "Heat shelter",
                topic: .survivalShelter,
                urgency: .urgent,
                triggerTerms: ["heat shelter", "cool shelter", "keep cool without power"],
                alternateTriggerPhrases: ["hot house shelter", "protect from heat inside"],
                triggerTokenGroups: [["heat", "shelter"], ["keep", "cool"]],
                summary: "Heat shelter is about lowering heat load and protecting water, medicines, and people.",
                whatMatters: "Move to the coolest shaded space you can manage and reduce heat entering the space.",
                steps: [
                    "Use the coolest shaded room or structure available.",
                    "Block direct sun where you can and reduce unnecessary movement.",
                    "Keep drinking water, medicines, and dependent needs close and cool if possible."
                ],
                avoid: ["Do not use extra indoor heat sources unless you have clear ventilation and a real need."],
                confidenceBoundary: "If the space is not cooling people enough, escalate to heat-illness guidance or safer relocation.",
                relatedGuideIDs: ["cool_home_without_power"],
                groundingGuideID: "cool_home_without_power",
                contextInjectors: [.heat, .dependents, .noPower]
            ),
            survival(
                id: "rain_wind_shelter_basics",
                displayName: "Rain / wind shelter basics",
                topic: .survivalShelter,
                urgency: .urgent,
                triggerTerms: ["rain shelter", "wind shelter", "shelter from storm"],
                alternateTriggerPhrases: ["keep dry shelter", "get out of wind and rain"],
                triggerTokenGroups: [["rain", "shelter"], ["wind", "shelter"]],
                summary: "Stay dry, stable, and out of falling hazards first.",
                whatMatters: "Get under cover, avoid falling hazards, and keep bedding and clothing dry.",
                steps: [
                    "Move away from flood paths, unstable trees, and damaged structures.",
                    "Use stable cover that sheds rain and blocks wind.",
                    "Keep the driest clothes and bedding protected from ground moisture."
                ],
                avoid: ["Do not shelter under damaged trees or unstable roofs."],
                confidenceBoundary: "If wind or storm damage is increasing, switch to formal shelter or safer relocation.",
                relatedGuideIDs: ["safe_tarp_shelter_setup"],
                groundingGuideID: "safe_tarp_shelter_setup",
                contextInjectors: [.night]
            ),

            // Fire / bushfire
            survival(
                id: "fire_nearby_leave_or_prepare",
                displayName: "Fire nearby: leave or stay preparation",
                topic: .bushfireEvacuation,
                urgency: .emergency,
                triggerTerms: ["fire nearby", "bushfire nearby", "smoke everywhere", "leave now fire", "bushfire evacuation"],
                alternateTriggerPhrases: ["fire close by", "what do i do bushfire now", "during bushfire evacuation"],
                triggerTokenGroups: [["fire", "nearby"], ["bushfire", "nearby"], ["smoke", "everywhere"], ["bushfire", "evacuation"]],
                summary: "When fire is nearby, early movement is usually safer than late movement.",
                whatMatters: "Decide early, keep the vehicle and route ready, and do not wait for smoke or flame to remove your options.",
                steps: [
                    "Check the safest available route and leave early if official warnings support it.",
                    "Take medicines, documents, water, children, pets, and chargers first.",
                    "Keep the vehicle pointed outward and ready to move."
                ],
                avoid: ["Do not wait for visible flame or heavy smoke before preparing to move."],
                confidenceBoundary: "Bushfire movement depends on official warnings, route safety, and your location. Follow the stricter path when uncertain.",
                emergencyEscalation: "Call 000 if you are trapped or immediate fire impact is occurring.",
                relatedGuideIDs: ["bushfire_leave_early_plan", "household_evacuation_quick_start"],
                groundingGuideID: "bushfire_leave_early_plan",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.routeRisk, .dependents, .pets, .smoke]
            ),
            survival(
                id: "smoke_ash_response",
                displayName: "Smoke / ash response",
                topic: .survivalFire,
                urgency: .urgent,
                triggerTerms: ["smoke response", "ash falling", "bushfire smoke", "smoke everywhere"],
                alternateTriggerPhrases: ["heavy smoke outside", "ash in air"],
                triggerTokenGroups: [["bushfire", "smoke"], ["ash", "falling"], ["smoke", "outside"]],
                summary: "Smoke changes priorities before flame is even visible.",
                whatMatters: "Reduce smoke exposure early and protect people with breathing problems first.",
                steps: [
                    "Move the household into the cleanest indoor room available.",
                    "Close gaps you can manage safely and reduce outdoor exertion.",
                    "Escalate early for asthma, chest pain, severe cough, or breathing trouble."
                ],
                avoid: ["Do not keep doing hard work outside in heavy smoke."],
                confidenceBoundary: "If indoor air is still unsafe or someone has breathing trouble, escalate early rather than waiting it out.",
                relatedGuideIDs: ["smoke_exposure_reduction"],
                groundingGuideID: "smoke_exposure_reduction",
                contextInjectors: [.smoke, .dependents]
            ),
            survival(
                id: "ember_risk_reduction",
                displayName: "Ember risk reduction",
                topic: .survivalFire,
                urgency: .urgent,
                triggerTerms: ["embers", "ember attack", "ember risk", "spot fires"],
                alternateTriggerPhrases: ["ash and embers", "embers around house"],
                triggerTokenGroups: [["ember", "risk"], ["ember", "attack"]],
                summary: "Embers can start spot fires well before the main fire front.",
                whatMatters: "Reduce ignition points around the house and prepare to leave before ember attack grows.",
                steps: [
                    "Close openings and move flammable items away from the structure if it is safe.",
                    "Keep hoses, buckets, and departure essentials ready.",
                    "Leave early if your trigger point or official warning tells you to."
                ],
                avoid: ["Do not spend so long defending small ember fires that you miss your safest leave window."],
                confidenceBoundary: "Ember attack can escalate quickly. Do not rely on property work if movement options are shrinking.",
                relatedGuideIDs: ["ember_attack_home_actions", "bushfire_leave_early_plan"],
                groundingGuideID: "ember_attack_home_actions",
                contextInjectors: [.routeRisk]
            ),
            survival(
                id: "bushfire_prep",
                displayName: "Bushfire preparation",
                topic: .bushfireEvacuation,
                urgency: .planning,
                triggerTerms: ["bushfire prep", "prepare for bushfire", "fire season prep"],
                alternateTriggerPhrases: ["fire readiness", "prepare for fire season"],
                triggerTokenGroups: [["bushfire", "prep"], ["prepare", "bushfire"]],
                summary: "Bushfire preparation is mostly about leaving early and leaving with the right things.",
                whatMatters: "Set a leave trigger before the day turns bad and prepare the vehicle, documents, medicines, pets, and route.",
                steps: [
                    "Choose a leave trigger before conditions worsen.",
                    "Prepare the vehicle, routes, documents, medicines, and pet gear.",
                    "Monitor official warnings and be ready to go early."
                ],
                avoid: ["Do not make the first decision after smoke and confusion have already started."],
                confidenceBoundary: "Bushfire prep must still adapt to local warnings and route safety.",
                relatedGuideIDs: ["bushfire_leave_early_plan", "official_warning_monitoring"],
                groundingGuideID: "bushfire_leave_early_plan",
                fastPathEligible: false,
                contextInjectors: [.dependents, .pets]
            ),
            survival(
                id: "evacuation_basics",
                displayName: "Evacuation basics",
                topic: .bushfireEvacuation,
                urgency: .urgent,
                triggerTerms: ["evacuation", "leave now", "we need to leave", "grab and go"],
                alternateTriggerPhrases: ["evacuate", "getting out now"],
                triggerTokenGroups: [["leave", "now"], ["need", "leave"], ["evacuation"]],
                summary: "Evacuation works best when essentials are pre-decided and the route is checked before movement.",
                whatMatters: "Take only what matters first, keep the group together, and check the safest route before moving.",
                steps: [
                    "Take medicines, water, documents, phones, and chargers first.",
                    "Move children, pets, and anyone needing support before optional gear.",
                    "Check the route before moving and leave while travel is still straightforward."
                ],
                avoid: ["Do not keep repacking until the safe leave window closes."],
                confidenceBoundary: "Evacuation advice depends on official warnings and route safety. When in doubt, prepare to move earlier.",
                relatedGuideIDs: ["household_evacuation_quick_start"],
                groundingGuideID: "household_evacuation_quick_start",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.dependents, .pets, .routeRisk]
            ),
            survival(
                id: "vehicle_departure_prep",
                displayName: "Vehicle departure prep",
                topic: .bushfireEvacuation,
                urgency: .urgent,
                triggerTerms: ["load vehicle to leave", "car ready to evacuate", "vehicle departure prep"],
                alternateTriggerPhrases: ["get car ready to leave", "departure vehicle"],
                triggerTokenGroups: [["vehicle", "departure"], ["car", "ready"]],
                summary: "Departure slows down when the vehicle is not ready before stress rises.",
                whatMatters: "Fuel, route, documents, medicines, and dependent needs matter more than optional gear.",
                steps: [
                    "Fuel the vehicle early if you still can.",
                    "Load medicines, documents, water, pet gear, and dependent needs first.",
                    "Park for forward exit and keep keys, phones, and chargers ready."
                ],
                avoid: ["Do not block your own exit with late-stage packing."],
                confidenceBoundary: "Vehicle departure only helps if the route is still safe. Recheck before moving.",
                contextInjectors: [.vehicle, .dependents, .pets, .routeRisk]
            ),

            // Flood / storm
            survival(
                id: "flood_prep",
                displayName: "Flood preparation",
                topic: .floodSafety,
                urgency: .planning,
                triggerTerms: ["prepare for flood", "flood prep", "flood ready"],
                alternateTriggerPhrases: ["flood preparation", "before flood"],
                triggerTokenGroups: [["flood", "prep"], ["prepare", "flood"]],
                summary: "Flood preparation is mostly about moving early and getting people and essentials above risk.",
                whatMatters: "Protect the household, move key items higher, and know the safe route before water cuts it off.",
                steps: [
                    "Move key items, medicines, and documents to higher ground.",
                    "Prepare go-bags and plan the route out before water rises.",
                    "Monitor official warnings and move early if advised."
                ],
                avoid: ["Do not wait until roads are already underwater before leaving."],
                confidenceBoundary: "Flood behaviour changes fast with road closures and local geography. Move early when warnings rise.",
                relatedGuideIDs: ["flood_evacuation_timing"],
                groundingGuideID: "flood_evacuation_timing",
                fastPathEligible: false,
                contextInjectors: [.routeRisk, .dependents]
            ),
            survival(
                id: "floodwater_avoidance",
                displayName: "Flood water avoidance",
                topic: .floodSafety,
                urgency: .emergency,
                triggerTerms: ["flood water", "floodwater", "driving through water", "water over road"],
                alternateTriggerPhrases: ["road underwater", "flash flood road"],
                triggerTokenGroups: [["flood", "water"], ["water", "road"]],
                summary: "Floodwater changes route safety immediately.",
                whatMatters: "Do not drive, walk, or ride into floodwater. Move to higher ground and use a safer route.",
                steps: [
                    "Turn away from floodwater immediately.",
                    "Move to higher ground or a safer route.",
                    "Call 000 if people are trapped by rising water."
                ],
                avoid: ["Do not drive, walk, or ride through floodwater."],
                confidenceBoundary: "Depth, current, and road damage are hard to judge. Treat all floodwater on roads as unsafe.",
                relatedGuideIDs: ["turn_around_dont_drown", "flood_evacuation_timing"],
                groundingGuideID: "turn_around_dont_drown",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.routeRisk, .routeBlocked, .waterExposure]
            ),
            survival(
                id: "move_to_higher_ground",
                displayName: "Move to higher ground",
                topic: .floodSafety,
                urgency: .emergency,
                triggerTerms: ["move to higher ground", "water entering house", "rising water inside"],
                alternateTriggerPhrases: ["water coming in house", "house flooding now"],
                triggerTokenGroups: [["higher", "ground"], ["water", "entering", "house"], ["house", "flooding"]],
                summary: "When water is entering the home, height and early movement matter.",
                whatMatters: "Move people, pets, medicines, and documents above water or out early using a safe route.",
                steps: [
                    "Move everyone, pets, medicines, and documents to higher ground immediately.",
                    "Use a safe route out if it is still open.",
                    "Call 000 if rising water traps you or cuts off safe movement."
                ],
                avoid: ["Do not stay in low rooms once water is rising."],
                confidenceBoundary: "If route safety is uncertain, treat rising indoor floodwater as a move-now problem.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.routeRisk, .routeBlocked, .dependents, .pets]
            ),
            survival(
                id: "storm_prep",
                displayName: "Storm preparation",
                topic: .survivalFloodStorm,
                urgency: .planning,
                triggerTerms: ["storm prep", "prepare for storm", "severe weather prep"],
                alternateTriggerPhrases: ["storm preparation", "get ready for storm"],
                triggerTokenGroups: [["storm", "prep"], ["prepare", "storm"]],
                summary: "Storm prep is mainly about loose items, shelter choice, and backup essentials.",
                whatMatters: "Secure what you can early and prepare the safest room before winds and rain arrive.",
                steps: [
                    "Secure loose outdoor items and protect important devices and documents.",
                    "Choose the safest internal room and move essentials there.",
                    "Charge devices, lights, and radios before conditions worsen."
                ],
                avoid: ["Do not leave storm preparation until wind and hail are already active."],
                confidenceBoundary: "Storm strength varies quickly. Re-check official warnings if the threat is increasing.",
                relatedGuideIDs: ["severe_storm_room_setup", "protect_devices_and_documents_before_storm"],
                groundingGuideID: "severe_storm_room_setup",
                fastPathEligible: false
            ),
            survival(
                id: "severe_weather_room_setup",
                displayName: "Severe weather room setup",
                topic: .survivalFloodStorm,
                urgency: .urgent,
                triggerTerms: ["storm room", "safe room storm", "internal room storm"],
                alternateTriggerPhrases: ["severe weather room", "safest room during storm"],
                triggerTokenGroups: [["storm", "room"], ["safe", "room", "storm"]],
                summary: "A good storm room reduces exposure to glass, debris, and sudden movement.",
                whatMatters: "Use the safest internal room available and bring critical items inside before the storm peaks.",
                steps: [
                    "Choose an internal room away from windows if possible.",
                    "Bring water, lights, radio, chargers, medicines, and dependent needs into that room.",
                    "Stay there while the worst conditions pass."
                ],
                avoid: ["Do not shelter near large glass if a safer internal room exists."],
                confidenceBoundary: "If the building itself is unsafe, switch from room setup to formal shelter or evacuation guidance.",
                relatedGuideIDs: ["severe_storm_room_setup"],
                groundingGuideID: "severe_storm_room_setup",
                contextInjectors: [.dependents]
            ),
            survival(
                id: "post_storm_safety",
                displayName: "Post-storm safety basics",
                topic: .survivalFloodStorm,
                urgency: .urgent,
                triggerTerms: ["after storm safety", "post storm", "safe after cyclone", "after severe weather"],
                alternateTriggerPhrases: ["storm passed now what", "after the storm"],
                triggerTokenGroups: [["after", "storm"], ["post", "storm"]],
                summary: "Injuries often happen after the storm, not during it.",
                whatMatters: "Treat damaged structures, water, and powerlines as hazards until they are confirmed safe.",
                steps: [
                    "Check for downed powerlines, unstable trees, and structural damage before moving around.",
                    "Avoid floodwater, contaminated surfaces, and damaged wiring.",
                    "Use gloves and protective gear for cleanup if you have them."
                ],
                avoid: ["Do not rush into damaged buildings or touch downed lines."],
                confidenceBoundary: "If structural damage, electricity, gas, or contamination are involved, move carefully and escalate early.",
                relatedGuideIDs: ["safe_cleanup_after_disaster", "downed_powerline_safety"],
                groundingGuideID: "safe_cleanup_after_disaster"
            ),

            // Power / blackout
            survival(
                id: "blackout_prep",
                displayName: "Blackout preparation",
                topic: .blackoutResponse,
                urgency: .planning,
                triggerTerms: ["blackout", "power out", "power outage", "blackout prep"],
                alternateTriggerPhrases: ["prepare for blackout", "power cut"],
                triggerTokenGroups: [["power", "out"], ["power", "outage"], ["blackout"]],
                summary: "Prepare early so you can stay safe and maintain essentials during a power outage.",
                whatMatters: "Water, lights, phones, and medicines matter before comfort.",
                steps: [
                    "Store water and ready-to-eat food.",
                    "Charge devices and prepare backup lighting.",
                    "Plan for refrigeration and medication storage.",
                    "Keep a radio or offline updates available."
                ],
                avoid: ["Do not rely on power-dependent systems without backup."],
                confidenceBoundary: "Blackout impact depends on duration, heat, medical needs, and communications access.",
                contextInjectors: [.noPower, .dependents]
            ),
            survival(
                id: "backup_lighting",
                displayName: "Backup lighting",
                topic: .blackoutResponse,
                urgency: .planning,
                triggerTerms: ["backup lighting", "lights for blackout", "no power lights"],
                alternateTriggerPhrases: ["torches for blackout", "flashlight power outage"],
                triggerTokenGroups: [["backup", "lighting"], ["no", "power", "lights"]],
                summary: "Safe lighting prevents injury and preserves battery-heavy devices.",
                whatMatters: "Use the safest light source you have and keep it where falls and urgent tasks are most likely.",
                steps: [
                    "Keep torches or headlamps where you can reach them in the dark.",
                    "Use low-power lighting for general tasks and save brighter options for urgent work.",
                    "Keep spare batteries together if you have them."
                ],
                avoid: ["Do not depend on phone flashlights alone for long outages."],
                confidenceBoundary: "Lighting choices depend on battery reserves and fire safety in the space.",
                contextInjectors: [.noPower]
            ),
            survival(
                id: "refrigeration_medication_planning",
                displayName: "Refrigeration / medication planning",
                topic: .blackoutResponse,
                urgency: .urgent,
                triggerTerms: ["medication fridge no power", "insulin blackout", "fridge medicines no power"],
                alternateTriggerPhrases: ["refrigerated medicine blackout", "cold medicine power outage"],
                triggerTokenGroups: [["medication", "fridge"], ["insulin", "blackout"]],
                summary: "Cold-chain medicines can become more important than ordinary food during a blackout.",
                whatMatters: "Protect critical medicines first and seek pharmacy or clinical advice early if temperature limits may be exceeded.",
                steps: [
                    "Keep the fridge closed as much as possible.",
                    "Prioritise temperature-sensitive medicines before ordinary food.",
                    "Seek pharmacy or medical advice early if you think storage limits may be exceeded."
                ],
                avoid: ["Do not assume temperature-sensitive medicines remain safe indefinitely without checking."],
                confidenceBoundary: "Medicine stability depends on the product and time out of range. Escalate early for essential medicines.",
                contextInjectors: [.noPower, .dependents]
            ),
            survival(
                id: "charging_power_budgeting",
                displayName: "Charging and power budgeting",
                topic: .blackoutResponse,
                urgency: .urgent,
                triggerTerms: ["charge phones blackout", "power budgeting", "battery save blackout"],
                alternateTriggerPhrases: ["keep phone alive blackout", "save battery no power"],
                triggerTokenGroups: [["power", "budgeting"], ["save", "battery"], ["charge", "phones"]],
                summary: "Power budgeting keeps communication and critical functions alive longer.",
                whatMatters: "Use battery for communication, route checks, medical needs, and official updates before comfort use.",
                steps: [
                    "Switch devices to low-power settings early.",
                    "Charge critical devices first: phones, medical equipment, radios, and lights.",
                    "Reduce non-essential screen use and background drain."
                ],
                avoid: ["Do not burn battery on entertainment or repeated unnecessary checks."],
                confidenceBoundary: "Power plans change with outage length, temperature, and medical devices.",
                contextInjectors: [.noPower, .noSignal]
            ),
            survival(
                id: "generator_safety",
                displayName: "Generator safety",
                topic: .blackoutResponse,
                urgency: .urgent,
                triggerTerms: ["generator safety", "using generator", "generator during blackout"],
                alternateTriggerPhrases: ["generator after storm", "portable generator safety"],
                triggerTokenGroups: [["generator", "safety"], ["using", "generator"]],
                summary: "Generators solve one problem and can create several others if they are used badly.",
                whatMatters: "Use the generator outside, away from openings, and keep fuel and cords managed safely.",
                steps: [
                    "Run generators outside and away from doors, windows, and vents.",
                    "Protect the generator from rain without trapping exhaust.",
                    "Manage fuel and cords so they do not create extra hazards."
                ],
                avoid: ["Do not run a generator inside a home, garage, or enclosed area."],
                confidenceBoundary: "Generator safety depends on ventilation and electrical setup. If the setup is unclear, use a safer fallback.",
                relatedGuideIDs: ["generator_safety_after_storm"],
                groundingGuideID: "generator_safety_after_storm",
                contextInjectors: [.noPower]
            ),
            survival(
                id: "no_power_communications",
                displayName: "No-power communications",
                topic: .communicationsResponse,
                urgency: .urgent,
                triggerTerms: ["no power communication", "blackout communication", "how do we communicate no power"],
                alternateTriggerPhrases: ["power out communication", "no power updates"],
                triggerTokenGroups: [["no", "power", "communication"], ["blackout", "communication"]],
                summary: "Comms degrade fast when power and mobile charging are both limited.",
                whatMatters: "Conserve battery, choose one primary update channel, and keep check-in plans simple.",
                steps: [
                    "Conserve phone battery for priority messages and updates.",
                    "Use radio or offline updates if you have them.",
                    "Agree on one family check-in method and one fallback."
                ],
                avoid: ["Do not scatter communication across too many devices and channels."],
                confidenceBoundary: "Comms plans depend on power, radio access, and whether the network is still working.",
                contextInjectors: [.noPower, .noSignal]
            ),

            // Signal / comms
            survival(
                id: "no_signal",
                displayName: "No signal",
                topic: .communicationsResponse,
                urgency: .urgent,
                triggerTerms: ["no signal", "cant get signal", "no phone service", "lost signal"],
                alternateTriggerPhrases: ["no bars", "service down"],
                triggerTokenGroups: [["no", "signal"], ["phone", "service"]],
                summary: "When signal drops out, battery, movement, and known meeting plans matter more.",
                whatMatters: "Do not waste battery searching blindly. Stabilise, check offline tools, and use agreed fallback comms.",
                steps: [
                    "Stop and assess before moving just to chase signal.",
                    "Use offline maps, stored contacts, radio, or agreed fallback plans if you have them.",
                    "Conserve battery for priority communication and emergency use."
                ],
                avoid: ["Do not walk into unsafe terrain just to search for a bar of signal."],
                confidenceBoundary: "If you are lost as well as out of signal, switch to navigation guidance rather than continuing random movement.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.noSignal, .noGPS]
            ),
            survival(
                id: "emergency_contact_plan",
                displayName: "Emergency contact plan",
                topic: .communicationsResponse,
                urgency: .planning,
                triggerTerms: ["contact plan", "family contact emergency", "who do we call emergency"],
                alternateTriggerPhrases: ["emergency contact plan", "check in plan family"],
                triggerTokenGroups: [["contact", "plan"], ["family", "contact"]],
                summary: "A simple contact plan reduces confusion when the network is unreliable.",
                whatMatters: "Choose who reports status, who receives updates, and where the group regroups if calls fail.",
                steps: [
                    "Choose one primary contact and one backup outside the immediate area.",
                    "Agree on how often to check in and what information to send.",
                    "Set a simple regroup point if contact fails."
                ],
                avoid: ["Do not assume everyone will remember the plan under stress unless it is written or rehearsed."],
                confidenceBoundary: "Contact plans depend on power, radio coverage, and how dispersed the household is.",
                fastPathEligible: false,
                contextInjectors: [.dependents]
            ),
            survival(
                id: "radio_use",
                displayName: "Radio use",
                topic: .communicationsResponse,
                urgency: .planning,
                triggerTerms: ["radio emergency", "use radio", "battery radio"],
                alternateTriggerPhrases: ["listen to radio updates", "emergency radio"],
                triggerTokenGroups: [["battery", "radio"], ["emergency", "radio"]],
                summary: "Radio is often the lowest-dependency way to keep getting updates in a prolonged outage.",
                whatMatters: "Know which radio you have, what powers it, and where it will be kept.",
                steps: [
                    "Keep a working radio in an easy-to-reach place.",
                    "Store batteries or charging backup with it.",
                    "Use one main station for official updates when signal is poor."
                ],
                avoid: ["Do not leave radios unpowered or buried in storage during storm season."],
                confidenceBoundary: "Radio usefulness depends on signal, power, and local broadcaster availability.",
                fastPathEligible: false
            ),
            survival(
                id: "battery_preservation",
                displayName: "Battery preservation",
                topic: .communicationsResponse,
                urgency: .urgent,
                triggerTerms: ["save battery", "battery preservation", "phone battery emergency"],
                alternateTriggerPhrases: ["keep battery alive", "phone about to die"],
                triggerTokenGroups: [["save", "battery"], ["battery", "preservation"]],
                summary: "Battery is a safety resource in outage and movement conditions.",
                whatMatters: "Keep battery for communication, maps, warnings, and medical needs first.",
                steps: [
                    "Switch to low-power mode and reduce brightness early.",
                    "Turn off unused radios and background drain.",
                    "Use short updates instead of long calls if coverage is unstable."
                ],
                avoid: ["Do not spend your remaining battery on non-essential apps."],
                confidenceBoundary: "Battery plans should change if you are moving, using maps, or waiting for rescue.",
                contextInjectors: [.noSignal, .noPower]
            ),
            survival(
                id: "rescue_signalling",
                displayName: "Signalling for rescue",
                topic: .communicationsResponse,
                urgency: .urgent,
                triggerTerms: ["signal for rescue", "how do i signal", "need rescue signal"],
                alternateTriggerPhrases: ["make distress signal", "rescue signalling"],
                triggerTokenGroups: [["signal", "rescue"], ["distress", "signal"]],
                summary: "Signalling works best when the signal is obvious, repeatable, and safe to maintain.",
                whatMatters: "Use the clearest signal you can make without creating extra danger or wasting critical energy.",
                steps: [
                    "Choose the clearest signal available: radio, whistle, torch, mirror, or visible marker.",
                    "Repeat the signal in a pattern if possible.",
                    "Stay where rescuers can find you unless moving is clearly safer."
                ],
                avoid: ["Do not waste all light or battery on constant signalling with no plan."],
                confidenceBoundary: "If signalling competes with warmth, shelter, or hydration, rebalance around survival first.",
                relatedGuideIDs: ["improvised_signal_methods"],
                groundingGuideID: "improvised_signal_methods",
                contextInjectors: [.noSignal, .night]
            ),

            // Navigation
            survival(
                id: "no_gps_or_lost",
                displayName: "No GPS / lost",
                topic: .routePlanning,
                urgency: .urgent,
                triggerTerms: ["lost", "no gps", "cant navigate", "where am i", "navigation help"],
                alternateTriggerPhrases: ["without gps", "gps not working"],
                triggerTokenGroups: [["no", "gps"], ["without", "gps"], ["navigation", "help"]],
                summary: "When you are lost, stopping early is usually safer than drifting deeper into uncertainty.",
                whatMatters: "Stop, assess, use known references, and move only when you have a clear reason and direction.",
                steps: [
                    "Stop moving and assess where you last knew your position.",
                    "Use offline maps, known landmarks, and rally points if you have them.",
                    "Signal for help or wait if movement is likely to make the situation worse."
                ],
                avoid: ["Do not keep moving just to feel like you are making progress."],
                confidenceBoundary: "If you are disoriented, injured, or losing light, staying put may be safer than continued movement.",
                relatedGuideIDs: ["route_planning_without_gps", "set_simple_rally_points"],
                groundingGuideID: "route_planning_without_gps",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.noGPS, .noSignal, .night]
            ),
            survival(
                id: "landmark_navigation",
                displayName: "Landmark navigation",
                topic: .navigationResponse,
                urgency: .planning,
                triggerTerms: ["navigate by landmarks", "landmark navigation"],
                alternateTriggerPhrases: ["use landmarks to navigate"],
                triggerTokenGroups: [["landmark", "navigation"]],
                summary: "Landmarks are most useful when you use them deliberately rather than vaguely.",
                whatMatters: "Choose distinct fixed references and link them to direction, not just memory.",
                steps: [
                    "Choose large fixed landmarks you can identify again.",
                    "Use landmark sequences instead of one-off guesses.",
                    "Check that each landmark actually confirms your direction before you commit."
                ],
                avoid: ["Do not rely on vague or moving references like smoke plumes or traffic alone."],
                confidenceBoundary: "If landmarks are poor, visibility is low, or you are tired, stop and re-assess rather than drifting.",
                fastPathEligible: false
            ),
            survival(
                id: "stop_assess_plan",
                displayName: "Stop, assess, plan",
                topic: .navigationResponse,
                urgency: .urgent,
                triggerTerms: ["stop assess plan", "what should i do first lost", "i dont know where to start outdoors"],
                alternateTriggerPhrases: ["stop and assess", "pause and plan"],
                triggerTokenGroups: [["stop", "assess"], ["pause", "plan"]],
                summary: "The first decision in confusion should reduce risk, not increase movement.",
                whatMatters: "Pause before acting so you do not turn a manageable problem into a bigger one.",
                steps: [
                    "Stop moving and get a quick picture of hazards, time, weather, and who is with you.",
                    "Choose one immediate priority: shelter, water, route, or help.",
                    "Only move once the next step is clearer than staying put."
                ],
                avoid: ["Do not stack multiple urgent decisions at once when you are already disoriented."],
                confidenceBoundary: "If injury, darkness, water, or fire are involved, use the stricter safety path before navigation goals."
            ),
            survival(
                id: "safe_route_selection",
                displayName: "Safe route selection",
                topic: .routePlanning,
                urgency: .urgent,
                triggerTerms: ["safe route", "which route is safer", "route blocked", "alternate route"],
                alternateTriggerPhrases: ["route selection", "choose route"],
                triggerTokenGroups: [["safe", "route"], ["alternate", "route"], ["route", "blocked"]],
                summary: "The shortest route is not always the safest route under hazard.",
                whatMatters: "Choose the route with the lowest current hazard, not just the lowest distance.",
                steps: [
                    "Check whether water, smoke, fire, wind damage, or road closure changes the route.",
                    "Choose the route that keeps you away from the strongest current hazard.",
                    "If route safety is uncertain, pause and re-check before committing."
                ],
                avoid: ["Do not push into blocked or low-visibility routes just because they are familiar."],
                confidenceBoundary: "Route choice should become more conservative as alert freshness worsens or visibility drops.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.routeRisk, .routeBlocked]
            ),
            survival(
                id: "when_not_to_move",
                displayName: "When not to move",
                topic: .routePlanning,
                urgency: .urgent,
                triggerTerms: ["should i stay put", "when not to move", "safer to stay"],
                alternateTriggerPhrases: ["stay where i am", "dont move lost"],
                triggerTokenGroups: [["stay", "put"], ["not", "move"]],
                summary: "Sometimes the safest navigation choice is not to keep moving.",
                whatMatters: "If visibility, hazard, injury, or uncertainty is high, staying put may be the safer route decision.",
                steps: [
                    "Stay put if moving is likely to increase exposure, confusion, or separation.",
                    "Improve shelter, warmth, water, or signalling while you wait.",
                    "Reassess movement only when you have better light, route confidence, or official direction."
                ],
                avoid: ["Do not keep walking into worsening hazard just because stopping feels passive."],
                confidenceBoundary: "This is a safety decision, not a comfort decision. Reassess when conditions improve."
            ),
            survival(
                id: "regrouping_meeting_points",
                displayName: "Regrouping / meeting points",
                topic: .navigationResponse,
                urgency: .planning,
                triggerTerms: ["meeting point", "regroup point", "where do we meet"],
                alternateTriggerPhrases: ["rally point", "family meeting point"],
                triggerTokenGroups: [["meeting", "point"], ["regroup", "point"], ["rally", "point"]],
                summary: "A simple rally plan reduces panic when the group separates.",
                whatMatters: "Choose obvious meeting points and agree what happens if the first one is not safe.",
                steps: [
                    "Choose one clear primary meeting point and one backup.",
                    "Make sure everyone knows when to move to the backup point.",
                    "Tie the meeting plan to the route and contact plan."
                ],
                avoid: ["Do not use vague or moving locations as rally points."],
                confidenceBoundary: "Rally points only work if the route to them stays safe and the group actually knows the plan.",
                relatedGuideIDs: ["set_simple_rally_points"],
                groundingGuideID: "set_simple_rally_points",
                fastPathEligible: false,
                contextInjectors: [.dependents]
            ),

            // Vehicle
            survival(
                id: "stranded_vehicle",
                displayName: "Stranded vehicle",
                topic: .vehicleResponse,
                urgency: .urgent,
                triggerTerms: ["stranded vehicle", "vehicle breakdown", "stuck in car", "car broken down"],
                alternateTriggerPhrases: ["broke down", "stranded on road"],
                triggerTokenGroups: [["vehicle", "breakdown"], ["stuck", "car"], ["stranded", "vehicle"]],
                summary: "A stranded vehicle is often a shelter, signal point, and known location all at once.",
                whatMatters: "Stay with the vehicle unless leaving is clearly safer and you know exactly where you are going.",
                steps: [
                    "Check whether staying with the vehicle is safer than walking.",
                    "Use the vehicle as shelter and a visible reference point if it is safe to stay.",
                    "Conserve water, battery, and energy while you plan the next step."
                ],
                avoid: ["Do not leave the vehicle into heat, cold, darkness, or poor visibility without a clear safe plan."],
                confidenceBoundary: "Vehicle decisions depend on heat, cold, water, traffic risk, and whether help knows where you are.",
                relatedGuideIDs: ["vehicle_trip_check_in_routine"],
                groundingGuideID: "vehicle_trip_check_in_routine",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.vehicle, .noSignal, .heat, .cold]
            ),
            survival(
                id: "stay_with_vehicle_or_leave",
                displayName: "Stay with vehicle or leave",
                topic: .vehicleResponse,
                urgency: .urgent,
                triggerTerms: ["stay or leave vehicle", "leave car or stay", "should i stay with car"],
                alternateTriggerPhrases: ["leave the vehicle", "walk from car"],
                triggerTokenGroups: [["stay", "vehicle"], ["leave", "car"]],
                summary: "Leaving a vehicle is a route decision, not just a frustration decision.",
                whatMatters: "Leave only if the vehicle itself is unsafe or you have a clearly safer destination, route, and timing.",
                steps: [
                    "Stay with the vehicle if it is safe, visible, and offers shelter.",
                    "Leave only if you know the safer destination and route and the conditions support the move.",
                    "Take water, signalling gear, navigation, and dependent needs if you must move."
                ],
                avoid: ["Do not walk away from the vehicle in heat, darkness, or poor route confidence just to keep moving."],
                confidenceBoundary: "If route confidence is low, staying with the vehicle is often safer than speculative movement.",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.vehicle, .noSignal, .routeRisk]
            ),
            survival(
                id: "extraction_waiting",
                displayName: "Extraction waiting",
                topic: .vehicleResponse,
                urgency: .planning,
                triggerTerms: ["waiting for extraction", "waiting for help vehicle", "rescue waiting"],
                alternateTriggerPhrases: ["stay and wait for help", "waiting for pickup"],
                triggerTokenGroups: [["waiting", "help"], ["waiting", "pickup"], ["rescue", "waiting"]],
                summary: "Waiting safely is a real survival task, not inactivity.",
                whatMatters: "Use the waiting time to protect water, shelter, signalling, and morale.",
                steps: [
                    "Set up shade, warmth, or weather protection first.",
                    "Protect water, battery, and signalling tools.",
                    "Use planned check-ins or signalling intervals instead of constant wasted effort."
                ],
                avoid: ["Do not burn fuel, battery, or water without a reason."],
                confidenceBoundary: "Waiting is only safe if the current position is safer than movement and the group can sustain it.",
                fastPathEligible: false,
                contextInjectors: [.vehicle, .noSignal]
            ),
            survival(
                id: "vehicle_heat_cold_survival",
                displayName: "Vehicle heat / cold survival basics",
                topic: .vehicleResponse,
                urgency: .urgent,
                triggerTerms: ["stuck in car heat", "sleep in car cold", "vehicle cold survival", "vehicle heat survival"],
                alternateTriggerPhrases: ["hot car stranded", "cold car stranded"],
                triggerTokenGroups: [["stuck", "car", "heat"], ["car", "cold"], ["vehicle", "heat"]],
                summary: "A vehicle can protect you or worsen heat and cold stress depending on how you use it.",
                whatMatters: "Control heat, cold, airflow, and hydration deliberately rather than reacting late.",
                steps: [
                    "Use shade, airflow, insulation, and clothing to reduce heat or cold load.",
                    "Protect water and critical battery reserves.",
                    "Reassess whether the vehicle remains the safest shelter as conditions change."
                ],
                avoid: ["Do not let the vehicle become an oven or a damp cold trap without adjusting shelter strategy."],
                confidenceBoundary: "If people are becoming confused, drowsy, or collapsing, switch to medical guidance immediately.",
                contextInjectors: [.vehicle, .heat, .cold]
            ),
            survival(
                id: "fuel_conservation",
                displayName: "Fuel conservation",
                topic: .vehicleResponse,
                urgency: .planning,
                triggerTerms: ["save fuel", "fuel conservation", "low fuel emergency"],
                alternateTriggerPhrases: ["stretch fuel", "running low on fuel"],
                triggerTokenGroups: [["save", "fuel"], ["low", "fuel"]],
                summary: "Fuel is mobility, power, and sometimes climate control all at once.",
                whatMatters: "Use fuel only where it clearly improves safety or the chance of getting out.",
                steps: [
                    "Stop unnecessary idling and unnecessary trips.",
                    "Reserve fuel for confirmed movement, charging, or climate control that prevents harm.",
                    "Re-check route and destination before spending fuel on movement."
                ],
                avoid: ["Do not burn fuel just to feel active when the route is unclear."],
                confidenceBoundary: "Fuel choices depend on route confidence, weather, and whether help is already coming.",
                fastPathEligible: false,
                contextInjectors: [.vehicle]
            ),

            // Sanitation / hygiene
            survival(
                id: "waste_handling",
                displayName: "Waste handling",
                topic: .sanitationResponse,
                urgency: .planning,
                triggerTerms: ["waste handling", "human waste emergency", "toilet not working"],
                alternateTriggerPhrases: ["no toilet waste", "manage waste emergency"],
                triggerTokenGroups: [["waste", "handling"], ["toilet", "working"]],
                summary: "Waste problems become health problems quickly when water and cleaning are limited.",
                whatMatters: "Separate waste from food, water, and living areas as early as possible.",
                steps: [
                    "Choose one waste area away from food, water, and sleeping space.",
                    "Keep waste containers or latrine areas clearly separate.",
                    "Clean hands after handling waste as well as conditions allow."
                ],
                avoid: ["Do not allow waste to accumulate around food prep or sleeping areas."],
                confidenceBoundary: "If sewage contamination is widespread, escalate to broader contamination avoidance and cleanup guidance.",
                fastPathEligible: false
            ),
            survival(
                id: "hand_hygiene_limited_water",
                displayName: "Hand hygiene when water is limited",
                topic: .sanitationResponse,
                urgency: .urgent,
                triggerTerms: ["wash hands no water", "hand hygiene limited water", "clean hands without much water"],
                alternateTriggerPhrases: ["limited water hygiene", "hand cleaning emergency"],
                triggerTokenGroups: [["hand", "hygiene"], ["wash", "hands"], ["limited", "water"]],
                summary: "Hand hygiene matters even more when healthcare, water, and food safety are limited.",
                whatMatters: "Use the cleanest method you have before eating, after toilet use, and before wound care.",
                steps: [
                    "Prioritise hand cleaning before food, medicines, and wound care.",
                    "Use soap and safe water when you can, or sanitizer if available.",
                    "Keep one small clean-water reserve for hygiene-critical tasks if supplies are tight."
                ],
                avoid: ["Do not spend all stored water on general washing if drinking water is already critical."],
                confidenceBoundary: "Limited-water hygiene is about priority use, not perfect cleanliness.",
                relatedGuideIDs: ["hygiene_when_water_is_limited"],
                groundingGuideID: "hygiene_when_water_is_limited",
                contextInjectors: [.noWater]
            ),
            survival(
                id: "latrine_basics",
                displayName: "Latrine basics",
                topic: .sanitationResponse,
                urgency: .planning,
                triggerTerms: ["latrine", "makeshift toilet", "emergency toilet"],
                alternateTriggerPhrases: ["field toilet", "temporary toilet"],
                triggerTokenGroups: [["emergency", "toilet"], ["makeshift", "toilet"], ["latrine"]],
                summary: "Toilet planning is mainly about distance from food, water, and sleeping areas.",
                whatMatters: "Place the toilet area where it is private, stable, and away from water flow and food handling.",
                steps: [
                    "Choose a toilet area away from water, food, and sleeping space.",
                    "Keep toilet materials and hand-cleaning materials together.",
                    "Mark the area clearly so children and visitors do not contaminate living space."
                ],
                avoid: ["Do not place a latrine where runoff can carry waste into living or water areas."],
                confidenceBoundary: "Ground and runoff conditions matter. Use a safer waste system if the site is unstable or flood-prone.",
                fastPathEligible: false,
                contextInjectors: [.dependents]
            ),
            survival(
                id: "contamination_reduction",
                displayName: "Contamination reduction",
                topic: .sanitationResponse,
                urgency: .urgent,
                triggerTerms: ["avoid contamination", "reduce contamination", "dirty cleanup safety"],
                alternateTriggerPhrases: ["contamination reduction", "cleanup contamination"],
                triggerTokenGroups: [["reduce", "contamination"], ["avoid", "contamination"]],
                summary: "Contamination spreads when clean and dirty zones are not separated.",
                whatMatters: "Separate dirty cleanup work from clean food, wound care, and sleeping areas.",
                steps: [
                    "Keep dirty gear and dirty shoes out of clean living space.",
                    "Separate cleanup clothing and tools from food and bedding.",
                    "Wash or sanitize hands after cleanup tasks."
                ],
                avoid: ["Do not carry floodwater or contaminated cleanup gear through clean areas unnecessarily."],
                confidenceBoundary: "If sewage, chemicals, or mould are involved, use the stricter cleanup and exposure path.",
                relatedGuideIDs: ["safe_cleanup_after_disaster", "mould_and_contamination_cleanup"],
                groundingGuideID: "safe_cleanup_after_disaster"
            ),

            // General prep
            survival(
                id: "go_bag_basics",
                displayName: "Go-bag basics",
                topic: .goBagResponse,
                urgency: .planning,
                triggerTerms: ["go bag", "grab bag", "evacuation bag", "what goes in go bag"],
                alternateTriggerPhrases: ["bug out bag", "grab and go kit"],
                triggerTokenGroups: [["go", "bag"], ["grab", "bag"], ["evacuation", "bag"]],
                summary: "A go-bag is about fast movement, not carrying the whole house.",
                whatMatters: "Pack the items that protect identity, medicines, water, communication, and movement first.",
                steps: [
                    "Pack medicines, documents, phone power, water, and basic clothing first.",
                    "Add child, pet, and special medical items before comfort extras.",
                    "Keep the bag easy to grab and ready near the exit."
                ],
                avoid: ["Do not overload the bag so much that it slows departure."],
                confidenceBoundary: "A go-bag supports movement but does not replace route, shelter, and household plans.",
                contextInjectors: [.dependents, .pets]
            ),
            survival(
                id: "medications_documents_prioritisation",
                displayName: "Medications / documents prioritisation",
                topic: .goBagResponse,
                urgency: .urgent,
                triggerTerms: ["take medications first", "important documents emergency", "what documents first"],
                alternateTriggerPhrases: ["prioritise medicines", "id and medicines emergency"],
                triggerTokenGroups: [["important", "documents"], ["medications", "first"], ["documents", "first"]],
                summary: "In fast movement, medicines and identity often matter more than extra gear.",
                whatMatters: "Take what cannot be replaced quickly or safely if you are away from home.",
                steps: [
                    "Take essential medicines and medical devices first.",
                    "Take identification, key records, and emergency contacts.",
                    "Then add chargers, water, and the next most critical movement items."
                ],
                avoid: ["Do not waste the safest leave window collecting low-value items first."],
                confidenceBoundary: "Critical document priorities change with family, legal, and medical needs. Keep the shortlist current.",
                relatedGuideIDs: ["assemble_family_medications"],
                groundingGuideID: "assemble_family_medications",
                contextInjectors: [.dependents]
            ),
            survival(
                id: "family_dependents_prep",
                displayName: "Family / dependents preparation",
                topic: .goBagResponse,
                urgency: .planning,
                triggerTerms: ["prepare children emergency", "family prep emergency", "dependents emergency"],
                alternateTriggerPhrases: ["prepare family evacuation", "children emergency plan"],
                triggerTokenGroups: [["family", "prep"], ["dependents"], ["children", "emergency"]],
                summary: "Dependents change how long every emergency task takes.",
                whatMatters: "Build the plan around the slowest, youngest, oldest, or most medically complex person first.",
                steps: [
                    "List medicines, comfort items, transport needs, and contact details for each dependent.",
                    "Keep these items together so departure is faster.",
                    "Practice the plan so each person knows the first move."
                ],
                avoid: ["Do not assume dependents can adapt quickly without rehearsal or dedicated gear."],
                confidenceBoundary: "Family prep must reflect real mobility, medication, and supervision needs, not ideal assumptions.",
                fastPathEligible: false,
                contextInjectors: [.dependents]
            ),
            survival(
                id: "pet_prep",
                displayName: "Pet preparation",
                topic: .goBagResponse,
                urgency: .planning,
                triggerTerms: ["pet emergency prep", "prepare pets evacuation", "pet go bag"],
                alternateTriggerPhrases: ["pet plan", "pet emergency"],
                triggerTokenGroups: [["pet", "prep"], ["pet", "bag"], ["prepare", "pets"]],
                summary: "Pets slow departure if their gear and containment are not ready beforehand.",
                whatMatters: "Leads, carriers, food, water, and proof of ownership matter early.",
                steps: [
                    "Keep leads, carriers, pet food, and water ready near the exit.",
                    "Add medications, vaccination details, and cleaning supplies.",
                    "Move pets early rather than trying to collect them at the last minute."
                ],
                avoid: ["Do not assume stressed pets will load quickly without carriers or leads."],
                confidenceBoundary: "Pet movement depends on containment, transport, and the destination being pet-compatible.",
                fastPathEligible: false,
                contextInjectors: [.pets]
            ),
            survival(
                id: "home_emergency_basics",
                displayName: "Home emergency basics",
                topic: .goBagResponse,
                urgency: .planning,
                triggerTerms: ["home emergency basics", "basic emergency prep home", "prepare home emergency"],
                alternateTriggerPhrases: ["home emergency plan", "household emergency basics"],
                triggerTokenGroups: [["home", "emergency"], ["prepare", "home"]],
                summary: "Most household readiness comes down to water, power, documents, and movement planning.",
                whatMatters: "Build from essentials that work across multiple hazards rather than one-off purchases.",
                steps: [
                    "Start with water, lights, charging, medicines, and documents.",
                    "Choose a simple contact plan and rally point.",
                    "Review evacuation and shelter options before the next alert day."
                ],
                avoid: ["Do not build a plan that depends on internet, live shopping, or last-minute fuel."],
                confidenceBoundary: "Home readiness should still be adapted to local hazards and dependent needs.",
                fastPathEligible: false,
                contextInjectors: [.dependents, .pets]
            ),
            survival(
                id: "evacuation_checklist",
                displayName: "Evacuation checklist",
                topic: .goBagResponse,
                urgency: .urgent,
                triggerTerms: ["evacuation checklist", "what do i take leaving", "leave checklist"],
                alternateTriggerPhrases: ["evacuation list", "leaving checklist"],
                triggerTokenGroups: [["evacuation", "checklist"], ["leave", "checklist"]],
                summary: "A good checklist protects the first minute of departure.",
                whatMatters: "Take what keeps people identified, medicated, hydrated, reachable, and movable.",
                steps: [
                    "Take medicines, documents, chargers, water, and keys first.",
                    "Load children, pets, and anyone needing assistance early.",
                    "Check the route once more before you move."
                ],
                avoid: ["Do not let optional packing push departure later than planned."],
                confidenceBoundary: "Checklist order should tighten as route risk rises or official warnings escalate.",
                relatedGuideIDs: ["household_evacuation_quick_start"],
                groundingGuideID: "household_evacuation_quick_start",
                shouldPrioritizePrimaryAction: true,
                primaryAction: .reviewRouteIfAvailable,
                contextInjectors: [.dependents, .pets, .routeRisk]
            )
        ]
    }
}

private extension AssistantSurvivalProtocolCatalog {
    static func survival(
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
        confidenceBoundary: String,
        emergencyEscalation: String? = nil,
        relatedGuideIDs: [String] = [],
        groundingGuideID: String? = nil,
        fastPathEligible: Bool = true,
        shouldPrioritizePrimaryAction: Bool = false,
        primaryAction: AssistantProtocolPrimaryAction = .none,
        contextInjectors: [AssistantProtocolContextInjector] = [],
        safeFallbackPolicy: AssistantProtocolFallbackPolicy = .planningPolicy,
        reviewSources: [AssistantProtocolReviewSource] = [.stJohnAustralia, .healthdirectAustralia],
        regionScope: AssistantRegionScope = .general
    ) -> AssistantProtocolDefinition {
        AssistantProtocolDefinition(
            id: id,
            displayName: displayName,
            domain: .survival,
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
            shouldPrioritizePrimaryAction: shouldPrioritizePrimaryAction,
            fastPathEligible: fastPathEligible,
            primaryAction: primaryAction,
            contextInjectors: contextInjectors,
            safeFallbackPolicy: safeFallbackPolicy,
            relatedGuideIDs: relatedGuideIDs,
            groundingGuideID: groundingGuideID,
            verificationStatus: groundingGuideID == nil ? .sourceReviewRequired : .guideGrounded,
            reviewSources: reviewSources,
            regionScope: regionScope
        )
    }
}

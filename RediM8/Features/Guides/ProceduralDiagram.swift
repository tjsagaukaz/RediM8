import Foundation

// MARK: - Procedural Diagram Model

/// Maps a guide step index to a visual diagram specification.
/// Each guide that supports procedural diagrams declares its step→diagram mapping here.
struct ProceduralDiagramStep: Identifiable {
    let id: String
    let stepIndex: Int
    let title: String
    let focusLabel: String
    let highlightParts: [String]
}

/// Registry of which guides have procedural step diagrams and what each step shows.
enum ProceduralDiagramRegistry {

    /// Returns the procedural steps for a guide, or nil if the guide has no procedural diagrams.
    static func steps(for guideID: String) -> [ProceduralDiagramStep]? {
        switch guideID {
        case "bow_drill_fire":
            return bowDrillSteps
        case "debris_hut_shelter":
            return debrisHutSteps
        case "solar_still_construction":
            return solarStillSteps
        case "basic_snares_small_game":
            return basicSnareSteps
        case "waste_disposal_distance_rules":
            return wasteDisposalSteps
        default:
            return nil
        }
    }

    /// Returns true if a guide has procedural diagrams.
    static func hasDiagrams(for guideID: String) -> Bool {
        steps(for: guideID) != nil
    }

    // MARK: - Bow Drill Fire (5 visual steps covering 9 text steps)

    private static let bowDrillSteps: [ProceduralDiagramStep] = [
        ProceduralDiagramStep(
            id: "bow_drill_1",
            stepIndex: 0,
            title: "Components",
            focusLabel: "GATHER THESE 4 PARTS",
            highlightParts: ["fireboard", "spindle", "bow", "bearing_block"]
        ),
        ProceduralDiagramStep(
            id: "bow_drill_2",
            stepIndex: 4,
            title: "Assembly",
            focusLabel: "STRING → SPINDLE → BOARD",
            highlightParts: ["bowstring_wrap", "spindle_on_board", "bearing_press"]
        ),
        ProceduralDiagramStep(
            id: "bow_drill_3",
            stepIndex: 5,
            title: "Sawing Motion",
            focusLabel: "FULL STROKES ← →",
            highlightParts: ["bow_motion", "downward_pressure", "spindle_rotation"]
        ),
        ProceduralDiagramStep(
            id: "bow_drill_4",
            stepIndex: 6,
            title: "Ember Formation",
            focusLabel: "WATCH THE V-NOTCH",
            highlightParts: ["smoke", "v_notch", "ember_dust"]
        ),
        ProceduralDiagramStep(
            id: "bow_drill_5",
            stepIndex: 7,
            title: "Transfer to Tinder",
            focusLabel: "TIP → WRAP → BLOW",
            highlightParts: ["ember_transfer", "tinder_bundle", "blow_direction"]
        ),
    ]

    // MARK: - Debris Hut Shelter (5 visual steps covering 9 text steps)

    private static let debrisHutSteps: [ProceduralDiagramStep] = [
        ProceduralDiagramStep(
            id: "debris_hut_1",
            stepIndex: 0,
            title: "Ridgepole",
            focusLabel: "MAIN BEAM 2.5–3M",
            highlightParts: ["ridgepole", "support_fork", "ground_end"]
        ),
        ProceduralDiagramStep(
            id: "debris_hut_2",
            stepIndex: 2,
            title: "Rib Structure",
            focusLabel: "30° ANGLE · 30CM APART",
            highlightParts: ["rib_sticks", "angle_markers", "spacing"]
        ),
        ProceduralDiagramStep(
            id: "debris_hut_3",
            stepIndex: 3,
            title: "Lattice Layer",
            focusLabel: "STICKS + BRUSH OVER RIBS",
            highlightParts: ["lattice", "cross_sticks"]
        ),
        ProceduralDiagramStep(
            id: "debris_hut_4",
            stepIndex: 4,
            title: "Insulation",
            focusLabel: "60CM+ THICK ALL OVER",
            highlightParts: ["leaf_layer", "thickness_marker", "ground_insulation"]
        ),
        ProceduralDiagramStep(
            id: "debris_hut_5",
            stepIndex: 7,
            title: "Entrance Seal",
            focusLabel: "PLUG WITH DEBRIS",
            highlightParts: ["entrance", "door_plug", "body_space"]
        ),
    ]

    // MARK: - Solar Still (5 visual steps covering 8 text steps)

    private static let solarStillSteps: [ProceduralDiagramStep] = [
        ProceduralDiagramStep(
            id: "solar_still_1",
            stepIndex: 0,
            title: "Dig the Pit",
            focusLabel: "60CM DEEP · 90CM WIDE",
            highlightParts: ["hole", "dimensions", "sun_position"]
        ),
        ProceduralDiagramStep(
            id: "solar_still_2",
            stepIndex: 1,
            title: "Place Container",
            focusLabel: "CENTRE OF HOLE",
            highlightParts: ["container", "centre_position"]
        ),
        ProceduralDiagramStep(
            id: "solar_still_3",
            stepIndex: 2,
            title: "Add Vegetation",
            focusLabel: "AROUND · NOT IN",
            highlightParts: ["vegetation", "container_clear"]
        ),
        ProceduralDiagramStep(
            id: "solar_still_4",
            stepIndex: 3,
            title: "Seal with Plastic",
            focusLabel: "AIRTIGHT EDGES",
            highlightParts: ["plastic_sheet", "edge_seal", "centre_stone"]
        ),
        ProceduralDiagramStep(
            id: "solar_still_5",
            stepIndex: 5,
            title: "Condensation Cycle",
            focusLabel: "HEAT → EVAP → DRIP",
            highlightParts: ["sun_rays", "evaporation", "condensation", "drip_path"]
        ),
    ]

    // MARK: - Basic Snare (4 visual steps covering 9 text steps)

    private static let basicSnareSteps: [ProceduralDiagramStep] = [
        ProceduralDiagramStep(
            id: "snare_1",
            stepIndex: 1,
            title: "Loop Construction",
            focusLabel: "RUNNING LOOP · FIST SIZE",
            highlightParts: ["wire_loop", "running_knot", "size_reference"]
        ),
        ProceduralDiagramStep(
            id: "snare_2",
            stepIndex: 2,
            title: "Trail Placement",
            focusLabel: "ON THE RUN · 4 FINGERS UP",
            highlightParts: ["animal_trail", "loop_height", "anchor_stake"]
        ),
        ProceduralDiagramStep(
            id: "snare_3",
            stepIndex: 7,
            title: "Funnel Guide",
            focusLabel: "FORCE THROUGH THE LOOP",
            highlightParts: ["funnel_sticks", "narrowing_channel", "snare_centre"]
        ),
        ProceduralDiagramStep(
            id: "snare_4",
            stepIndex: 8,
            title: "Drag Snare",
            focusLabel: "HEAVY LOG · NOT FIXED",
            highlightParts: ["drag_log", "wire_connection", "drag_path"]
        ),
    ]

    // MARK: - Waste Disposal (4 visual steps covering 8 text steps)

    private static let wasteDisposalSteps: [ProceduralDiagramStep] = [
        ProceduralDiagramStep(
            id: "waste_1",
            stepIndex: 0,
            title: "Distance Layout",
            focusLabel: "60M FROM WATER · CAMP · FOOD",
            highlightParts: ["camp", "water_source", "latrine_zone", "distance_markers"]
        ),
        ProceduralDiagramStep(
            id: "waste_2",
            stepIndex: 1,
            title: "Cat Hole",
            focusLabel: "15–20CM DEEP · COVER AFTER",
            highlightParts: ["hole_cross_section", "depth_marker", "cover_soil"]
        ),
        ProceduralDiagramStep(
            id: "waste_3",
            stepIndex: 2,
            title: "Slit Trench",
            focusLabel: "30CM × 60CM × 1M+",
            highlightParts: ["trench_cross_section", "dimensions", "fill_level"]
        ),
        ProceduralDiagramStep(
            id: "waste_4",
            stepIndex: 4,
            title: "Hand Hygiene",
            focusLabel: "ASH + WATER · SAND SCRUB",
            highlightParts: ["hands", "ash_pile", "water_pour"]
        ),
    ]
}

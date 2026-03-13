import SwiftUI

struct RediIcon: View {
    let name: String
    let fallbackSystemName: String?

    init(_ name: String, fallbackSystemName: String? = nil) {
        self.name = name
        self.fallbackSystemName = fallbackSystemName
    }

    @ViewBuilder
    var body: some View {
        // The bundled PDF icon assets are JPEG-backed and render as tinted squares in template mode.
        // Prefer explicit SF Symbols for UI chrome until the asset pipeline is rebuilt with transparency.
        Image(systemName: Self.systemName(for: name, fallbackSystemName: fallbackSystemName))
    }

    static func mappedSystemName(for name: String) -> String? {
        symbolMap[name]
    }

    static func systemName(for name: String, fallbackSystemName: String? = nil) -> String {
        fallbackSystemName ?? mappedSystemName(for: name) ?? name
    }

    private static let symbolMap: [String: String] = [
        "emergency": "phone.connection.fill",
        "warning": "exclamationmark.triangle.fill",
        "alert": "exclamationmark.circle.fill",
        "beacon": "dot.radiowaves.left.and.right",
        "radio": "dot.radiowaves.left.and.right",
        "signal": "antenna.radiowaves.left.and.right",
        "go_bag": "backpack.fill",
        "first_aid": "cross.case.fill",
        "documents": "doc.on.doc.fill",
        "battery": "battery.100",
        "flashlight": "flashlight.on.fill",
        "power_bank": "battery.100",
        "water": "drop.fill",
        "shelter": "house.fill",
        "shield": "shield.fill",
        "fuel": "fuelpump.fill",
        "medical": "cross.case.fill",
        "pharmacy": "pills.fill",
        "food": "fork.knife",
        "compass": "location.north.line.fill",
        "map_marker": "map.fill",
        "route": "arrow.triangle.turn.up.right.diamond.fill",
        "dirt_road": "road.lanes",
        "fire_trail": "flame.fill",
        "flood": "water.waves",
        "airstrip": "airplane",
        "vehicle": "car.fill",
        "four_wd": "car.fill",
        "tent": "figure.hiking",
        "camp": "tree.fill",
        "fire_extinguisher": "flame.circle.fill",
        "fire_blanket": "shield.fill",
        "rope": "link",
        "whistle": "speaker.wave.2.fill",
        "knife": "scissors",
        "pet": "pawprint.fill",
        "pets": "pawprint.fill",
        "dog": "pawprint.fill",
        "livestock": "pawprint.fill",
        "family": "person.2.fill",
        "meeting_point": "mappin.and.ellipse",
        "home": "house.fill",
        "airstrip_marker": "airplane",
        "campground_marker": "figure.hiking",
        "checkpoint_marker": "xmark.circle.fill",
        "community_beacon_marker": "dot.radiowaves.left.and.right",
        "dirt_road_marker": "road.lanes",
        "flood_marker": "water.waves",
        "fire_trail_marker": "flame.fill",
        "food_marker": "fork.knife",
        "fourwd_track_marker": "car.fill",
        "fuel_marker": "fuelpump.fill",
        "hardware_store_marker": "hammer",
        "hospital_marker": "cross.case.fill",
        "layer_airstrips": "airplane",
        "layer_beacons": "antenna.radiowaves.left.and.right",
        "layer_fire_trails": "flame.fill",
        "layer_roads": "road.lanes",
        "layer_shelters": "house.fill",
        "layer_water": "drop.fill",
        "map_legend": "map.fill",
        "medical_marker": "cross.case.fill",
        "outback_supply_marker": "shippingbox.fill",
        "pharmacy_marker": "pills.fill",
        "police_marker": "shield.fill",
        "radio_marker": "dot.radiowaves.left.and.right",
        "remote_water_marker": "drop.fill",
        "road_blocked": "xmark.octagon.fill",
        "road_blocked_marker": "xmark.octagon.fill",
        "route_marker": "arrow.triangle.turn.up.right.diamond.fill",
        "shelter_marker": "house.fill",
        "signal_node_marker": "antenna.radiowaves.left.and.right",
        "warning_marker": "exclamationmark.triangle.fill",
        "water_marker": "drop.fill",
    ]
}

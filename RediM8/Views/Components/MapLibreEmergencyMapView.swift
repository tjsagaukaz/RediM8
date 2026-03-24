import MapKit
import MapLibre
import SwiftUI
import UIKit

struct MapLibreEmergencyMapView: UIViewRepresentable {
    let styleURL: URL
    let region: MKCoordinateRegion
    let regionRevision: Int
    let availablePacks: [OfflineMapPack]
    let installedPackIDs: Set<String>
    let contextDirtRoads: [TrackSegment]
    let contextFireTrails: [TrackSegment]
    let resourceMarkers: [ResourceMarker]
    let dirtRoads: [TrackSegment]
    let fireTrails: [TrackSegment]
    let waterPoints: [WaterPoint]
    let shelters: [ShelterLocation]
    let officialAlerts: [OfficialAlert]
    let beacons: [CommunityBeacon]
    let currentLocation: CLLocation?
    let heading: CLLocationDirection
    let showsUserLocation: Bool
    let showsDistanceRings: Bool
    let animatesRegionChanges: Bool
    let onSelectShelter: (String?) -> Void
    var onSelectFeature: ((MapSelectedFeature?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyStyleIfNeeded(on: mapView)
        mapView.showsUserLocation = false
        context.coordinator.refreshIfNeeded(on: mapView)
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        private enum SourceID {
            static let availablePackCoverage = "redim8-available-pack-coverage-source"
            static let installedPackCoverage = "redim8-installed-pack-coverage-source"
            static let availablePackLabels = "redim8-available-pack-labels-source"
            static let installedPackLabels = "redim8-installed-pack-labels-source"
            static let corridorContext = "redim8-corridor-context-source"
            static let graticule = "redim8-graticule-source"
            static let distanceRings = "redim8-distance-rings-source"
            static let currentLocation = "redim8-current-location-source"
            static let resources = "redim8-resources-source"
            static let dirtRoads = "redim8-dirt-roads-source"
            static let fireTrails = "redim8-fire-trails-source"
            static let waterPoints = "redim8-water-points-source"
            static let shelters = "redim8-shelters-source"
            static let officialAlerts = "redim8-official-alerts-source"
            static let beacons = "redim8-beacons-source"
        }

        private enum LayerID {
            static let availablePackCoverage = "redim8-available-pack-coverage-layer"
            static let installedPackCoverage = "redim8-installed-pack-coverage-layer"
            static let packOutline = "redim8-pack-outline-layer"
            static let corridorContext = "redim8-corridor-context-layer"
            static let availablePackLabels = "redim8-available-pack-labels-layer"
            static let installedPackLabels = "redim8-installed-pack-labels-layer"
            static let graticule = "redim8-graticule-layer"
            static let distanceRings = "redim8-distance-rings-layer"
            static let currentLocationPulse = "redim8-current-location-pulse-layer"
            static let currentLocationCore = "redim8-current-location-core-layer"
            static let currentLocationHeading = "redim8-current-location-heading-layer"
            static let dirtRoads = "redim8-dirt-roads-layer"
            static let fireTrails = "redim8-fire-trails-layer"
            static let resources = "redim8-resources-layer"
            static let waterPoints = "redim8-water-points-layer"
            static let shelters = "redim8-shelters-layer"
            static let officialAlerts = "redim8-official-alerts-layer"
            static let beacons = "redim8-beacons-layer"
        }

        private enum FeatureKey {
            static let id = "id"
            static let markerIcon = "marker_icon"
            static let title = "title"
            static let subtitle = "subtitle"
            static let capacity = "capacity"
            static let quality = "quality"
            static let kind = "kind"
            static let heading = "heading"
        }

        var parent: MapLibreEmergencyMapView
        weak var mapView: MLNMapView?
        private var didFinishLoadingStyle = false
        private var lastRenderedSignature = ""
        private var lastRegionRevision = -1

        init(parent: MapLibreEmergencyMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            didFinishLoadingStyle = true
            registerMarkerImages(on: style)
            installRuntimeLayersIfNeeded(on: style)
            refreshSources(on: style)
            applyRegionIfNeeded(on: mapView)
        }

        func refreshIfNeeded(on mapView: MLNMapView) {
            guard didFinishLoadingStyle, let style = mapView.style else {
                return
            }

            registerMarkerImages(on: style)
            refreshSources(on: style)
            applyRegionIfNeeded(on: mapView)
        }

        func applyStyleIfNeeded(on mapView: MLNMapView) {
            guard mapView.styleURL != parent.styleURL else {
                return
            }

            didFinishLoadingStyle = false
            lastRenderedSignature = ""
            lastRegionRevision = -1
            mapView.styleURL = parent.styleURL
        }

        private func installRuntimeLayersIfNeeded(on style: MLNStyle) {
            ensureFillLayer(
                on: style,
                sourceID: SourceID.availablePackCoverage,
                layerID: LayerID.availablePackCoverage,
                color: UIColor(red: 0.05, green: 0.12, blue: 0.10, alpha: 1),
                outlineColor: UIColor(red: 0.10, green: 0.28, blue: 0.22, alpha: 1),
                opacity: 0.58
            )
            ensureFillLayer(
                on: style,
                sourceID: SourceID.installedPackCoverage,
                layerID: LayerID.installedPackCoverage,
                color: UIColor(red: 0.06, green: 0.22, blue: 0.16, alpha: 1),
                outlineColor: UIColor(red: 0.18, green: 0.56, blue: 0.39, alpha: 1),
                opacity: 0.72
            )
            ensureLineLayer(
                on: style,
                sourceID: SourceID.availablePackCoverage,
                layerID: LayerID.packOutline,
                color: UIColor(red: 0.14, green: 0.42, blue: 0.31, alpha: 1),
                width: 1.0,
                dashPattern: [2.0, 1.8],
                opacity: 0.68
            )
            ensureLineLayer(
                on: style,
                sourceID: SourceID.corridorContext,
                layerID: LayerID.corridorContext,
                color: UIColor(red: 0.34, green: 0.49, blue: 0.42, alpha: 1),
                width: 1.4,
                dashPattern: [],
                opacity: 0.42
            )
            ensureTextLayer(
                on: style,
                sourceID: SourceID.availablePackLabels,
                layerID: LayerID.availablePackLabels,
                color: UIColor(red: 0.56, green: 0.69, blue: 0.63, alpha: 1),
                haloColor: UIColor(red: 0.01, green: 0.03, blue: 0.02, alpha: 1),
                haloWidth: 0.8,
                fontSize: 11
            )
            ensureTextLayer(
                on: style,
                sourceID: SourceID.installedPackLabels,
                layerID: LayerID.installedPackLabels,
                color: UIColor(red: 0.54, green: 1.0, blue: 0.76, alpha: 1),
                haloColor: UIColor(red: 0.01, green: 0.03, blue: 0.02, alpha: 1),
                haloWidth: 1.0,
                fontSize: 12
            )
            ensureLineLayer(
                on: style,
                sourceID: SourceID.graticule,
                layerID: LayerID.graticule,
                color: UIColor(red: 0.08, green: 0.26, blue: 0.19, alpha: 1),
                width: 0.9,
                dashPattern: [2.0, 2.6],
                opacity: 0.52
            )
            ensureLineLayer(
                on: style,
                sourceID: SourceID.distanceRings,
                layerID: LayerID.distanceRings,
                color: UIColor(red: 0.16, green: 1.0, blue: 0.64, alpha: 1),
                width: 1.2,
                dashPattern: [1.2, 1.4],
                opacity: 0.72
            )
            ensureCircleLayer(
                on: style,
                sourceID: SourceID.currentLocation,
                layerID: LayerID.currentLocationPulse,
                fillColor: UIColor(red: 0.99, green: 0.76, blue: 0.24, alpha: 1),
                radius: 17,
                opacity: 0.18,
                strokeColor: UIColor(red: 0.99, green: 0.76, blue: 0.24, alpha: 1),
                strokeWidth: 1.2
            )
            ensureCircleLayer(
                on: style,
                sourceID: SourceID.currentLocation,
                layerID: LayerID.currentLocationCore,
                fillColor: UIColor.white,
                radius: 6.5,
                opacity: 0.96,
                strokeColor: UIColor(red: 0.99, green: 0.76, blue: 0.24, alpha: 1),
                strokeWidth: 2.0
            )
            ensureUserLocationHeadingLayer(
                on: style,
                sourceID: SourceID.currentLocation,
                layerID: LayerID.currentLocationHeading
            )
            ensureLineLayer(
                on: style,
                sourceID: SourceID.dirtRoads,
                layerID: LayerID.dirtRoads,
                color: UIColor(red: 0.55, green: 0.35, blue: 0.17, alpha: 1),
                width: 2.4,
                dashPattern: [2.2, 1.2],
                opacity: 0.96
            )
            ensureLineLayer(
                on: style,
                sourceID: SourceID.fireTrails,
                layerID: LayerID.fireTrails,
                color: UIColor(red: 1.0, green: 0.62, blue: 0.04, alpha: 1),
                width: 2.8,
                dashPattern: [1.1, 1.0],
                opacity: 0.98
            )
            ensureSymbolLayer(
                on: style,
                sourceID: SourceID.resources,
                layerID: LayerID.resources,
                iconScale: 0.68
            )
            ensureSymbolLayer(
                on: style,
                sourceID: SourceID.waterPoints,
                layerID: LayerID.waterPoints,
                iconScale: 0.82
            )
            ensureSymbolLayer(
                on: style,
                sourceID: SourceID.shelters,
                layerID: LayerID.shelters,
                iconScale: 0.88
            )
            ensureSymbolLayer(
                on: style,
                sourceID: SourceID.officialAlerts,
                layerID: LayerID.officialAlerts,
                iconScale: 0.84
            )
            ensureSymbolLayer(
                on: style,
                sourceID: SourceID.beacons,
                layerID: LayerID.beacons,
                iconScale: 0.74
            )
        }

        private func ensureFillLayer(
            on style: MLNStyle,
            sourceID: String,
            layerID: String,
            color: UIColor,
            outlineColor: UIColor,
            opacity: Double
        ) {
            let source = shapeSource(on: style, sourceID: sourceID)
            guard style.layer(withIdentifier: layerID) == nil else {
                return
            }

            let layer = MLNFillStyleLayer(identifier: layerID, source: source)
            layer.fillColor = NSExpression(forConstantValue: color)
            layer.fillOutlineColor = NSExpression(forConstantValue: outlineColor)
            layer.fillOpacity = NSExpression(forConstantValue: opacity)
            style.addLayer(layer)
        }

        private func ensureLineLayer(
            on style: MLNStyle,
            sourceID: String,
            layerID: String,
            color: UIColor,
            width: Double,
            dashPattern: [NSNumber],
            opacity: Double
        ) {
            let source = shapeSource(on: style, sourceID: sourceID)
            guard style.layer(withIdentifier: layerID) == nil else {
                return
            }

            let layer = MLNLineStyleLayer(identifier: layerID, source: source)
            layer.lineColor = NSExpression(forConstantValue: color)
            layer.lineWidth = NSExpression(forConstantValue: width)
            layer.lineOpacity = NSExpression(forConstantValue: opacity)
            if !dashPattern.isEmpty {
                layer.lineDashPattern = NSExpression(forConstantValue: dashPattern)
            }
            style.addLayer(layer)
        }

        private func ensureTextLayer(
            on style: MLNStyle,
            sourceID: String,
            layerID: String,
            color: UIColor,
            haloColor: UIColor,
            haloWidth: Double,
            fontSize: Double
        ) {
            let source = shapeSource(on: style, sourceID: sourceID)
            guard style.layer(withIdentifier: layerID) == nil else {
                return
            }

            let layer = MLNSymbolStyleLayer(identifier: layerID, source: source)
            layer.text = NSExpression(forKeyPath: FeatureKey.title)
            layer.textFontSize = NSExpression(forConstantValue: fontSize)
            layer.textColor = NSExpression(forConstantValue: color)
            layer.textHaloColor = NSExpression(forConstantValue: haloColor)
            layer.textHaloWidth = NSExpression(forConstantValue: haloWidth)
            layer.textAllowsOverlap = NSExpression(forConstantValue: false)
            style.addLayer(layer)
        }

        private func ensureCircleLayer(
            on style: MLNStyle,
            sourceID: String,
            layerID: String,
            fillColor: UIColor,
            radius: Double,
            opacity: Double,
            strokeColor: UIColor,
            strokeWidth: Double
        ) {
            let source = shapeSource(on: style, sourceID: sourceID)
            guard style.layer(withIdentifier: layerID) == nil else {
                return
            }

            let layer = MLNCircleStyleLayer(identifier: layerID, source: source)
            layer.circleColor = NSExpression(forConstantValue: fillColor)
            layer.circleRadius = NSExpression(forConstantValue: radius)
            layer.circleOpacity = NSExpression(forConstantValue: opacity)
            layer.circleStrokeColor = NSExpression(forConstantValue: strokeColor)
            layer.circleStrokeWidth = NSExpression(forConstantValue: strokeWidth)
            style.addLayer(layer)
        }

        private func ensureSymbolLayer(
            on style: MLNStyle,
            sourceID: String,
            layerID: String,
            iconScale: Double
        ) {
            let source = shapeSource(on: style, sourceID: sourceID)
            guard style.layer(withIdentifier: layerID) == nil else {
                return
            }

            let layer = MLNSymbolStyleLayer(identifier: layerID, source: source)
            layer.iconImageName = NSExpression(forKeyPath: FeatureKey.markerIcon)
            layer.iconScale = NSExpression(forConstantValue: iconScale)
            layer.iconAnchor = NSExpression(forConstantValue: "bottom")
            layer.iconAllowsOverlap = NSExpression(forConstantValue: true)
            layer.iconIgnoresPlacement = NSExpression(forConstantValue: true)
            layer.iconPitchAlignment = NSExpression(forConstantValue: "viewport")
            layer.iconRotationAlignment = NSExpression(forConstantValue: "viewport")
            layer.iconOpacity = NSExpression(forConstantValue: 0.98)
            style.addLayer(layer)
        }

        private func ensureUserLocationHeadingLayer(
            on style: MLNStyle,
            sourceID: String,
            layerID: String
        ) {
            let source = shapeSource(on: style, sourceID: sourceID)
            guard style.layer(withIdentifier: layerID) == nil else {
                return
            }

            let layer = MLNSymbolStyleLayer(identifier: layerID, source: source)
            layer.iconImageName = NSExpression(forConstantValue: "redim8-current-location-heading")
            layer.iconScale = NSExpression(forConstantValue: 0.9)
            layer.iconAllowsOverlap = NSExpression(forConstantValue: true)
            layer.iconIgnoresPlacement = NSExpression(forConstantValue: true)
            layer.iconRotation = NSExpression(forKeyPath: FeatureKey.heading)
            layer.iconRotationAlignment = NSExpression(forConstantValue: "viewport")
            layer.iconPitchAlignment = NSExpression(forConstantValue: "viewport")
            style.addLayer(layer)
        }

        private func registerMarkerImages(on style: MLNStyle) {
            let assetNames = Set(
                parent.resourceMarkers.map { $0.kind.mapMarkerAssetName } +
                parent.waterPoints.map { $0.kind.mapMarkerAssetName } +
                parent.shelters.map { $0.type.mapMarkerAssetName } +
                parent.officialAlerts.map { $0.kind.mapMarkerAssetName } +
                parent.beacons.map { $0.type.mapMarkerAssetName }
            )

            for assetName in assetNames {
                guard style.image(forName: assetName) == nil,
                      let image = markerImage(named: assetName) else {
                    continue
                }
                style.setImage(image, forName: assetName)
            }

            if style.image(forName: "redim8-current-location-heading") == nil,
               let locationImage = currentLocationHeadingImage() {
                style.setImage(locationImage, forName: "redim8-current-location-heading")
            }
        }

        private func markerImage(named assetName: String) -> UIImage? {
            if let symbolName = RediIcon.mappedSystemName(for: assetName),
               let generated = generatedMarkerImage(assetName: assetName, symbolName: symbolName) {
                return generated
            }

            return UIImage(named: assetName, in: .main, compatibleWith: nil)
        }

        private func generatedMarkerImage(assetName: String, symbolName: String) -> UIImage? {
            let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            guard let symbol = UIImage(systemName: symbolName, withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) else {
                return nil
            }

            let tint = markerTint(for: assetName)
            let canvasSize = CGSize(width: 32, height: 32)
            return UIGraphicsImageRenderer(size: canvasSize).image { context in
                let bounds = CGRect(origin: .zero, size: canvasSize)
                UIColor.clear.setFill()
                context.fill(bounds)

                let backgroundRect = CGRect(x: 3, y: 3, width: 26, height: 26)
                let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 13)
                tint.withAlphaComponent(0.88).setFill()
                backgroundPath.fill()

                UIColor.white.withAlphaComponent(0.14).setStroke()
                backgroundPath.lineWidth = 1
                backgroundPath.stroke()

                let iconRect = CGRect(x: 8, y: 8, width: 16, height: 16)
                symbol.draw(in: iconRect)
            }
        }

        private func markerTint(for assetName: String) -> UIColor {
            switch assetName {
            case "water_marker", "remote_water_marker":
                UIColor(red: 0.12, green: 0.62, blue: 0.96, alpha: 1)
            case "shelter_marker":
                UIColor(red: 0.16, green: 0.68, blue: 0.41, alpha: 1)
            case "warning_marker", "fire_trail_marker":
                UIColor(red: 0.96, green: 0.50, blue: 0.10, alpha: 1)
            case "flood_marker":
                UIColor(red: 0.16, green: 0.56, blue: 0.92, alpha: 1)
            case "road_blocked_marker":
                UIColor(red: 0.91, green: 0.33, blue: 0.14, alpha: 1)
            case "community_beacon_marker", "signal_node_marker":
                UIColor(red: 0.92, green: 0.77, blue: 0.18, alpha: 1)
            case "fuel_marker", "checkpoint_marker":
                UIColor(red: 0.75, green: 0.42, blue: 0.18, alpha: 1)
            case "medical_marker", "hospital_marker", "pharmacy_marker":
                UIColor(red: 0.78, green: 0.22, blue: 0.30, alpha: 1)
            default:
                UIColor(red: 0.16, green: 0.42, blue: 0.78, alpha: 1)
            }
        }

        private func currentLocationHeadingImage() -> UIImage? {
            let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            guard let symbol = UIImage(systemName: "location.north.fill", withConfiguration: configuration)?
                .withTintColor(UIColor(red: 0.99, green: 0.76, blue: 0.24, alpha: 1), renderingMode: .alwaysOriginal) else {
                return nil
            }

            let canvasSize = CGSize(width: 30, height: 30)
            return UIGraphicsImageRenderer(size: canvasSize).image { context in
                let iconRect = CGRect(x: 4, y: 2, width: 22, height: 22)
                symbol.draw(in: iconRect)

                let glowRect = CGRect(x: 8, y: 15, width: 14, height: 14)
                let glowPath = UIBezierPath(ovalIn: glowRect)
                UIColor.white.withAlphaComponent(0.2).setFill()
                glowPath.fill()

                let coreRect = CGRect(x: 10, y: 17, width: 10, height: 10)
                let corePath = UIBezierPath(ovalIn: coreRect)
                UIColor.white.setFill()
                corePath.fill()
            }
        }

        private func refreshSources(on style: MLNStyle) {
            let regionSignature = "\(parent.region.center.latitude):\(parent.region.center.longitude):\(parent.region.span.latitudeDelta):\(parent.region.span.longitudeDelta)"
            let availablePackSignature = parent.availablePacks.map {
                "\($0.id):\($0.kind.rawValue):\($0.center.latitude):\($0.center.longitude):\($0.latitudeDelta):\($0.longitudeDelta)"
            }.joined(separator: ",")
            let installedPackSignature = parent.installedPackIDs.sorted().joined(separator: ",")
            let corridorContextSignature = (parent.contextDirtRoads + parent.contextFireTrails)
                .map { "\($0.id):\($0.kind.rawValue)" }
                .joined(separator: ",")
            let locationSignature = parent.currentLocation.map { "\($0.coordinate.latitude):\($0.coordinate.longitude):\(parent.heading)" } ?? "no-location"
            let resourceSignature = parent.resourceMarkers.map { "\($0.id.uuidString):\($0.kind.rawValue):\($0.latitude):\($0.longitude)" }.joined(separator: ",")
            let dirtRoadSignature = parent.dirtRoads.map { "\($0.id):\($0.kind.rawValue)" }.joined(separator: ",")
            let fireTrailSignature = parent.fireTrails.map { "\($0.id):\($0.kind.rawValue)" }.joined(separator: ",")
            let waterPointSignature = parent.waterPoints.map { "\($0.id):\($0.kind.rawValue):\($0.coordinate.latitude):\($0.coordinate.longitude)" }.joined(separator: ",")
            let shelterSignature = parent.shelters.map { "\($0.id):\($0.type.rawValue):\($0.latitude):\($0.longitude)" }.joined(separator: ",")
            let officialAlertSignature = parent.officialAlerts.map { alert in
                let coordinateSignature = alert.coordinate.map { "\($0.latitude):\($0.longitude)" } ?? "no-coordinate"
                return "\(alert.id):\(alert.kind.rawValue):\(alert.severity.rawValue):\(coordinateSignature):\(alert.lastUpdated.timeIntervalSince1970)"
            }.joined(separator: ",")
            let beaconSignature = parent.beacons.map { "\($0.id):\($0.type.rawValue):\($0.latitude):\($0.longitude):\($0.updatedAt.timeIntervalSince1970)" }.joined(separator: ",")
            let signature = [
                regionSignature,
                availablePackSignature,
                installedPackSignature,
                corridorContextSignature,
                locationSignature,
                parent.showsDistanceRings ? "rings-on" : "rings-off",
                resourceSignature,
                dirtRoadSignature,
                fireTrailSignature,
                waterPointSignature,
                shelterSignature,
                officialAlertSignature,
                beaconSignature,
            ].joined(separator: "|")

            guard signature != lastRenderedSignature else {
                return
            }

            updateShapeSource(on: style, sourceID: SourceID.availablePackCoverage, shapes: packCoverageShapes(parent.availablePacks))
            updateShapeSource(on: style, sourceID: SourceID.installedPackCoverage, shapes: packCoverageShapes(installedPacks))
            updateShapeSource(on: style, sourceID: SourceID.availablePackLabels, shapes: packLabelShapes(parent.availablePacks))
            updateShapeSource(on: style, sourceID: SourceID.installedPackLabels, shapes: packLabelShapes(installedPacks))
            updateShapeSource(on: style, sourceID: SourceID.corridorContext, shapes: lineShapes(from: parent.contextDirtRoads + parent.contextFireTrails))
            updateShapeSource(on: style, sourceID: SourceID.graticule, shapes: graticuleShapes())
            updateShapeSource(on: style, sourceID: SourceID.distanceRings, shapes: distanceRingShapes())
            updateShapeSource(on: style, sourceID: SourceID.currentLocation, shapes: currentLocationShapes())
            updateShapeSource(on: style, sourceID: SourceID.resources, shapes: resourceShapes())
            updateShapeSource(on: style, sourceID: SourceID.dirtRoads, shapes: lineShapes(from: parent.dirtRoads))
            updateShapeSource(on: style, sourceID: SourceID.fireTrails, shapes: lineShapes(from: parent.fireTrails))
            updateShapeSource(on: style, sourceID: SourceID.waterPoints, shapes: waterPointShapes())
            updateShapeSource(on: style, sourceID: SourceID.shelters, shapes: shelterShapes())
            updateShapeSource(on: style, sourceID: SourceID.officialAlerts, shapes: officialAlertShapes())
            updateShapeSource(on: style, sourceID: SourceID.beacons, shapes: beaconShapes())

            lastRenderedSignature = signature
        }

        private func applyRegionIfNeeded(on mapView: MLNMapView) {
            guard lastRegionRevision != parent.regionRevision else {
                return
            }

            let southWest = CLLocationCoordinate2D(
                latitude: parent.region.center.latitude - parent.region.span.latitudeDelta / 2,
                longitude: parent.region.center.longitude - parent.region.span.longitudeDelta / 2
            )
            let northEast = CLLocationCoordinate2D(
                latitude: parent.region.center.latitude + parent.region.span.latitudeDelta / 2,
                longitude: parent.region.center.longitude + parent.region.span.longitudeDelta / 2
            )
            let bounds = MLNCoordinateBounds(sw: southWest, ne: northEast)
            mapView.setVisibleCoordinateBounds(
                bounds,
                edgePadding: UIEdgeInsets(top: 28, left: 20, bottom: 28, right: 20),
                animated: parent.animatesRegionChanges,
                completionHandler: nil
            )
            lastRegionRevision = parent.regionRevision
        }

        private func shapeSource(on style: MLNStyle, sourceID: String) -> MLNShapeSource {
            if let existing = style.source(withIdentifier: sourceID) as? MLNShapeSource {
                return existing
            }

            let source = MLNShapeSource(identifier: sourceID, shape: MLNShapeCollection(shapes: []), options: nil)
            style.addSource(source)
            return source
        }

        private func updateShapeSource(on style: MLNStyle, sourceID: String, shapes: [MLNShape]) {
            let source = shapeSource(on: style, sourceID: sourceID)
            source.shape = MLNShapeCollection(shapes: shapes)
        }

        private var installedPacks: [OfflineMapPack] {
            parent.availablePacks.filter { parent.installedPackIDs.contains($0.id) }
        }

        private func currentLocationShapes() -> [MLNShape] {
            guard parent.showsUserLocation, let coordinate = parent.currentLocation?.coordinate else {
                return []
            }

            let feature = MLNPointFeature()
            feature.coordinate = coordinate
            feature.attributes = [
                FeatureKey.heading: parent.heading
            ]
            return [feature]
        }

        private func resourceShapes() -> [MLNShape] {
            parent.resourceMarkers.map { marker in
                let feature = MLNPointFeature()
                feature.coordinate = marker.coordinate
                feature.attributes = [
                    FeatureKey.title: marker.title,
                    FeatureKey.subtitle: marker.subtitle,
                    FeatureKey.kind: marker.kind.title,
                    FeatureKey.markerIcon: marker.kind.mapMarkerAssetName
                ]
                return feature
            }
        }

        private func waterPointShapes() -> [MLNShape] {
            parent.waterPoints.map { point in
                let feature = MLNPointFeature()
                feature.coordinate = point.location
                feature.attributes = [
                    FeatureKey.title: point.name,
                    FeatureKey.subtitle: point.kind.title,
                    FeatureKey.quality: point.quality.title,
                    FeatureKey.markerIcon: point.kind.mapMarkerAssetName
                ]
                return feature
            }
        }

        private func beaconShapes() -> [MLNShape] {
            parent.beacons.map { beacon in
                let feature = MLNPointFeature()
                feature.coordinate = beacon.coordinate
                feature.attributes = [
                    FeatureKey.title: beacon.type.title,
                    FeatureKey.subtitle: beacon.statusText,
                    FeatureKey.markerIcon: beacon.type.mapMarkerAssetName
                ]
                return feature
            }
        }

        private func officialAlertShapes() -> [MLNShape] {
            parent.officialAlerts.compactMap { alert in
                guard let coordinate = alert.coordinate else {
                    return nil
                }
                let feature = MLNPointFeature()
                feature.identifier = alert.id as NSString
                feature.coordinate = coordinate
                feature.attributes = [
                    FeatureKey.id: alert.id,
                    FeatureKey.title: alert.title,
                    FeatureKey.subtitle: alert.severity.title,
                    FeatureKey.kind: alert.kind.title,
                    FeatureKey.markerIcon: alert.kind.mapMarkerAssetName
                ]
                return feature
            }
        }

        private func shelterShapes() -> [MLNShape] {
            parent.shelters.map { shelter in
                let feature = MLNPointFeature()
                feature.identifier = shelter.id as NSString
                feature.coordinate = shelter.coordinate
                feature.attributes = [
                    FeatureKey.id: shelter.id,
                    FeatureKey.title: shelter.name,
                    FeatureKey.subtitle: shelter.type.title,
                    FeatureKey.capacity: shelter.capacity ?? 0,
                    FeatureKey.markerIcon: shelter.type.mapMarkerAssetName
                ]
                return feature
            }
        }

        private func packCoverageShapes(_ packs: [OfflineMapPack]) -> [MLNShape] {
            packs.map { pack in
                var coordinates = packPolygonCoordinates(for: pack)
                let feature = MLNPolygonFeature(coordinates: &coordinates, count: UInt(coordinates.count))
                feature.attributes = [
                    FeatureKey.id: pack.id,
                    FeatureKey.title: pack.name,
                    FeatureKey.subtitle: pack.subtitle
                ]
                return feature
            }
        }

        private func packLabelShapes(_ packs: [OfflineMapPack]) -> [MLNShape] {
            packs.map { pack in
                let feature = MLNPointFeature()
                feature.identifier = pack.id as NSString
                feature.coordinate = pack.center.coordinate
                feature.attributes = [
                    FeatureKey.id: pack.id,
                    FeatureKey.title: pack.name,
                    FeatureKey.subtitle: pack.subtitle
                ]
                return feature
            }
        }

        private func lineShapes(from segments: [TrackSegment]) -> [MLNShape] {
            segments.compactMap { segment in
                var coordinates = segment.points.map(\.coordinate)
                guard coordinates.count >= 2 else {
                    return nil
                }
                let feature = MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count))
                feature.attributes = [
                    "title": segment.name,
                    "subtitle": segment.kind.title
                ]
                return feature
            }
        }

        private func graticuleShapes() -> [MLNShape] {
            let latSpan = max(parent.region.span.latitudeDelta, 0.2)
            let lonSpan = max(parent.region.span.longitudeDelta, 0.2)
            let latMin = parent.region.center.latitude - latSpan / 2
            let latMax = parent.region.center.latitude + latSpan / 2
            let lonMin = parent.region.center.longitude - lonSpan / 2
            let lonMax = parent.region.center.longitude + lonSpan / 2
            let latStep = graticuleStep(for: latSpan)
            let lonStep = graticuleStep(for: lonSpan)

            var shapes: [MLNShape] = []

            var latitude = floor(latMin / latStep) * latStep
            while latitude <= latMax {
                var coordinates = [
                    CLLocationCoordinate2D(latitude: latitude, longitude: lonMin),
                    CLLocationCoordinate2D(latitude: latitude, longitude: lonMax)
                ]
                shapes.append(MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count)))
                latitude += latStep
            }

            var longitude = floor(lonMin / lonStep) * lonStep
            while longitude <= lonMax {
                var coordinates = [
                    CLLocationCoordinate2D(latitude: latMin, longitude: longitude),
                    CLLocationCoordinate2D(latitude: latMax, longitude: longitude)
                ]
                shapes.append(MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count)))
                longitude += lonStep
            }

            return shapes
        }

        private func distanceRingShapes() -> [MLNShape] {
            guard parent.showsDistanceRings, let center = parent.currentLocation?.coordinate else {
                return []
            }

            return [1_000.0, 5_000.0, 10_000.0].map { radius in
                var coordinates = circleCoordinates(center: center, radiusMeters: radius)
                return MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count))
            }
        }

        private func graticuleStep(for span: CLLocationDegrees) -> CLLocationDegrees {
            let candidates: [CLLocationDegrees] = [0.05, 0.1, 0.25, 0.5, 1, 2, 5]
            let target = max(span / 4, 0.05)
            return candidates.first(where: { $0 >= target }) ?? 5
        }

        private func packPolygonCoordinates(for pack: OfflineMapPack) -> [CLLocationCoordinate2D] {
            let halfLatitudeDelta = pack.latitudeDelta / 2
            let halfLongitudeDelta = pack.longitudeDelta / 2
            let south = pack.center.latitude - halfLatitudeDelta
            let north = pack.center.latitude + halfLatitudeDelta
            let west = pack.center.longitude - halfLongitudeDelta
            let east = pack.center.longitude + halfLongitudeDelta

            return [
                CLLocationCoordinate2D(latitude: south, longitude: west),
                CLLocationCoordinate2D(latitude: south, longitude: east),
                CLLocationCoordinate2D(latitude: north, longitude: east),
                CLLocationCoordinate2D(latitude: north, longitude: west),
                CLLocationCoordinate2D(latitude: south, longitude: west)
            ]
        }

        private func circleCoordinates(center: CLLocationCoordinate2D, radiusMeters: CLLocationDistance) -> [CLLocationCoordinate2D] {
            let earthRadius = 6_378_137.0
            let angularDistance = radiusMeters / earthRadius
            let latitude = center.latitude * .pi / 180
            let longitude = center.longitude * .pi / 180

            return stride(from: 0.0, through: 360.0, by: 6.0).map { degrees in
                let bearing = degrees * .pi / 180
                let ringLatitude = asin(
                    sin(latitude) * cos(angularDistance) +
                    cos(latitude) * sin(angularDistance) * cos(bearing)
                )
                let ringLongitude = longitude + atan2(
                    sin(bearing) * sin(angularDistance) * cos(latitude),
                    cos(angularDistance) - sin(latitude) * sin(ringLatitude)
                )

                return CLLocationCoordinate2D(
                    latitude: ringLatitude * 180 / .pi,
                    longitude: ringLongitude * 180 / .pi
                )
            }
        }

        @objc
        func handleMapTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let mapView else {
                return
            }

            let point = recognizer.location(in: mapView)

            // Query all interactive feature layers
            let interactiveLayers: Set<String> = [
                LayerID.shelters, LayerID.waterPoints, LayerID.resources,
                LayerID.officialAlerts, LayerID.beacons
            ]

            let features = mapView.visibleFeatures(at: point, styleLayerIdentifiers: interactiveLayers)

            guard let feature = features.first else {
                parent.onSelectShelter(nil)
                parent.onSelectFeature?(nil)
                return
            }

            let featureID = feature.attribute(forKey: FeatureKey.id) as? String
            let title = feature.attribute(forKey: FeatureKey.title) as? String
            let subtitle = feature.attribute(forKey: FeatureKey.subtitle) as? String
            let kind = feature.attribute(forKey: FeatureKey.kind) as? String
            let quality = feature.attribute(forKey: FeatureKey.quality) as? String

            // Determine which layer was hit
            let layerID = feature.attributes["layer_id"] as? String
            let featureLayer: MapSelectedFeature.FeatureLayer
            if let layerID {
                switch layerID {
                case LayerID.shelters: featureLayer = .shelter
                case LayerID.waterPoints: featureLayer = .waterPoint
                case LayerID.resources: featureLayer = .resource
                case LayerID.officialAlerts: featureLayer = .officialAlert
                case LayerID.beacons: featureLayer = .beacon
                default: featureLayer = .unknown
                }
            } else {
                // Fallback: determine by querying each layer individually
                let shelterHit = mapView.visibleFeatures(at: point, styleLayerIdentifiers: [LayerID.shelters])
                let waterHit = mapView.visibleFeatures(at: point, styleLayerIdentifiers: [LayerID.waterPoints])
                let alertHit = mapView.visibleFeatures(at: point, styleLayerIdentifiers: [LayerID.officialAlerts])
                let beaconHit = mapView.visibleFeatures(at: point, styleLayerIdentifiers: [LayerID.beacons])
                let resourceHit = mapView.visibleFeatures(at: point, styleLayerIdentifiers: [LayerID.resources])

                if shelterHit.contains(where: { $0.attribute(forKey: FeatureKey.id) as? String == featureID }) {
                    featureLayer = .shelter
                } else if waterHit.contains(where: { $0.attribute(forKey: FeatureKey.id) as? String == featureID }) {
                    featureLayer = .waterPoint
                } else if alertHit.contains(where: { $0.attribute(forKey: FeatureKey.id) as? String == featureID }) {
                    featureLayer = .officialAlert
                } else if beaconHit.contains(where: { $0.attribute(forKey: FeatureKey.id) as? String == featureID }) {
                    featureLayer = .beacon
                } else if resourceHit.contains(where: { $0.attribute(forKey: FeatureKey.id) as? String == featureID }) {
                    featureLayer = .resource
                } else {
                    featureLayer = .unknown
                }
            }

            // Legacy shelter selection path
            if featureLayer == .shelter {
                parent.onSelectShelter(featureID)
            } else {
                parent.onSelectShelter(nil)
            }

            // New generic feature selection
            if let title {
                let coordinate: CLLocationCoordinate2D?
                if let pointFeature = feature as? MLNPointFeature {
                    coordinate = pointFeature.coordinate
                } else {
                    coordinate = nil
                }

                let selected = MapSelectedFeature(
                    id: featureID ?? UUID().uuidString,
                    title: title,
                    subtitle: subtitle,
                    kind: kind,
                    quality: quality,
                    layer: featureLayer,
                    coordinate: coordinate
                )
                parent.onSelectFeature?(selected)
            }
        }
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.delegate = context.coordinator
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsUserLocation = false
        mapView.tintColor = UIColor(ColorTheme.accent)

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = context.coordinator
        mapView.addGestureRecognizer(tapRecognizer)

        context.coordinator.mapView = mapView
        return mapView
    }
}

extension MapLibreEmergencyMapView.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

struct AppleEmergencyMapView: UIViewRepresentable {
    let surfaceMode: MapSurfaceMode
    let region: MKCoordinateRegion
    let regionRevision: Int
    let availablePacks: [OfflineMapPack]
    let installedPackIDs: Set<String>
    let resourceMarkers: [ResourceMarker]
    let dirtRoads: [TrackSegment]
    let fireTrails: [TrackSegment]
    let waterPoints: [WaterPoint]
    let shelters: [ShelterLocation]
    let officialAlerts: [OfficialAlert]
    let beacons: [CommunityBeacon]
    let currentLocation: CLLocation?
    let heading: CLLocationDirection
    let showsUserLocation: Bool
    let showsDistanceRings: Bool
    let animatesRegionChanges: Bool
    let onSelectShelter: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.overrideUserInterfaceStyle = .dark
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        mapView.showsUserLocation = showsUserLocation
        mapView.tintColor = UIColor(ColorTheme.accent)
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        if mapView.mapType != surfaceMode.appleMapType {
            mapView.mapType = surfaceMode.appleMapType
        }
        mapView.showsUserLocation = showsUserLocation
        context.coordinator.refreshIfNeeded(on: mapView)
        context.coordinator.updateUserLocationHeading()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AppleEmergencyMapView
        weak var mapView: MKMapView?
        private var lastRenderedSignature = ""
        private var lastRegionRevision = -1
        private weak var userLocationView: AppleUserLocationAnnotationView?

        init(parent: AppleEmergencyMapView) {
            self.parent = parent
        }

        func refreshIfNeeded(on mapView: MKMapView) {
            refreshContentIfNeeded(on: mapView)
            applyRegionIfNeeded(on: mapView)
        }

        private func refreshContentIfNeeded(on mapView: MKMapView) {
            let signature = [
                parent.surfaceMode.rawValue,
                parent.installedPackIDs.sorted().joined(separator: ","),
                packSignature(for: parent.availablePacks),
                resourceSignature(for: parent.resourceMarkers),
                trackSignature(for: parent.dirtRoads),
                trackSignature(for: parent.fireTrails),
                waterPointSignature(for: parent.waterPoints),
                shelterSignature(for: parent.shelters),
                officialAlertSignature(for: parent.officialAlerts),
                beaconSignature(for: parent.beacons),
                parent.showsDistanceRings ? "rings-on" : "rings-off",
                parent.currentLocation.map { "\($0.coordinate.latitude):\($0.coordinate.longitude)" } ?? "no-location"
            ].joined(separator: "|")

            guard signature != lastRenderedSignature else {
                return
            }

            let annotations = resourceAnnotations()
                + waterPointAnnotations()
                + shelterAnnotations()
                + officialAlertAnnotations()
                + beaconAnnotations()

            let overlays = packCoverageOverlays()
                + distanceRingOverlays()
                + officialAlertAreaOverlays()
                + dirtRoadOverlays()
                + fireTrailOverlays()

            let removableAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(removableAnnotations)
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays(overlays, level: .aboveRoads)
            mapView.addAnnotations(annotations)

            lastRenderedSignature = signature
        }

        func updateUserLocationHeading() {
            userLocationView?.updateHeading(parent.heading)
        }

        private func applyRegionIfNeeded(on mapView: MKMapView) {
            guard lastRegionRevision != parent.regionRevision else {
                return
            }

            mapView.setRegion(parent.region, animated: parent.animatesRegionChanges)
            lastRegionRevision = parent.regionRevision
        }

        private func resourceAnnotations() -> [AppleMapFeatureAnnotation] {
            parent.resourceMarkers.map { marker in
                AppleMapFeatureAnnotation(
                    featureID: marker.id.uuidString,
                    kind: .resource,
                    coordinate: marker.coordinate,
                    title: marker.title,
                    subtitle: marker.subtitle,
                    glyphSystemName: RediIcon.systemName(for: marker.kind.mapMarkerAssetName, fallbackSystemName: marker.kind.defaultSymbolName),
                    tintColor: UIColor(marker.kind.tint),
                    shelterID: nil,
                    displayPriority: .defaultLow
                )
            }
        }

        private func waterPointAnnotations() -> [AppleMapFeatureAnnotation] {
            parent.waterPoints.map { point in
                AppleMapFeatureAnnotation(
                    featureID: point.id,
                    kind: .waterPoint,
                    coordinate: point.location,
                    title: point.name,
                    subtitle: "\(point.kind.title) • \(point.quality.title)",
                    glyphSystemName: RediIcon.systemName(for: point.kind.mapMarkerAssetName, fallbackSystemName: "drop.fill"),
                    tintColor: UIColor(point.quality == .drinkingWater ? ColorTheme.water : ColorTheme.info),
                    shelterID: nil,
                    displayPriority: .defaultHigh
                )
            }
        }

        private func shelterAnnotations() -> [AppleMapFeatureAnnotation] {
            parent.shelters.map { shelter in
                AppleMapFeatureAnnotation(
                    featureID: shelter.id,
                    kind: .shelter,
                    coordinate: shelter.coordinate,
                    title: shelter.name,
                    subtitle: shelter.type.title,
                    glyphSystemName: RediIcon.systemName(for: shelter.type.mapMarkerAssetName, fallbackSystemName: "house.fill"),
                    tintColor: shelter.type.appleTintColor,
                    shelterID: shelter.id,
                    displayPriority: .required
                )
            }
        }

        private func officialAlertAnnotations() -> [AppleMapFeatureAnnotation] {
            parent.officialAlerts.compactMap { alert in
                guard let coordinate = alert.coordinate else {
                    return nil
                }

                return AppleMapFeatureAnnotation(
                    featureID: alert.id,
                    kind: .officialAlert,
                    coordinate: coordinate,
                    title: alert.title,
                    subtitle: alert.severity.title,
                    glyphSystemName: RediIcon.systemName(for: alert.kind.mapMarkerAssetName, fallbackSystemName: alert.kind.systemImage),
                    tintColor: alert.severity.appleTintColor,
                    shelterID: nil,
                    displayPriority: .required
                )
            }
        }

        private func beaconAnnotations() -> [AppleMapFeatureAnnotation] {
            parent.beacons.map { beacon in
                AppleMapFeatureAnnotation(
                    featureID: beacon.id,
                    kind: .beacon,
                    coordinate: beacon.coordinate,
                    title: beacon.type.title,
                    subtitle: beacon.statusText,
                    glyphSystemName: RediIcon.systemName(for: beacon.type.mapMarkerAssetName, fallbackSystemName: beacon.type.symbolName),
                    tintColor: beacon.type.appleTintColor,
                    shelterID: nil,
                    displayPriority: .defaultHigh
                )
            }
        }

        private func packCoverageOverlays() -> [MKOverlay] {
            let installedPackIDs = parent.installedPackIDs
            let installedPacks = parent.availablePacks.filter { installedPackIDs.contains($0.id) }
            let availablePacks = installedPacks.isEmpty
                ? parent.availablePacks
                : parent.availablePacks.filter { !installedPackIDs.contains($0.id) }

            let availableOverlays = availablePacks.map { pack -> MKPolygon in
                var coordinates = packPolygonCoordinates(for: pack)
                let polygon = MKPolygon(coordinates: &coordinates, count: coordinates.count)
                polygon.title = AppleMapOverlayKind.availablePackCoverage.rawValue
                return polygon
            }

            let installedOverlays = installedPacks.map { pack -> MKPolygon in
                var coordinates = packPolygonCoordinates(for: pack)
                let polygon = MKPolygon(coordinates: &coordinates, count: coordinates.count)
                polygon.title = AppleMapOverlayKind.installedPackCoverage.rawValue
                return polygon
            }

            return availableOverlays + installedOverlays
        }

        private func distanceRingOverlays() -> [MKOverlay] {
            guard parent.showsDistanceRings, let coordinate = parent.currentLocation?.coordinate else {
                return []
            }

            return [1_000.0, 5_000.0, 10_000.0].map { radius in
                let circle = MKCircle(center: coordinate, radius: radius)
                circle.title = AppleMapOverlayKind.distanceRing.rawValue
                return circle
            }
        }

        private func officialAlertAreaOverlays() -> [MKOverlay] {
            parent.officialAlerts.compactMap { alert in
                guard let coordinate = alert.coordinate, let area = alert.area else {
                    return nil
                }

                let circle = MKCircle(center: coordinate, radius: area.radiusMetres)
                circle.title = AppleMapOverlayKind.overlayTitle(for: alert.severity)
                return circle
            }
        }

        private func dirtRoadOverlays() -> [MKOverlay] {
            parent.dirtRoads.compactMap { track in
                var coordinates = track.points.map(\.coordinate)
                guard coordinates.count >= 2 else {
                    return nil
                }

                let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
                polyline.title = AppleMapOverlayKind.dirtRoad.rawValue
                return polyline
            }
        }

        private func fireTrailOverlays() -> [MKOverlay] {
            parent.fireTrails.compactMap { track in
                var coordinates = track.points.map(\.coordinate)
                guard coordinates.count >= 2 else {
                    return nil
                }

                let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
                polyline.title = AppleMapOverlayKind.fireTrail.rawValue
                return polyline
            }
        }

        private func packPolygonCoordinates(for pack: OfflineMapPack) -> [CLLocationCoordinate2D] {
            let halfLatitudeDelta = pack.latitudeDelta / 2
            let halfLongitudeDelta = pack.longitudeDelta / 2
            let south = pack.center.latitude - halfLatitudeDelta
            let north = pack.center.latitude + halfLatitudeDelta
            let west = pack.center.longitude - halfLongitudeDelta
            let east = pack.center.longitude + halfLongitudeDelta

            return [
                CLLocationCoordinate2D(latitude: south, longitude: west),
                CLLocationCoordinate2D(latitude: south, longitude: east),
                CLLocationCoordinate2D(latitude: north, longitude: east),
                CLLocationCoordinate2D(latitude: north, longitude: west),
                CLLocationCoordinate2D(latitude: south, longitude: west)
            ]
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let overlayTitle = overlayTitle(for: overlay) ?? ""

            switch overlayTitle {
            case AppleMapOverlayKind.availablePackCoverage.rawValue, AppleMapOverlayKind.installedPackCoverage.rawValue:
                let renderer = MKPolygonRenderer(overlay: overlay)
                let isInstalled = overlayTitle == AppleMapOverlayKind.installedPackCoverage.rawValue
                renderer.fillColor = UIColor(isInstalled ? ColorTheme.ready.opacity(0.12) : ColorTheme.info.opacity(0.06))
                renderer.strokeColor = UIColor(isInstalled ? ColorTheme.ready.opacity(0.72) : ColorTheme.info.opacity(0.34))
                renderer.lineWidth = isInstalled ? 2.0 : 1.2
                if !isInstalled {
                    renderer.lineDashPattern = [5, 4]
                }
                return renderer
            case AppleMapOverlayKind.dirtRoad.rawValue:
                let renderer = MKPolylineRenderer(overlay: overlay)
                renderer.strokeColor = UIColor(red: 0.70, green: 0.46, blue: 0.21, alpha: 0.92)
                renderer.lineWidth = 2.2
                renderer.lineDashPattern = [4, 2]
                return renderer
            case AppleMapOverlayKind.fireTrail.rawValue:
                let renderer = MKPolylineRenderer(overlay: overlay)
                renderer.strokeColor = UIColor(ColorTheme.warning)
                renderer.lineWidth = 2.8
                renderer.lineDashPattern = [3, 2]
                return renderer
            case AppleMapOverlayKind.distanceRing.rawValue:
                let renderer = MKCircleRenderer(overlay: overlay)
                let tint = UIColor(red: 0.16, green: 1.0, blue: 0.64, alpha: 1)
                renderer.fillColor = .clear
                renderer.strokeColor = tint.withAlphaComponent(0.7)
                renderer.lineWidth = 1.2
                renderer.lineDashPattern = [3, 3]
                return renderer
            case AppleMapOverlayKind.alertAdviceArea.rawValue,
                 AppleMapOverlayKind.alertWatchArea.rawValue,
                 AppleMapOverlayKind.alertEmergencyArea.rawValue:
                let renderer = MKCircleRenderer(overlay: overlay)
                let tint = AppleMapOverlayKind.tintColor(for: overlayTitle)
                renderer.fillColor = tint.withAlphaComponent(0.08)
                renderer.strokeColor = tint.withAlphaComponent(0.64)
                renderer.lineWidth = 1.8
                renderer.lineDashPattern = [6, 4]
                return renderer
            default:
                return MKOverlayRenderer(overlay: overlay)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let identifier = "user-location"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? AppleUserLocationAnnotationView)
                    ?? AppleUserLocationAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.updateHeading(parent.heading)
                userLocationView = view
                return view
            }

            guard let annotation = annotation as? AppleMapFeatureAnnotation else {
                return nil
            }

            let identifier = annotation.kind.rawValue
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = true
            view.animatesWhenAdded = false
            view.displayPriority = annotation.displayPriority
            view.markerTintColor = annotation.tintColor
            view.glyphImage = UIImage(
                systemName: annotation.glyphSystemName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            )
            view.glyphTintColor = .white
            view.titleVisibility = .adaptive
            view.subtitleVisibility = .adaptive
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? AppleMapFeatureAnnotation else {
                parent.onSelectShelter(nil)
                return
            }

            parent.onSelectShelter(annotation.shelterID)
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard view.annotation is AppleMapFeatureAnnotation else {
                return
            }
            parent.onSelectShelter(nil)
        }

        private func overlayTitle(for overlay: MKOverlay) -> String? {
            (overlay as? MKShape)?.title ?? nil
        }

        private func packSignature(for packs: [OfflineMapPack]) -> String {
            packs
                .map { pack in
                    "\(pack.id):\(pack.center.latitude):\(pack.center.longitude):\(pack.latitudeDelta):\(pack.longitudeDelta)"
                }
                .joined(separator: ",")
        }

        private func resourceSignature(for markers: [ResourceMarker]) -> String {
            markers
                .map { marker in
                    "\(marker.id.uuidString):\(marker.kind.rawValue):\(marker.latitude):\(marker.longitude)"
                }
                .joined(separator: ",")
        }

        private func trackSignature(for tracks: [TrackSegment]) -> String {
            tracks
                .map { track in
                    "\(track.id):\(track.kind.rawValue)"
                }
                .joined(separator: ",")
        }

        private func waterPointSignature(for points: [WaterPoint]) -> String {
            points
                .map { point in
                    "\(point.id):\(point.kind.rawValue):\(point.coordinate.latitude):\(point.coordinate.longitude)"
                }
                .joined(separator: ",")
        }

        private func shelterSignature(for shelters: [ShelterLocation]) -> String {
            shelters
                .map { shelter in
                    "\(shelter.id):\(shelter.type.rawValue):\(shelter.latitude):\(shelter.longitude)"
                }
                .joined(separator: ",")
        }

        private func officialAlertSignature(for alerts: [OfficialAlert]) -> String {
            alerts
                .map { alert in
                    let coordinate = alert.coordinate.map { "\($0.latitude):\($0.longitude)" } ?? "no-coordinate"
                    return "\(alert.id):\(alert.kind.rawValue):\(alert.severity.rawValue):\(coordinate)"
                }
                .joined(separator: ",")
        }

        private func beaconSignature(for beacons: [CommunityBeacon]) -> String {
            beacons
                .map { beacon in
                    "\(beacon.id):\(beacon.type.rawValue):\(beacon.latitude):\(beacon.longitude):\(beacon.updatedAt.timeIntervalSince1970)"
                }
                .joined(separator: ",")
        }
    }
}

private enum AppleMapOverlayKind: String {
    case availablePackCoverage = "available-pack-coverage"
    case installedPackCoverage = "installed-pack-coverage"
    case dirtRoad = "dirt-road"
    case fireTrail = "fire-trail"
    case distanceRing = "distance-ring"
    case alertAdviceArea = "alert-advice-area"
    case alertWatchArea = "alert-watch-area"
    case alertEmergencyArea = "alert-emergency-area"

    static func overlayTitle(for severity: OfficialAlertSeverity) -> String {
        switch severity {
        case .advice:
            alertAdviceArea.rawValue
        case .watchAndAct:
            alertWatchArea.rawValue
        case .emergencyWarning:
            alertEmergencyArea.rawValue
        }
    }

    static func tintColor(for title: String) -> UIColor {
        switch title {
        case alertEmergencyArea.rawValue:
            UIColor(ColorTheme.danger)
        case alertWatchArea.rawValue:
            UIColor(ColorTheme.warning)
        default:
            UIColor(ColorTheme.info)
        }
    }
}

private final class AppleUserLocationAnnotationView: MKAnnotationView {
    private let pulseLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()
    private let coreLayer = CAShapeLayer()
    private let arrowImageView = UIImageView()

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        centerOffset = .zero
        collisionMode = .circle
        displayPriority = .required
        isOpaque = false
        canShowCallout = false

        pulseLayer.fillColor = UIColor(red: 0.99, green: 0.76, blue: 0.24, alpha: 0.16).cgColor
        layer.addSublayer(pulseLayer)

        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = UIColor(red: 0.99, green: 0.76, blue: 0.24, alpha: 0.8).cgColor
        ringLayer.lineWidth = 2
        layer.addSublayer(ringLayer)

        coreLayer.fillColor = UIColor.white.cgColor
        coreLayer.strokeColor = UIColor(red: 0.99, green: 0.76, blue: 0.24, alpha: 1).cgColor
        coreLayer.lineWidth = 2
        layer.addSublayer(coreLayer)

        arrowImageView.image = UIImage(
            systemName: "location.north.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        )?.withTintColor(UIColor(red: 0.99, green: 0.76, blue: 0.24, alpha: 1), renderingMode: .alwaysOriginal)
        arrowImageView.frame = CGRect(x: 11, y: 5, width: 22, height: 22)
        arrowImageView.contentMode = .scaleAspectFit
        addSubview(arrowImageView)

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.92
        scaleAnimation.toValue = 1.12
        scaleAnimation.duration = 1.4
        scaleAnimation.autoreverses = true
        scaleAnimation.repeatCount = .infinity

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.22
        opacityAnimation.toValue = 0.08
        opacityAnimation.duration = 1.4
        opacityAnimation.autoreverses = true
        opacityAnimation.repeatCount = .infinity

        pulseLayer.add(scaleAnimation, forKey: "pulse-scale")
        pulseLayer.add(opacityAnimation, forKey: "pulse-opacity")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pulseRect = CGRect(x: 7, y: 7, width: 30, height: 30)
        pulseLayer.path = UIBezierPath(ovalIn: pulseRect).cgPath

        let ringRect = CGRect(x: 11, y: 11, width: 22, height: 22)
        ringLayer.path = UIBezierPath(ovalIn: ringRect).cgPath

        let coreRect = CGRect(x: 15, y: 15, width: 14, height: 14)
        coreLayer.path = UIBezierPath(ovalIn: coreRect).cgPath
    }

    func updateHeading(_ heading: CLLocationDirection) {
        arrowImageView.transform = CGAffineTransform(rotationAngle: CGFloat(heading * .pi / 180))
    }
}

private final class AppleMapFeatureAnnotation: NSObject, MKAnnotation {
    enum Kind: String {
        case resource
        case waterPoint
        case shelter
        case officialAlert
        case beacon
    }

    let featureID: String
    let kind: Kind
    let shelterID: String?
    var coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let glyphSystemName: String
    let tintColor: UIColor
    let displayPriority: MKFeatureDisplayPriority

    init(
        featureID: String,
        kind: Kind,
        coordinate: CLLocationCoordinate2D,
        title: String?,
        subtitle: String?,
        glyphSystemName: String,
        tintColor: UIColor,
        shelterID: String?,
        displayPriority: MKFeatureDisplayPriority
    ) {
        self.featureID = featureID
        self.kind = kind
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.glyphSystemName = glyphSystemName
        self.tintColor = tintColor
        self.shelterID = shelterID
        self.displayPriority = displayPriority
    }
}

private extension MapSurfaceMode {
    var appleMapType: MKMapType {
        switch self {
        case .liveTiles:
            .mutedStandard
        case .hybrid:
            .hybrid
        case .tactical:
            .mutedStandard
        }
    }
}

private extension ShelterType {
    var appleTintColor: UIColor {
        switch self {
        case .evacuationCentre:
            UIColor(ColorTheme.ready)
        case .communityShelter, .publicAssemblyPoint:
            UIColor(ColorTheme.info)
        case .cycloneShelter, .temporaryReliefCentre:
            UIColor(ColorTheme.warning)
        }
    }
}

private extension OfficialAlertSeverity {
    var appleTintColor: UIColor {
        switch self {
        case .advice:
            UIColor(ColorTheme.info)
        case .watchAndAct:
            UIColor(ColorTheme.warning)
        case .emergencyWarning:
            UIColor(ColorTheme.danger)
        }
    }
}

private extension BeaconType {
    var appleTintColor: UIColor {
        switch self {
        case .safeLocation, .shelter:
            UIColor(ColorTheme.ready)
        case .waterAvailable:
            UIColor(ColorTheme.water)
        case .fuelAvailable, .fireSpotted, .floodedRoad, .roadBlocked:
            UIColor(ColorTheme.warning)
        case .medicalHelp, .needHelp:
            UIColor(ColorTheme.danger)
        }
    }
}

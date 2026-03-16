import CoreLocation

/// A lightweight 2D R-tree for fast spatial queries on geographic points.
/// Optimized for emergency use: all queries return in O(log n) instead of O(n).
///
/// Usage:
///   let index = SpatialIndex<WaterPoint>(items: points) { $0.coordinate.coordinate }
///   let nearby = index.nearest(to: userLocation, limit: 5)
///   let inArea = index.query(within: bounds)
final class SpatialIndex<Item> {

    // MARK: - Types

    struct BoundingBox {
        var minLat: Double
        var maxLat: Double
        var minLon: Double
        var maxLon: Double

        static var empty: BoundingBox {
            BoundingBox(minLat: .greatestFiniteMagnitude, maxLat: -.greatestFiniteMagnitude,
                        minLon: .greatestFiniteMagnitude, maxLon: -.greatestFiniteMagnitude)
        }

        mutating func expand(to coord: CLLocationCoordinate2D) {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        mutating func expand(to other: BoundingBox) {
            minLat = min(minLat, other.minLat)
            maxLat = max(maxLat, other.maxLat)
            minLon = min(minLon, other.minLon)
            maxLon = max(maxLon, other.maxLon)
        }

        func contains(_ coord: CLLocationCoordinate2D) -> Bool {
            coord.latitude >= minLat && coord.latitude <= maxLat &&
            coord.longitude >= minLon && coord.longitude <= maxLon
        }

        func intersects(_ other: BoundingBox) -> Bool {
            !(other.minLat > maxLat || other.maxLat < minLat ||
              other.minLon > maxLon || other.maxLon < minLon)
        }

        /// Minimum possible haversine distance from a coordinate to this bounding box.
        /// Returns 0 if the coordinate is inside the box.
        func minDistance(to coord: CLLocationCoordinate2D) -> CLLocationDistance {
            if contains(coord) { return 0 }

            let clampedLat = min(max(coord.latitude, minLat), maxLat)
            let clampedLon = min(max(coord.longitude, minLon), maxLon)
            let clamped = CLLocation(latitude: clampedLat, longitude: clampedLon)
            let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            return target.distance(from: clamped)
        }
    }

    private enum Node {
        case leaf(items: [(item: Item, coord: CLLocationCoordinate2D)], bounds: BoundingBox)
        case branch(children: [Node], bounds: BoundingBox)
    }

    // MARK: - Properties

    private let root: Node?
    private let coordinateOf: (Item) -> CLLocationCoordinate2D
    private static var leafCapacity: Int { 16 }

    /// Total number of items in the index.
    let count: Int

    // MARK: - Init

    /// Build a spatial index from an array of items.
    /// - Parameters:
    ///   - items: The items to index.
    ///   - coordinate: Closure that extracts a coordinate from an item.
    init(items: [Item], coordinate: @escaping (Item) -> CLLocationCoordinate2D) {
        self.coordinateOf = coordinate
        self.count = items.count

        guard !items.isEmpty else {
            self.root = nil
            return
        }

        let entries = items.map { (item: $0, coord: coordinate($0)) }
        self.root = Self.buildNode(from: entries)
    }

    // MARK: - Queries

    /// Find all items within a bounding box.
    func query(within bounds: BoundingBox) -> [Item] {
        guard let root else { return [] }
        var results: [Item] = []
        Self.rangeSearch(node: root, bounds: bounds, results: &results)
        return results
    }

    /// Find all items within a radius (metres) of a coordinate.
    func query(near center: CLLocationCoordinate2D, radiusMetres: CLLocationDistance) -> [Item] {
        guard root != nil else { return [] }

        // Approximate bounding box for the radius (overestimates slightly at high latitudes)
        let latDelta = radiusMetres / 111_320.0
        let lonDelta = radiusMetres / (111_320.0 * cos(center.latitude * .pi / 180.0))

        let searchBounds = BoundingBox(
            minLat: center.latitude - latDelta,
            maxLat: center.latitude + latDelta,
            minLon: center.longitude - lonDelta,
            maxLon: center.longitude + lonDelta
        )

        let candidates = query(within: searchBounds)
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return candidates.filter { item in
            let coord = coordinateOf(item)
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            return centerLocation.distance(from: loc) <= radiusMetres
        }
    }

    /// Find the N nearest items to a coordinate, sorted by distance (ascending).
    /// Uses a priority-queue branch-and-bound search for efficiency.
    func nearest(to center: CLLocationCoordinate2D, limit: Int) -> [(item: Item, distanceMetres: CLLocationDistance)] {
        guard let root, limit > 0 else { return [] }

        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        var heap = BoundedMaxHeap<(item: Item, distanceMetres: CLLocationDistance)>(capacity: limit) { $0.distanceMetres }
        Self.knnSearch(node: root, center: center, centerLocation: centerLocation, heap: &heap)

        return heap.sorted().reversed()
    }

    /// Find the single nearest item to a coordinate.
    func nearest(to center: CLLocationCoordinate2D) -> (item: Item, distanceMetres: CLLocationDistance)? {
        nearest(to: center, limit: 1).first
    }

    // MARK: - Tree Construction

    private static func buildNode(from entries: [(item: Item, coord: CLLocationCoordinate2D)]) -> Node {
        if entries.count <= leafCapacity {
            var bounds = BoundingBox.empty
            for entry in entries { bounds.expand(to: entry.coord) }
            return .leaf(items: entries, bounds: bounds)
        }

        // Sort-tile-recursive (STR) bulk loading
        let sorted = entries.sorted { $0.coord.latitude < $1.coord.latitude }
        let sliceSize = max(1, Int(ceil(sqrt(Double(entries.count)))))
        var children: [Node] = []
        var overallBounds = BoundingBox.empty

        for sliceStart in stride(from: 0, to: sorted.count, by: sliceSize) {
            let sliceEnd = min(sliceStart + sliceSize, sorted.count)
            var slice = Array(sorted[sliceStart..<sliceEnd])
            slice.sort { $0.coord.longitude < $1.coord.longitude }

            for leafStart in stride(from: 0, to: slice.count, by: leafCapacity) {
                let leafEnd = min(leafStart + leafCapacity, slice.count)
                let leafEntries = Array(slice[leafStart..<leafEnd])
                let child = buildNode(from: leafEntries)

                switch child {
                case .leaf(_, let b), .branch(_, let b):
                    overallBounds.expand(to: b)
                }
                children.append(child)
            }
        }

        if children.count == 1 { return children[0] }
        return .branch(children: children, bounds: overallBounds)
    }

    // MARK: - Search Algorithms

    private static func rangeSearch(node: Node, bounds: BoundingBox, results: inout [Item]) {
        switch node {
        case .leaf(let items, let nodeBounds):
            guard bounds.intersects(nodeBounds) else { return }
            for entry in items where bounds.contains(entry.coord) {
                results.append(entry.item)
            }

        case .branch(let children, let nodeBounds):
            guard bounds.intersects(nodeBounds) else { return }
            for child in children {
                rangeSearch(node: child, bounds: bounds, results: &results)
            }
        }
    }

    private static func knnSearch(
        node: Node,
        center: CLLocationCoordinate2D,
        centerLocation: CLLocation,
        heap: inout BoundedMaxHeap<(item: Item, distanceMetres: CLLocationDistance)>
    ) {
        switch node {
        case .leaf(let items, let nodeBounds):
            // Prune: if the closest point in this node's bounds is farther than our worst candidate, skip
            if heap.isFull {
                let minDist = nodeBounds.minDistance(to: center)
                if minDist > heap.worstValue { return }
            }

            for entry in items {
                let loc = CLLocation(latitude: entry.coord.latitude, longitude: entry.coord.longitude)
                let dist = centerLocation.distance(from: loc)
                heap.insert((item: entry.item, distanceMetres: dist))
            }

        case .branch(let children, let nodeBounds):
            if heap.isFull {
                let minDist = nodeBounds.minDistance(to: center)
                if minDist > heap.worstValue { return }
            }

            // Visit children in order of proximity to center for better pruning
            let sortedChildren: [(node: Node, minDist: CLLocationDistance)] = children.map { child in
                let childBounds: BoundingBox
                switch child {
                case .leaf(_, let b): childBounds = b
                case .branch(_, let b): childBounds = b
                }
                return (child, childBounds.minDistance(to: center))
            }.sorted { $0.minDist < $1.minDist }

            for (child, minDist) in sortedChildren {
                if heap.isFull && minDist > heap.worstValue { break }
                knnSearch(node: child, center: center, centerLocation: centerLocation, heap: &heap)
            }
        }
    }
}

// MARK: - Bounded Max-Heap

/// A fixed-capacity max-heap that keeps only the K smallest values.
/// Used for K-nearest-neighbor searches.
struct BoundedMaxHeap<Element> {
    private var storage: [Element] = []
    private let capacity: Int
    private let value: (Element) -> CLLocationDistance

    var isFull: Bool { storage.count >= capacity }
    var worstValue: CLLocationDistance { storage.first.map(value) ?? .greatestFiniteMagnitude }

    init(capacity: Int, value: @escaping (Element) -> CLLocationDistance) {
        self.capacity = capacity
        self.value = value
        storage.reserveCapacity(capacity + 1)
    }

    mutating func insert(_ element: Element) {
        let v = value(element)

        if isFull {
            guard v < worstValue else { return }
            storage[0] = element
            siftDown(0)
        } else {
            storage.append(element)
            siftUp(storage.count - 1)
        }
    }

    func sorted() -> [Element] {
        storage.sorted { value($0) < value($1) }
    }

    // MARK: - Heap Operations

    private mutating func siftUp(_ index: Int) {
        var i = index
        while i > 0 {
            let parent = (i - 1) / 2
            if value(storage[i]) > value(storage[parent]) {
                storage.swapAt(i, parent)
                i = parent
            } else {
                break
            }
        }
    }

    private mutating func siftDown(_ index: Int) {
        var i = index
        let count = storage.count

        while true {
            var largest = i
            let left = 2 * i + 1
            let right = 2 * i + 2

            if left < count && value(storage[left]) > value(storage[largest]) { largest = left }
            if right < count && value(storage[right]) > value(storage[largest]) { largest = right }

            if largest == i { break }
            storage.swapAt(i, largest)
            i = largest
        }
    }
}

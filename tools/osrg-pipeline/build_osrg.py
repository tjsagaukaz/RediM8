#!/usr/bin/env python3
"""
OSRG Pipeline — Converts OSM extracts into .osrg routing graph files.

Workflow:
  1. Download regional OSM PBF extract (e.g. from Geofabrik)
  2. Extract drivable road network
  3. Build directed graph (nodes + edges with weights)
  4. Compute Contraction Hierarchy (node ordering + shortcut edges)
  5. Serialize to .osrg v2 binary format

Usage:
  python build_osrg.py --input australia-latest.osm.pbf --region queensland --output qld-routing.osrg
  python build_osrg.py --input brisbane.osm.pbf --region brisbane --bbox "-28.2,152.5,-27.0,153.6" --output brisbane-routing.osrg

Requirements:
  pip install osmium shapely

Optional (for PBF downloading):
  pip install requests
"""

import argparse
import heapq
import math
import struct
import sys
import time
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

try:
    import osmium
except ImportError:
    print("ERROR: osmium not installed. Run: pip install osmium", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Node:
    id: int
    lat: float
    lon: float
    level: int = 0  # CH level — assigned during contraction


@dataclass
class Edge:
    from_id: int
    to_id: int
    weight_metres: int
    shortcut_mid: int = 0  # 0 = not a shortcut


@dataclass
class Graph:
    region: str
    version: str
    nodes: list[Node] = field(default_factory=list)
    edges: list[Edge] = field(default_factory=list)
    node_map: dict[int, int] = field(default_factory=dict)  # osm_id -> internal_id
    adjacency: dict[int, list[Edge]] = field(default_factory=lambda: defaultdict(list))
    reverse_adj: dict[int, list[Edge]] = field(default_factory=lambda: defaultdict(list))

    @property
    def bbox(self) -> tuple[float, float, float, float]:
        if not self.nodes:
            return (0, 0, 0, 0)
        lats = [n.lat for n in self.nodes]
        lons = [n.lon for n in self.nodes]
        return (min(lats), min(lons), max(lats), max(lons))


# ---------------------------------------------------------------------------
# Step 1: Extract road network from OSM PBF
# ---------------------------------------------------------------------------

# OSM highway types that are drivable
DRIVABLE_HIGHWAYS = {
    "motorway", "trunk", "primary", "secondary", "tertiary",
    "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link",
    "unclassified", "residential", "service", "living_street",
    "track", "road",
}

# Speed assumptions (km/h) for weight calculation
SPEED_MAP = {
    "motorway": 110, "trunk": 100, "primary": 80, "secondary": 60,
    "tertiary": 50, "unclassified": 40, "residential": 30,
    "motorway_link": 60, "trunk_link": 60, "primary_link": 50,
    "secondary_link": 40, "tertiary_link": 30,
    "service": 20, "living_street": 20, "track": 20, "road": 30,
}


class RoadExtractor(osmium.SimpleHandler):
    """Extract nodes and ways from OSM PBF, filtered to drivable roads."""

    def __init__(self, bbox: Optional[tuple[float, float, float, float]] = None):
        super().__init__()
        self.way_nodes: list[tuple[list[int], str, bool]] = []  # (node_refs, highway_type, oneway)
        self.node_coords: dict[int, tuple[float, float]] = {}
        self.referenced_nodes: set[int] = set()
        self.bbox = bbox

    def way(self, w):
        tags = {t.k: t.v for t in w.tags}
        highway = tags.get("highway")
        if highway not in DRIVABLE_HIGHWAYS:
            return

        # Skip ways explicitly marked as not for motor vehicles
        if tags.get("motor_vehicle") == "no" or tags.get("access") == "no":
            return

        refs = [n.ref for n in w.nodes]
        oneway = tags.get("oneway", "no") in ("yes", "1", "true")
        # Motorways/links are implicitly oneway
        if highway in ("motorway", "motorway_link") and not oneway:
            oneway = tags.get("oneway", "yes") != "no"

        self.way_nodes.append((refs, highway, oneway))
        self.referenced_nodes.update(refs)

    def node(self, n):
        if n.id in self.referenced_nodes or not self.referenced_nodes:
            lat, lon = n.location.lat, n.location.lon
            if self.bbox:
                min_lat, min_lon, max_lat, max_lon = self.bbox
                if not (min_lat <= lat <= max_lat and min_lon <= lon <= max_lon):
                    return
            self.node_coords[n.id] = (lat, lon)


def haversine_metres(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Haversine distance in metres."""
    R = 6_371_000
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def extract_roads(pbf_path: str, bbox: Optional[tuple[float, float, float, float]] = None) -> tuple[dict, list]:
    """
    Two-pass extraction:
      Pass 1: Collect way references to know which nodes we need
      Pass 2: Collect node coordinates

    Returns (node_coords, ways) where ways = [(refs, highway_type, oneway), ...]
    """
    print(f"[1/5] Extracting roads from {pbf_path}...")
    t0 = time.time()

    handler = RoadExtractor(bbox=bbox)

    # Pass 1: collect ways and referenced node IDs
    handler.apply_file(pbf_path, locations=False)

    # Pass 2: collect coordinates for referenced nodes
    handler.apply_file(pbf_path, locations=True)

    elapsed = time.time() - t0
    print(f"       {len(handler.way_nodes):,} ways, {len(handler.node_coords):,} nodes ({elapsed:.1f}s)")
    return handler.node_coords, handler.way_nodes


# ---------------------------------------------------------------------------
# Step 2: Build graph
# ---------------------------------------------------------------------------

def build_graph(node_coords: dict, ways: list, region: str, version: str = "1.0") -> Graph:
    """Build a directed graph from extracted OSM road data."""
    print("[2/5] Building routing graph...")
    t0 = time.time()

    graph = Graph(region=region, version=version)

    # Assign internal IDs to nodes
    internal_id = 0
    for osm_id, (lat, lon) in node_coords.items():
        graph.node_map[osm_id] = internal_id
        graph.nodes.append(Node(id=internal_id, lat=lat, lon=lon))
        internal_id += 1

    # Build edges from ways
    edge_count = 0
    for refs, highway, oneway in ways:
        speed_kmh = SPEED_MAP.get(highway, 30)

        for i in range(len(refs) - 1):
            a_osm, b_osm = refs[i], refs[i + 1]
            if a_osm not in graph.node_map or b_osm not in graph.node_map:
                continue

            a = graph.node_map[a_osm]
            b = graph.node_map[b_osm]

            lat_a, lon_a = node_coords[a_osm]
            lat_b, lon_b = node_coords[b_osm]
            dist_m = int(haversine_metres(lat_a, lon_a, lat_b, lon_b))

            # Weight = travel time in deciseconds (0.1s units) for better precision
            # weight = distance_m / (speed_m_per_s) * 10
            speed_mps = speed_kmh / 3.6
            weight = max(1, int(dist_m / speed_mps * 10))

            # Forward edge
            edge = Edge(from_id=a, to_id=b, weight_metres=weight)
            graph.edges.append(edge)
            graph.adjacency[a].append(edge)
            graph.reverse_adj[b].append(edge)
            edge_count += 1

            # Reverse edge (if not oneway)
            if not oneway:
                rev_edge = Edge(from_id=b, to_id=a, weight_metres=weight)
                graph.edges.append(rev_edge)
                graph.adjacency[b].append(rev_edge)
                graph.reverse_adj[a].append(rev_edge)
                edge_count += 1

    elapsed = time.time() - t0
    print(f"       {len(graph.nodes):,} nodes, {edge_count:,} edges ({elapsed:.1f}s)")
    return graph


# ---------------------------------------------------------------------------
# Step 3: Contraction Hierarchy preprocessing
# ---------------------------------------------------------------------------

def compute_contraction_hierarchy(graph: Graph) -> Graph:
    """
    Compute Contraction Hierarchy by iteratively contracting least-important nodes.

    Node importance heuristic:
      importance = edge_difference + contracted_neighbors + level
    where edge_difference = shortcuts_needed - edges_removed

    For each contracted node u:
      - For all pairs (v -> u -> w), if the path v->u->w is the only shortest path,
        add a shortcut edge v->w with weight = w(v,u) + w(u,w).
    """
    print("[3/5] Computing contraction hierarchy...")
    t0 = time.time()

    n = len(graph.nodes)
    contracted = [False] * n
    node_level = [0] * n

    # Working adjacency (mutable)
    fwd: dict[int, list[tuple[int, int, int]]] = defaultdict(list)  # node -> [(to, weight, shortcut_mid)]
    bwd: dict[int, list[tuple[int, int, int]]] = defaultdict(list)

    for edge in graph.edges:
        fwd[edge.from_id].append((edge.to_id, edge.weight_metres, 0))
        bwd[edge.to_id].append((edge.from_id, edge.weight_metres, 0))

    def edge_difference(u: int) -> int:
        """Compute how many shortcuts contracting u would add minus edges removed."""
        in_edges = [(v, w) for v, w, _ in bwd[u] if not contracted[v]]
        out_edges = [(w, wt) for w, wt, _ in fwd[u] if not contracted[w]]
        shortcuts_needed = 0

        for v, w_vu in in_edges:
            for w, w_uw in out_edges:
                if v == w:
                    continue
                path_weight = w_vu + w_uw
                # Check if there's a witness path v->w not through u
                if not has_witness(v, w, u, path_weight, fwd, contracted):
                    shortcuts_needed += 1

        edges_removed = len(in_edges) + len(out_edges)
        return shortcuts_needed - edges_removed

    def importance(u: int) -> int:
        return edge_difference(u) + sum(1 for v, _, _ in fwd[u] if contracted[v]) + node_level[u]

    # Priority queue: (importance, node_id)
    pq = [(importance(u), u) for u in range(n)]
    heapq.heapify(pq)

    shortcuts_added = 0
    level = 0
    contracted_count = 0
    report_interval = max(1, n // 20)

    while pq:
        _, u = heapq.heappop(pq)
        if contracted[u]:
            continue

        # Lazy update: recompute importance and check if still minimum
        current_imp = importance(u)
        if pq and current_imp > pq[0][0]:
            heapq.heappush(pq, (current_imp, u))
            continue

        # Contract node u
        contracted[u] = True
        node_level[u] = level
        level += 1
        contracted_count += 1

        if contracted_count % report_interval == 0:
            pct = contracted_count * 100 // n
            print(f"       Contracted {contracted_count:,}/{n:,} ({pct}%), shortcuts: {shortcuts_added:,}")

        # Add shortcut edges
        in_edges = [(v, w) for v, w, _ in bwd[u] if not contracted[v]]
        out_edges = [(w, wt) for w, wt, _ in fwd[u] if not contracted[w]]

        for v, w_vu in in_edges:
            for w, w_uw in out_edges:
                if v == w:
                    continue
                path_weight = w_vu + w_uw
                if not has_witness(v, w, u, path_weight, fwd, contracted):
                    # Add shortcut v -> w through u
                    fwd[v].append((w, path_weight, u))
                    bwd[w].append((v, path_weight, u))
                    shortcuts_added += 1

    # Rebuild graph with CH levels and shortcut edges
    graph.edges.clear()
    graph.adjacency.clear()
    graph.reverse_adj.clear()

    for u in range(n):
        graph.nodes[u].level = node_level[u]

    for u in range(n):
        for to, weight, mid in fwd[u]:
            edge = Edge(from_id=u, to_id=to, weight_metres=weight, shortcut_mid=mid)
            graph.edges.append(edge)
            graph.adjacency[u].append(edge)
            graph.reverse_adj[to].append(edge)

    elapsed = time.time() - t0
    print(f"       CH complete: {shortcuts_added:,} shortcuts added ({elapsed:.1f}s)")
    return graph


def has_witness(v: int, w: int, excluded: int, max_weight: int,
                fwd: dict, contracted: list) -> bool:
    """
    Limited Dijkstra from v to w, avoiding node `excluded`.
    Returns True if a path exists with weight <= max_weight.
    """
    dist = {v: 0}
    pq = [(0, v)]
    hops = 0
    max_hops = 10  # Limit search depth for performance

    while pq and hops < max_hops:
        d, u = heapq.heappop(pq)
        hops += 1
        if d > max_weight:
            return False
        if u == w:
            return True
        if d > dist.get(u, float("inf")):
            continue

        for next_node, edge_weight, _ in fwd[u]:
            if next_node == excluded or contracted[next_node]:
                continue
            nd = d + edge_weight
            if nd < dist.get(next_node, float("inf")) and nd <= max_weight:
                dist[next_node] = nd
                heapq.heappush(pq, (nd, next_node))

    return False


# ---------------------------------------------------------------------------
# Step 4: Serialize to .osrg v2
# ---------------------------------------------------------------------------

def degrees_to_microdegrees(deg: float) -> int:
    return max(-2_147_483_648, min(2_147_483_647, int(deg * 1_000_000)))


def serialize_osrg_v2(graph: Graph, output_path: str, delta_encode: bool = True):
    """Serialize graph to .osrg v2 binary format."""
    print(f"[5/5] Serializing to {output_path}...")
    t0 = time.time()

    region_bytes = graph.region.encode("utf-8")
    version_bytes = graph.version.encode("utf-8")

    min_lat, min_lon, max_lat, max_lon = graph.bbox
    bbox_min_lat = degrees_to_microdegrees(min_lat)
    bbox_min_lon = degrees_to_microdegrees(min_lon)
    bbox_max_lat = degrees_to_microdegrees(max_lat)
    bbox_max_lon = degrees_to_microdegrees(max_lon)

    flags = 0x01 if delta_encode else 0x00

    with open(output_path, "wb") as f:
        # Header (48 bytes)
        f.write(b"OSRG")
        f.write(struct.pack("<H", 2))  # format version
        f.write(struct.pack("<H", flags))
        f.write(struct.pack("<I", len(graph.nodes)))
        f.write(struct.pack("<I", len(graph.edges)))
        f.write(struct.pack("<i", bbox_min_lat))
        f.write(struct.pack("<i", bbox_min_lon))
        f.write(struct.pack("<i", bbox_max_lat))
        f.write(struct.pack("<i", bbox_max_lon))
        f.write(struct.pack("<H", len(region_bytes)))
        f.write(struct.pack("<H", len(version_bytes)))
        f.write(b"\x00" * 12)  # reserved

        # Strings
        f.write(region_bytes)
        f.write(version_bytes)

        # Nodes (14 bytes each)
        for node in graph.nodes:
            f.write(struct.pack("<I", node.id))
            if delta_encode:
                d_lat = degrees_to_microdegrees(node.lat) - bbox_min_lat
                d_lon = degrees_to_microdegrees(node.lon) - bbox_min_lon
                f.write(struct.pack("<i", d_lat))
                f.write(struct.pack("<i", d_lon))
            else:
                f.write(struct.pack("<f", node.lat))
                f.write(struct.pack("<f", node.lon))
            f.write(struct.pack("<H", node.level))

        # Edges (16 bytes each)
        for edge in graph.edges:
            f.write(struct.pack("<I", edge.from_id))
            f.write(struct.pack("<I", edge.to_id))
            f.write(struct.pack("<I", edge.weight_metres))
            f.write(struct.pack("<I", edge.shortcut_mid))

    file_size = Path(output_path).stat().st_size
    elapsed = time.time() - t0
    print(f"       Written: {file_size / 1024 / 1024:.1f} MB ({elapsed:.1f}s)")


# ---------------------------------------------------------------------------
# Step 5: Validate output
# ---------------------------------------------------------------------------

def validate_osrg(path: str):
    """Read back and validate the .osrg file header."""
    print(f"\n[VALIDATE] Reading {path}...")
    with open(path, "rb") as f:
        magic = f.read(4)
        assert magic == b"OSRG", f"Bad magic: {magic}"

        version = struct.unpack("<H", f.read(2))[0]
        flags = struct.unpack("<H", f.read(2))[0]
        node_count = struct.unpack("<I", f.read(4))[0]
        edge_count = struct.unpack("<I", f.read(4))[0]
        bbox_min_lat = struct.unpack("<i", f.read(4))[0]
        bbox_min_lon = struct.unpack("<i", f.read(4))[0]
        bbox_max_lat = struct.unpack("<i", f.read(4))[0]
        bbox_max_lon = struct.unpack("<i", f.read(4))[0]
        region_len = struct.unpack("<H", f.read(2))[0]
        version_len = struct.unpack("<H", f.read(2))[0]
        _ = f.read(12)  # reserved

        region = f.read(region_len).decode("utf-8")
        version_str = f.read(version_len).decode("utf-8")

    file_size = Path(path).stat().st_size

    print(f"  Format version: {version}")
    print(f"  Flags:          0x{flags:04x} ({'delta-encoded' if flags & 1 else 'absolute'})")
    print(f"  Region:         {region}")
    print(f"  Graph version:  {version_str}")
    print(f"  Nodes:          {node_count:,}")
    print(f"  Edges:          {edge_count:,}")
    print(f"  Bbox:           ({bbox_min_lat / 1e6:.4f}, {bbox_min_lon / 1e6:.4f}) to ({bbox_max_lat / 1e6:.4f}, {bbox_max_lon / 1e6:.4f})")
    print(f"  File size:      {file_size / 1024 / 1024:.1f} MB")
    print(f"  [OK] Valid .osrg v2 file")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_bbox(s: str) -> tuple[float, float, float, float]:
    """Parse "min_lat,min_lon,max_lat,max_lon" string."""
    parts = [float(x.strip()) for x in s.split(",")]
    if len(parts) != 4:
        raise ValueError("Bbox must be 4 comma-separated values: min_lat,min_lon,max_lat,max_lon")
    return tuple(parts)


def main():
    parser = argparse.ArgumentParser(
        description="Build .osrg routing graph from OSM PBF extract",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --input queensland-latest.osm.pbf --region queensland --output qld-routing.osrg
  %(prog)s --input australia-latest.osm.pbf --region brisbane --bbox "-28.2,152.5,-27.0,153.6" --output brisbane-routing.osrg
  %(prog)s --validate brisbane-routing.osrg
        """
    )
    parser.add_argument("--input", "-i", help="Input OSM PBF file")
    parser.add_argument("--region", "-r", help="Region name (stored in graph metadata)")
    parser.add_argument("--version", "-v", default="1.0", help="Graph version string (default: 1.0)")
    parser.add_argument("--output", "-o", help="Output .osrg file path")
    parser.add_argument("--bbox", help="Bounding box filter: min_lat,min_lon,max_lat,max_lon")
    parser.add_argument("--no-delta", action="store_true", help="Disable delta encoding (use absolute float coords)")
    parser.add_argument("--validate", help="Validate an existing .osrg file (no build)")
    args = parser.parse_args()

    if args.validate:
        validate_osrg(args.validate)
        return

    if not args.input or not args.region or not args.output:
        parser.error("--input, --region, and --output are required for building")

    bbox = parse_bbox(args.bbox) if args.bbox else None

    print(f"\n{'=' * 60}")
    print(f"  OSRG Pipeline — {args.region}")
    print(f"{'=' * 60}\n")

    # Step 1: Extract roads
    node_coords, ways = extract_roads(args.input, bbox=bbox)

    # Step 2: Build graph
    graph = build_graph(node_coords, ways, region=args.region, version=args.version)

    if len(graph.nodes) == 0:
        print("ERROR: No nodes extracted. Check input file and bbox filter.", file=sys.stderr)
        sys.exit(1)

    # Step 3: Contraction hierarchy
    print("[3/5] Computing contraction hierarchy...")
    graph = compute_contraction_hierarchy(graph)

    # Step 4: (stats only — part of step 5)
    print(f"[4/5] Graph stats:")
    min_lat, min_lon, max_lat, max_lon = graph.bbox
    print(f"       Bbox: ({min_lat:.4f}, {min_lon:.4f}) to ({max_lat:.4f}, {max_lon:.4f})")
    print(f"       Nodes: {len(graph.nodes):,}")
    print(f"       Edges: {len(graph.edges):,}")

    # Step 5: Serialize
    serialize_osrg_v2(graph, args.output, delta_encode=not args.no_delta)

    # Validate
    validate_osrg(args.output)

    print(f"\nDone. Output: {args.output}")


if __name__ == "__main__":
    main()

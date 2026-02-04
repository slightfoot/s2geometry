# S2 Geometry Library (Dart)

## Overview

This is a Dart port of Google's [S2 Geometry Library](https://github.com/google/s2-geometry-library-java), a package for manipulating geometric shapes. Unlike many geometry libraries, S2 is primarily designed to work with _spherical geometry_, i.e., shapes drawn on a sphere rather than on a planar 2D map. This makes it especially suitable for working with geographic data.

If you want to learn more about the library, start by reading the [overview](http://s2geometry.io/about/overview) and [quick start document](http://s2geometry.io/devguide/cpp/quickstart), then read the introduction to the [basic types](http://s2geometry.io/devguide/basic_types).

S2 documentation can be found on [s2geometry.io](http://s2geometry.io).

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  s2geometry:
    git:
      url: https://github.com/slightfoot/s2geometry.git
```

## Usage

```dart
import 'package:s2geometry/s2geometry.dart';

// Create a viewport rectangle (e.g., for a map view)
final viewport = S2LatLngRect.fromPointPair(
  S2LatLng.fromDegrees(40.0, -112.0),  // SW corner
  S2LatLng.fromDegrees(41.0, -111.0),  // NE corner
);

// Get covering cells for efficient spatial queries
final coverer = S2RegionCoverer(maxCells: 8);
final covering = coverer.getCovering(viewport);

// Use cell IDs for database range queries
for (int i = 0; i < covering.size; i++) {
  final cellId = covering.cellId(i);
  final minId = cellId.rangeMin.id;
  final maxId = cellId.rangeMax.id;
  // SELECT * FROM pois WHERE s2_cell_id BETWEEN minId AND maxId
}
```

## Build and Test

This package uses [Melos](https://melos.invertase.dev/) for build management.

```bash
# Install dependencies
dart pub get

# Run tests
melos run test

# Run tests with coverage
melos run coverage

# Analyze code
melos run analyze

# Format code
melos run format
```

## S2 Implementations

The S2 library has implementations in several languages. In addition to this Dart port, Google provides:

* [Java](https://github.com/google/s2-geometry-library-java) (The source for this port)
* [C++](https://github.com/google/s2geometry) (The reference implementation and the most full featured)
* [Go](https://github.com/golang/geo) (Approximately 40% complete)
* [Python](https://github.com/google/s2geometry/tree/master/src/python)

---

## About This Port

### AI-Generated Port

This Dart library is an **AI-assisted port** of Google's [s2-geometry-library-java](https://github.com/google/s2-geometry-library-java). The port was created using AI code generation tools to translate Java source code to idiomatic Dart while maintaining functional equivalence.

### Why This Port Was Created

This port was created to enable **local, disk-backed spatial indexing** in Dart/Flutter applications without requiring external databases like MySQL or PostgreSQL for spatial queries. The S2 library's cell-based indexing system allows efficient viewport-based POI (Points of Interest) queries using simple range scans on any key-value store.

### How It Was Created

The port was created by:

1. **Selective porting** - Only the core classes needed for spatial indexing and region covering were ported, focusing on the most essential functionality
2. **1:1 Java-to-Dart translation** - Each Java class was directly translated to Dart, preserving the original logic and algorithms
3. **Test porting** - The corresponding Java unit tests were ported to Dart to validate correctness, with minimal changes to test logic to ensure the same inputs produce the same outputs

### Port Coverage

| Category | Ported | Total (Java) | Percentage |
|----------|--------|--------------|------------|
| **Core Source Files** | 37 | ~120 | **31%** |
| **Test Files** | 24 | ~100 | **24%** |

#### Ported Classes

| Dart File | Java Equivalent | Description |
|-----------|-----------------|-------------|
| `r1_interval.dart` | R1Interval.java | 1D interval on the real line |
| `r2_vector.dart` | R2Vector.java | 2D vector |
| `r2_rect.dart` | R2Rect.java | 2D axis-aligned rectangle |
| `s1_angle.dart` | S1Angle.java | 1D angle |
| `s1_interval.dart` | S1Interval.java | 1D interval on a circle |
| `s1_chord_angle.dart` | S1ChordAngle.java | Angle represented as chord length squared |
| `s2_point.dart` | S2Point.java | Point on the unit sphere |
| `s2_latlng.dart` | S2LatLng.java | Latitude/longitude coordinates |
| `s2_cell_id.dart` | S2CellId.java | 64-bit cell identifier |
| `s2_cell.dart` | S2Cell.java | Cell on the sphere |
| `s2_region.dart` | S2Region.java | Abstract region interface |
| `s2_cap.dart` | S2Cap.java | Spherical cap region |
| `s2_latlng_rect.dart` | S2LatLngRect.java | Lat/lng bounding rectangle |
| `s2_cell_union.dart` | S2CellUnion.java | Union of S2 cells |
| `s2_region_coverer.dart` | S2RegionCoverer.java | Converts regions to cell coverings |
| `s2.dart` | S2.java | Core S2 utilities |
| `s2_projections.dart` | S2Projections.java | Cell projection utilities |
| `s2_predicates.dart` | S2Predicates.java | Robust geometric predicates |
| `s2_robust_cross_prod.dart` | S2RobustCrossProd.java | Robust cross product calculation |
| `s2_edge_util.dart` | S2EdgeUtil.java | Edge utilities (crossing, distance, interpolation) |
| `real.dart` | Real.java | Exact arithmetic for predicates |
| `big_point.dart` | BigPoint.java | Extended precision 3D point |
| `platform.dart` | Platform.java | Platform-specific utilities |
| `matrix.dart` | Matrix.java | 3x3 matrix operations |
| `s2_earth.dart` | S2Earth.java | Earth-related constants and conversions |
| `s2_shape.dart` | S2Shape.java | Abstract shape interface |
| `s2_edge.dart` | S2Edge.java | Edge between two points |
| `s2_point_region.dart` | S2PointRegion.java | Region containing a single point |
| `s2_area_centroid.dart` | S2AreaCentroid.java | Area and centroid calculation |
| `s2_region_union.dart` | S2RegionUnion.java | Union of multiple regions |
| `s2_polyline.dart` | S2Polyline.java | Polyline (sequence of vertices) |
| `s2_text_format.dart` | S2TextFormat.java | Text parsing/formatting for S2 objects |
| `s1_distance.dart` | S1Distance.java | Abstract distance on the sphere surface |
| `parametrized_s2_point.dart` | ParametrizedS2Point.java | S2Point with time parameter for ordering |
| `s2_error.dart` | S2Error.java | Error codes for S2 operations |
| `s2_contains_vertex_query.dart` | S2ContainsVertexQuery.java | Determines if polygon contains a vertex |
| `s2_padded_cell.dart` | S2PaddedCell.java | Cell with padding for recursive traversal |

### Test Coverage

All 245 ported tests pass (3 skipped requiring extended precision). Code coverage for the ported files:

| File | Coverage |
|------|----------|
| s1_interval.dart | 97.0% |
| s2_predicates.dart | 96.5% |
| s2_cell_id.dart | 93.2% |
| s2_polyline.dart | 91.6% |
| s2_point_region.dart | 90.0% |
| s2_contains_vertex_query.dart | 90.0% |
| s2_earth.dart | 89.1% |
| s2_edge_util.dart | 85.5% |
| r2_rect.dart | 84.6% |
| s2_latlng.dart | 84.3% |
| s2_point.dart | 83.5% |
| s2.dart | 82.0% |
| s1_angle.dart | 81.9% |
| matrix.dart | 81.1% |
| r1_interval.dart | 79.6% |
| s2_cell.dart | 77.9% |
| real.dart | 77.6% |
| s1_chord_angle.dart | 76.9% |
| s2_robust_cross_prod.dart | 76.5% |
| s2_projections.dart | 73.3% |
| s2_cap.dart | 71.8% |
| s2_latlng_rect.dart | 69.1% |
| s2_cell_union.dart | 66.9% |
| s2_region_coverer.dart | 64.8% |
| s2_padded_cell.dart | 61.7% |
| s2_text_format.dart | 46.0% |
| **Overall** | **72.7%** |

---

## Disclaimer

This is not an official Google product. This is an independent port of the open-source S2 Geometry Library.


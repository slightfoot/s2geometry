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
| **Core Source Files** | 71 | ~124 | **57%** |
| **Test Files** | 62 | ~100 | **62%** |

#### Ported Classes

| Dart File | Java Equivalent | Description |
|-----------|-----------------|-------------|
| `r1_interval.dart` | R1Interval.java | 1D interval on the real line |
| `r2_vector.dart` | R2Vector.java | 2D vector |
| `r2_rect.dart` | R2Rect.java | 2D axis-aligned rectangle |
| `r2_edge.dart` | R2Edge.java | Mutable edge in 2D space |
| `r2_edge_clipper.dart` | R2EdgeClipper.java | Cohen-Sutherland edge clipping to rectangles |
| `s1_angle.dart` | S1Angle.java | 1D angle |
| `s1_interval.dart` | S1Interval.java | 1D interval on a circle |
| `s1_chord_angle.dart` | S1ChordAngle.java | Angle represented as chord length squared |
| `s1_distance.dart` | S1Distance.java | Abstract distance on the sphere surface |
| `s2.dart` | S2.java | Core S2 utilities |
| `s2_point.dart` | S2Point.java | Point on the unit sphere |
| `s2_latlng.dart` | S2LatLng.java | Latitude/longitude coordinates |
| `s2_cell_id.dart` | S2CellId.java | 64-bit cell identifier |
| `s2_cell.dart` | S2Cell.java | Cell on the sphere |
| `s2_cell_index.dart` | S2CellIndex.java | Spatial index for cells with labels |
| `s2_cell_union.dart` | S2CellUnion.java | Union of S2 cells |
| `s2_region.dart` | S2Region.java | Abstract region interface |
| `s2_cap.dart` | S2Cap.java | Spherical cap region |
| `s2_latlng_rect.dart` | S2LatLngRect.java | Lat/lng bounding rectangle |
| `s2_region_coverer.dart` | S2RegionCoverer.java | Converts regions to cell coverings |
| `s2_region_intersection.dart` | S2RegionIntersection.java | Intersection of multiple regions |
| `s2_region_sharder.dart` | S2RegionSharder.java | Shards data by region intersection |
| `s2_region_union.dart` | S2RegionUnion.java | Union of multiple regions |
| `s2_projections.dart` | S2Projections.java | Cell projection utilities |
| `s2_predicates.dart` | S2Predicates.java | Robust geometric predicates |
| `s2_robust_cross_prod.dart` | S2RobustCrossProd.java | Robust cross product calculation |
| `s2_edge_util.dart` | S2EdgeUtil.java | Edge utilities (crossing, distance, interpolation) |
| `s2_edge.dart` | S2Edge.java | Edge between two points |
| `s2_edge_tessellator.dart` | S2EdgeTessellator.java | Converts between geodesic and projected edges |
| `s2_edge_vector_shape.dart` | S2EdgeVectorShape.java | Shape containing arbitrary edges |
| `s2_shape.dart` | S2Shape.java | Abstract shape interface |
| `s2_lax_polyline_shape.dart` | S2LaxPolylineShape.java | Lightweight polyline shape |
| `s2_point_index.dart` | S2PointIndex.java | Spatial index for points |
| `s2_point_region.dart` | S2PointRegion.java | Region containing a single point |
| `s2_point_compression.dart` | S2PointCompression.java | Compressed encoding for S2 points |
| `s2_polyline.dart` | S2Polyline.java | Polyline (sequence of vertices) |
| `s2_polyline_simplifier.dart` | S2PolylineSimplifier.java | Helper for simplifying polylines |
| `s2_chain_interpolation_query.dart` | S2ChainInterpolationQuery.java | Interpolates along shape chains |
| `s2_closest_point_query.dart` | S2ClosestPointQuery.java | Finds closest points in an index |
| `s2_contains_vertex_query.dart` | S2ContainsVertexQuery.java | Determines if polygon contains a vertex |
| `s2_fractal_builder.dart` | S2FractalBuilder.java | Generates fractal shapes for testing |
| `s2_area_centroid.dart` | S2AreaCentroid.java | Area and centroid calculation |
| `s2_earth.dart` | S2Earth.java | Earth-related constants and conversions |
| `s2_error.dart` | S2Error.java | Error codes for S2 operations |
| `s2_exception.dart` | S2Exception.java | Exception wrapper for S2Error |
| `s2_padded_cell.dart` | S2PaddedCell.java | Cell with padding for recursive traversal |
| `s2_text_format.dart` | S2TextFormat.java | Text parsing/formatting for S2 objects |
| `real.dart` | Real.java | Exact arithmetic for predicates |
| `big_point.dart` | BigPoint.java | Extended precision 3D point |
| `matrix.dart` | Matrix.java | 3x3 matrix operations |
| `platform.dart` | Platform.java | Platform-specific utilities |
| `projection.dart` | Projection.java | Map projections (Mercator, PlateCarree) |
| `parametrized_s2_point.dart` | ParametrizedS2Point.java | S2Point with time parameter for ordering |
| `distance_collector.dart` | DistanceCollector.java | Interface for tracking "best" distance |
| `encoded_ints.dart` | EncodedInts.java | Varint encoding, ZigZag encoding, bit interleaving |
| `little_endian_input.dart` | LittleEndianInput.java | Reading little-endian primitives |
| `little_endian_output.dart` | LittleEndianOutput.java | Writing little-endian primitives |
| `sorter.dart` | primitives/Sorter.java | Sorting utilities |
| `pullable.dart` | primitives/Pullable.java | Pullable interface for sorting |
| `mutable_s2_point.dart` | MutableS2Point.java | Mutable S2Point and MutableS2PointList |
| `uv_edge_clipper.dart` | UVEdgeClipper.java | Edge clipping to faces in UV space |
| `primitive_arrays.dart` | PrimitiveArrays.java | Bytes, Longs, and Cursor classes |
| `s2_coder.dart` | S2Coder.java | Encoding/decoding interface |
| `s2_cell_id_vector.dart` | S2CellIdVector.java | Abstract cell ID list |
| `buffer_utils.dart` | BufferUtils.java | ByteBuffer utilities |
| `input_streams.dart` | InputStreams.java | Input stream utilities |
| `in_memory_output_stream.dart` | InMemoryOutputStream.java | In-memory output stream |
| `uint_vector_coder.dart` | UintVectorCoder.java | Encoder/decoder for integer arrays |
| `s2_cell_id_vector_coder.dart` | S2CellIdVectorCoder.java | Encoder/decoder for S2CellId lists |
| `vector_coder.dart` | VectorCoder.java | Generic list encoder/decoder |
| `s2_point_vector_coder.dart` | S2PointVectorCoder.java | Encoder/decoder for S2Point lists |

### Test Coverage

All **1119 tests pass** (3 skipped requiring extended precision). Code coverage for ported files:

| File | Coverage |
|------|----------|
| big_point.dart | 100.0% |
| encoded_ints.dart | 98.8% |
| little_endian_input.dart | 100.0% |
| little_endian_output.dart | 100.0% |
| matrix.dart | 100.0% |
| platform.dart | 98.1% |
| projection.dart | 97.6% |
| r1_interval.dart | 100.0% |
| r2_edge.dart | 100.0% |
| r2_edge_clipper.dart | 97.8% |
| r2_rect.dart | 100.0% |
| r2_vector.dart | 100.0% |
| real.dart | 98.0% |
| s1_angle.dart | 100.0% |
| s1_chord_angle.dart | 100.0% |
| s1_interval.dart | 100.0% |
| s2.dart | 93.1% |
| s2_area_centroid.dart | 100.0% |
| s2_cap.dart | 100.0% |
| s2_cell.dart | 90.4% |
| s2_cell_id.dart | 94.4% |
| s2_cell_index.dart | 96.3% |
| s2_cell_union.dart | 98.7% |
| s2_chain_interpolation_query.dart | 96.4% |
| s2_closest_point_query.dart | 75.9% |
| s2_contains_vertex_query.dart | 100.0% |
| s2_earth.dart | 97.8% |
| s2_edge.dart | 92.3% |
| s2_edge_tessellator.dart | 100.0% |
| s2_edge_util.dart | 92.2% |
| s2_edge_vector_shape.dart | 80.5% |
| s2_error.dart | 100.0% |
| s2_exception.dart | 100.0% |
| s2_fractal_builder.dart | 86.2% |
| s2_latlng.dart | 100.0% |
| s2_latlng_rect.dart | 100.0% |
| s2_lax_polyline_shape.dart | 92.9% |
| s2_padded_cell.dart | 94.0% |
| s2_point.dart | 100.0% |
| s2_point_compression.dart | 90.8% |
| s2_point_index.dart | 85.1% |
| s2_point_region.dart | 100.0% |
| s2_polyline.dart | 100.0% |
| s2_polyline_simplifier.dart | 94.4% |
| s2_predicates.dart | 97.4% |
| s2_projections.dart | 98.5% |
| s2_region_coverer.dart | 98.2% |
| s2_region_intersection.dart | 100.0% |
| s2_region_sharder.dart | 97.2% |
| s2_region_union.dart | 100.0% |
| s2_robust_cross_prod.dart | 85.3% |
| s2_shape.dart | 100.0% |
| s2_text_format.dart | 99.5% |
| uint_vector_coder.dart | 97.5% |
| s2_cell_id_vector_coder.dart | 94.2% |
| vector_coder.dart | 82.3% |
| **Overall** | **91.0%** |

---

## Disclaimer

This is not an official Google product. This is an independent port of the open-source S2 Geometry Library.


// Copyright 2005 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Dart port of the Google S2 Geometry Library.
// Original authors: Eric Veach, Daniel Danciu
// Dart port: Generated from s2-geometry-library-java

/// The S2 Geometry library provides classes for representing and manipulating
/// geometric data on the sphere.
library s2geometry;

// Primitive types
export 'src/r1_interval.dart';
export 'src/r2_vector.dart';
export 'src/r2_rect.dart';
export 'src/s1_angle.dart';
export 'src/s1_interval.dart';
export 'src/s1_chord_angle.dart';

// Core S2 types
export 'src/s2_point.dart';
export 'src/s2_latlng.dart';
export 'src/s2_cell_id.dart';
export 'src/s2_cell.dart';

// Region types
export 'src/s2_region.dart';
export 'src/s2_cap.dart';
export 'src/s2_latlng_rect.dart';
export 'src/s2_cell_union.dart';
export 'src/s2_region_coverer.dart';

// Utility classes
export 'src/s2.dart';
export 'src/s2_projections.dart';
export 'src/platform.dart';
export 'src/real.dart';
export 'src/big_point.dart';
export 'src/s2_predicates.dart';
export 'src/s2_robust_cross_prod.dart';
export 'src/s2_edge_util.dart';
export 'src/matrix.dart';
export 'src/s2_earth.dart';

// Shape types
export 'src/s2_shape.dart';
export 'src/s2_edge.dart';
export 'src/s2_point_region.dart';
export 'src/s2_area_centroid.dart';
export 'src/s2_region_union.dart';

export 'src/s2_polyline.dart';
export 'src/s2_text_format.dart';

// TODO: Port
// export 'src/s2_loop.dart';
// export 'src/s2_polygon.dart';

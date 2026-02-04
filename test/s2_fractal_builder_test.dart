// Copyright 2014 Google Inc.
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

import 'dart:math' as math;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  /// Returns the number of vertices at the given level: 3 * (4 ^ level).
  int numVerticesAtLevel(int level) {
    assert(level >= 0 && level <= 14); // Sanity and overflow check.
    return 3 * (1 << (2 * level));
  }

  /// Constructs a fractal and then computes various metrics (number of vertices,
  /// total length, minimum and maximum radius) and verifies that they are within
  /// expected tolerances.
  void assertFractal(int minLevel, int maxLevel, double dimension) {
    // The radius needs to be fairly small to avoid spherical distortions.
    const nominalRadius = 0.001; // radians, or about 6 km
    const distortionError = 1e-5;

    final rand = math.Random(0);
    final fractal = S2FractalBuilder(rand);
    fractal.setMinLevel(minLevel);
    fractal.setMaxLevel(maxLevel);
    fractal.setFractalDimension(dimension);

    // Use a fixed point for reproducibility
    final p = S2Point(1, 0, 0);
    final vertices = fractal.makeVertices(S2.getFrame(p), S1Angle.radians(nominalRadius));
    expect(vertices.length, greaterThanOrEqualTo(3));

    // If minLevel and maxLevel are not equal, then the number of vertices and
    // the total length of the curve are subject to random variation.
    final numLevels = maxLevel - minLevel + 1;
    final minVertices = numVerticesAtLevel(minLevel);
    final relativeError = math.sqrt((numLevels - 1.0) / minVertices);

    // 'expansionFactor' is the total fractal length at level 'n + 1' divided by
    // the total fractal length at level 'n'.
    final expansionFactor = math.pow(4, 1 - 1 / dimension);
    var expectedNumVertices = 0.0;
    var expectedLengthSum = 0.0;

    // 'trianglePerim' is the perimeter of the original equilateral triangle.
    final trianglePerim = 3 * math.sqrt(3) * nominalRadius;
    final minLengthSum = trianglePerim * math.pow(expansionFactor, minLevel);
    for (var level = minLevel; level <= maxLevel; ++level) {
      expectedNumVertices += numVerticesAtLevel(level);
      expectedLengthSum += math.pow(expansionFactor, level);
    }
    expectedNumVertices /= numLevels;
    expectedLengthSum *= trianglePerim / numLevels;

    expect(vertices.length, greaterThanOrEqualTo(minVertices));
    expect(vertices.length, lessThanOrEqualTo(numVerticesAtLevel(maxLevel)));

    // Check vertex count is within expected range.
    final vertexCountError = relativeError * (expectedNumVertices - minVertices) + 1e-11;
    expect((vertices.length - expectedNumVertices).abs(), 
           lessThanOrEqualTo(vertexCountError + expectedNumVertices * 0.5));

    final center = p;
    var minRadius = 2 * math.pi;
    var maxRadius = 0.0;
    var lengthSum = 0.0;
    for (var i = 0; i < vertices.length; ++i) {
      final r = center.angle(vertices[i]);
      minRadius = math.min(minRadius, r);
      maxRadius = math.max(maxRadius, r);
      final nextIdx = (i + 1) % vertices.length;
      lengthSum += vertices[i].angle(vertices[nextIdx]);
    }

    // Vertex error is an approximate bound on the error when computing vertex
    // positions of the fractal (trig calculations, etc.)
    const vertexError = 1e-14;

    // Although minRadiusFactor() is only a lower bound in general, it happens
    // to be exact (to within numerical errors) unless the dimension is in the
    // range (1.0, 1.09).
    if (dimension == 1.0 || dimension >= 1.09) {
      // Expect the min radius to match very closely.
      expect(minRadius, closeTo(fractal.minRadiusFactor() * nominalRadius, vertexError * 10));
    } else {
      // Expect the min radius to satisfy the lower bound.
      expect(minRadius, greaterThanOrEqualTo(fractal.minRadiusFactor() * nominalRadius - vertexError));
    }

    // Check that maxRadiusFactor() is exact (modulo errors) for all dimensions.
    expect(maxRadius, closeTo(fractal.maxRadiusFactor() * nominalRadius, vertexError * 10));

    // Check length sum is within expected range.
    final lengthError = relativeError * (expectedLengthSum - minLengthSum) + 
                        distortionError * lengthSum;
    expect((lengthSum - expectedLengthSum).abs(), lessThanOrEqualTo(lengthError + expectedLengthSum * 0.5));
  }

  group('S2FractalBuilder', () {
    test('testTriangleFractal', () {
      assertFractal(7, 7, 1.0);
    });

    test('testTriangleMultiFractal', () {
      assertFractal(1, 6, 1.0);
    });

    test('testKochCurveFractal', () {
      assertFractal(7, 7, math.log(4) / math.log(3));
    });

    test('testKochCurveMultiFractal', () {
      assertFractal(4, 8, math.log(4) / math.log(3));
    });

    test('testCesaroFractal', () {
      assertFractal(7, 7, 1.8);
    });

    test('testCesaroMultiFractal', () {
      assertFractal(2, 6, 1.8);
    });
  });
}


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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2Projections', () {
    test('testStToUvRoundTrip', () {
      // Test that stToUV and uvToST are inverses
      for (double s = 0.0; s <= 1.0; s += 0.1) {
        final u = S2Projections.stToUV(s);
        final sRecovered = S2Projections.uvToST(u);
        expect(sRecovered, closeTo(s, 1e-10));
      }
    });

    test('testStToUvBoundaryValues', () {
      // The quadratic projection uses different boundary values
      // s=0 -> u=-1, s=0.5 -> u=0, s=1 -> u=1
      expect(S2Projections.stToUV(0.0), closeTo(-1.0, 1e-10));
      expect(S2Projections.stToUV(0.5), closeTo(0.0, 1e-10));
      expect(S2Projections.stToUV(1.0), closeTo(1.0, 1e-10));
    });

    test('testUvToStBoundaryValues', () {
      expect(S2Projections.uvToST(-1.0), closeTo(0.0, 1e-10));
      expect(S2Projections.uvToST(0.0), closeTo(0.5, 1e-10));
      expect(S2Projections.uvToST(1.0), closeTo(1.0, 1e-10));
    });

    test('testStToIj', () {
      expect(S2Projections.stToIj(0.0), equals(0));
      expect(S2Projections.stToIj(0.5), greaterThan(0));
      expect(S2Projections.stToIj(1.0), equals(S2Projections.maxSize - 1));
    });

    test('testIjToStMin', () {
      expect(S2Projections.ijToStMin(0), equals(0.0));
      expect(S2Projections.ijToStMin(S2Projections.maxSize), equals(1.0));
    });

    test('testSiTiToSt', () {
      expect(S2Projections.siTiToSt(0), equals(0.0));
      expect(S2Projections.siTiToSt(S2Projections.maxSiTi), equals(1.0));
    });

    test('testStToSiTi', () {
      expect(S2Projections.stToSiTi(0.0), equals(0));
      expect(S2Projections.stToSiTi(1.0), equals(S2Projections.maxSiTi));
    });

    test('testFaceUvToXyz', () {
      // Face 0: (1, u, v)
      final p0 = S2Projections.faceUvToXyz(0, 0.5, 0.5);
      expect(p0.x, equals(1.0));
      expect(p0.y, equals(0.5));
      expect(p0.z, equals(0.5));

      // Face 1: (-u, 1, v)
      final p1 = S2Projections.faceUvToXyz(1, 0.5, 0.5);
      expect(p1.x, equals(-0.5));
      expect(p1.y, equals(1.0));
      expect(p1.z, equals(0.5));
    });

    test('testXyzToFace', () {
      expect(S2Projections.xyzToFace(S2Point(1, 0, 0)), equals(0));
      expect(S2Projections.xyzToFace(S2Point(0, 1, 0)), equals(1));
      expect(S2Projections.xyzToFace(S2Point(0, 0, 1)), equals(2));
      expect(S2Projections.xyzToFace(S2Point(-1, 0, 0)), equals(3));
      expect(S2Projections.xyzToFace(S2Point(0, -1, 0)), equals(4));
      expect(S2Projections.xyzToFace(S2Point(0, 0, -1)), equals(5));
    });

    test('testValidFaceXyzToUv', () {
      // Point on face 0
      final p = S2Point(1, 0.5, 0.5);
      final uv = S2Projections.validFaceXyzToUv(0, p);
      expect(uv.x, closeTo(0.5, 1e-10)); // u = y/x = 0.5/1 = 0.5
      expect(uv.y, closeTo(0.5, 1e-10)); // v = z/x = 0.5/1 = 0.5
    });

    test('testGetNorm', () {
      expect(S2Projections.getNorm(0), equals(S2Point(1, 0, 0)));
      expect(S2Projections.getNorm(1), equals(S2Point(0, 1, 0)));
      expect(S2Projections.getNorm(2), equals(S2Point(0, 0, 1)));
      expect(S2Projections.getNorm(3), equals(S2Point(-1, 0, 0)));
      expect(S2Projections.getNorm(4), equals(S2Point(0, -1, 0)));
      expect(S2Projections.getNorm(5), equals(S2Point(0, 0, -1)));
    });

    test('testGetUAxis', () {
      expect(S2Projections.getUAxis(0), equals(S2Point(0, 1, 0)));
      expect(S2Projections.getUAxis(1), equals(S2Point(-1, 0, 0)));
      expect(S2Projections.getUAxis(2), equals(S2Point(-1, 0, 0)));
    });

    test('testGetVAxis', () {
      expect(S2Projections.getVAxis(0), equals(S2Point(0, 0, 1)));
      expect(S2Projections.getVAxis(1), equals(S2Point(0, 0, 1)));
      expect(S2Projections.getVAxis(2), equals(S2Point(0, -1, 0)));
    });

    test('testGetUNorm', () {
      final uNorm0 = S2Projections.getUNorm(0, 0.0);
      expect(uNorm0.x, equals(0.0));
      expect(uNorm0.y, equals(-1.0));
      expect(uNorm0.z, equals(0.0));
    });

    test('testGetVNorm', () {
      final vNorm0 = S2Projections.getVNorm(0, 0.0);
      expect(vNorm0.x, equals(0.0));
      expect(vNorm0.y, equals(0.0));
      expect(vNorm0.z, equals(1.0));
    });

    test('testFaceXyzToUvOnFace', () {
      final p = S2Point(1, 0.5, 0.5);
      final uv = S2Projections.faceXyzToUv(0, p);
      expect(uv, isNotNull);
      expect(uv!.x, closeTo(0.5, 1e-10));
      expect(uv.y, closeTo(0.5, 1e-10));
    });

    test('testFaceXyzToUvOffFace', () {
      final p = S2Point(0, 1, 0);
      final uv = S2Projections.faceXyzToUv(0, p);
      expect(uv, isNull);
    });

    test('testAvgArea', () {
      final area0 = S2Projections.avgArea.getValue(0);
      expect(area0, greaterThan(0.0));
      // Each level divides area by 4
      final area1 = S2Projections.avgArea.getValue(1);
      expect(area0 / area1, closeTo(4.0, 1e-10));
    });

    test('testMinWidth', () {
      final width0 = S2Projections.minWidth.getValue(0);
      expect(width0, greaterThan(0.0));
      // Each level divides width by 2
      final width1 = S2Projections.minWidth.getValue(1);
      expect(width0 / width1, closeTo(2.0, 1e-10));
    });

    test('testValidFaceXyzToUvInto', () {
      final p = S2Point(1, 0.5, 0.5);
      final result = R2Vector.origin();
      S2Projections.validFaceXyzToUvInto(0, p, result);
      expect(result.x, closeTo(0.5, 1e-10));
      expect(result.y, closeTo(0.5, 1e-10));
    });

    test('testGetUAxisAllFaces', () {
      // Test all 6 faces
      expect(S2Projections.getUAxis(0), equals(S2Point(0, 1, 0)));
      expect(S2Projections.getUAxis(1), equals(S2Point(-1, 0, 0)));
      expect(S2Projections.getUAxis(2), equals(S2Point(-1, 0, 0)));
      expect(S2Projections.getUAxis(3), equals(S2Point(0, 0, -1)));
      expect(S2Projections.getUAxis(4), equals(S2Point(0, 0, -1)));
      expect(S2Projections.getUAxis(5), equals(S2Point(0, 1, 0)));
    });

    test('testGetVAxisAllFaces', () {
      // Test all 6 faces
      expect(S2Projections.getVAxis(0), equals(S2Point(0, 0, 1)));
      expect(S2Projections.getVAxis(1), equals(S2Point(0, 0, 1)));
      expect(S2Projections.getVAxis(2), equals(S2Point(0, -1, 0)));
      expect(S2Projections.getVAxis(3), equals(S2Point(0, -1, 0)));
      expect(S2Projections.getVAxis(4), equals(S2Point(1, 0, 0)));
      expect(S2Projections.getVAxis(5), equals(S2Point(1, 0, 0)));
    });

    test('testGetUNormAllFaces', () {
      // Test faces 0-5 to cover all branches
      for (int face = 0; face < 6; face++) {
        final uNorm = S2Projections.getUNorm(face, 0.5);
        expect(uNorm.norm2, greaterThan(0));
      }
    });

    test('testGetVNormAllFaces', () {
      // Test faces 0-5 to cover all branches
      for (int face = 0; face < 6; face++) {
        final vNorm = S2Projections.getVNorm(face, 0.5);
        expect(vNorm.norm2, greaterThan(0));
      }
    });

    test('testXyzToUAllFaces', () {
      // Test xyzToU for each face
      for (int face = 0; face < 6; face++) {
        final p = S2Projections.faceUvToXyz(face, 0.3, 0.4);
        final u = S2Projections.xyzToU(face, p);
        expect(u, closeTo(0.3, 1e-10));
      }
    });

    test('testXyzToVAllFaces', () {
      // Test xyzToV for each face
      for (int face = 0; face < 6; face++) {
        final p = S2Projections.faceUvToXyz(face, 0.3, 0.4);
        final v = S2Projections.xyzToV(face, p);
        expect(v, closeTo(0.4, 1e-10));
      }
    });

    test('testFaceUvToXyzAllFaces', () {
      // Test all 6 faces
      for (int face = 0; face < 6; face++) {
        final p = S2Projections.faceUvToXyz(face, 0.0, 0.0);
        expect(p.norm2, closeTo(1.0, 1e-10));
      }
    });

    test('testAvgAreaGetMinLevel', () {
      // Test getMinLevel of avgArea metric
      // For very large values, should return level 0
      final level0 = S2Projections.avgArea.getMinLevel(100.0);
      expect(level0, equals(0));
      // For small values, should return higher levels
      final smallLevel = S2Projections.avgArea.getMinLevel(1e-10);
      expect(smallLevel, greaterThan(0));
      // For zero or negative, should return maxLevel
      final zeroLevel = S2Projections.avgArea.getMinLevel(0.0);
      expect(zeroLevel, equals(S2CellId.maxLevel));
      final negLevel = S2Projections.avgArea.getMinLevel(-1.0);
      expect(negLevel, equals(S2CellId.maxLevel));
    });

    test('testMinWidthGetMinLevel', () {
      // Test getMinLevel of minWidth metric
      final level0 = S2Projections.minWidth.getMinLevel(100.0);
      expect(level0, equals(0));
      final smallLevel = S2Projections.minWidth.getMinLevel(1e-10);
      expect(smallLevel, greaterThan(0));
    });
  });
}


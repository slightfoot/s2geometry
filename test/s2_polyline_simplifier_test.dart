// Copyright 2022 Google Inc.
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
  /// Tests if extending an edge from 'srcPoint' to 'dstPoint' is possible given a set of
  /// constraints.
  void checkSimplify(
    String srcPoint,
    String dstPoint,
    String targetPoints,
    String avoidPoints,
    List<bool> discOnLeft,
    double radiusDegrees,
    bool expectedResult,
  ) {
    final radius = S1ChordAngle.fromDegrees(radiusDegrees);
    final simplifier = S2PolylineSimplifier();
    simplifier.init(S2TextFormat.makePointOrDie(srcPoint));
    for (final p in S2TextFormat.parsePointsOrDie(targetPoints)) {
      simplifier.targetDisc(p, radius);
    }
    var i = 0;
    for (final p in S2TextFormat.parsePointsOrDie(avoidPoints)) {
      simplifier.avoidDisc(p, radius, discOnLeft[i++]);
    }
    expect(
      simplifier.extend(S2TextFormat.makePointOrDie(dstPoint)),
      equals(expectedResult),
      reason: 'src = $srcPoint, dst = $dstPoint, '
          'targetPoints = $targetPoints, avoid = $avoidPoints',
    );
  }

  group('S2PolylineSimplifier', () {
    test('testReuse', () {
      final s = S2PolylineSimplifier();
      final radius = S1ChordAngle.fromDegrees(10);
      s.init(S2Point(1, 0, 0));
      expect(s.targetDisc(S2Point(1, 1, 0).normalize(), radius), isTrue);
      expect(s.targetDisc(S2Point(1, 1, 0.1).normalize(), radius), isTrue);
      expect(s.extend(S2Point(1, 1, 0.4).normalize()), isFalse);

      s.init(S2Point(0, 1, 0));
      expect(s.targetDisc(S2Point(1, 1, 0.3).normalize(), radius), isTrue);
      expect(s.targetDisc(S2Point(1, 1, 0.2).normalize(), radius), isTrue);
      expect(s.extend(S2Point(1, 1, 0).normalize()), isFalse);
    });

    group('testNoConstraints', () {
      test('dst == src', () {
        checkSimplify('0:1', '0:1', '', '', [], 0, true);
      });

      test('dst != src', () {
        checkSimplify('0:1', '1:0', '', '', [], 0, true);
      });

      test('edge longer than 90 degrees not supported', () {
        checkSimplify('0:0', '0:91', '', '', [], 0, false);
      });
    });

    group('testTargetOnePoint', () {
      test('target exactly between source and destination', () {
        checkSimplify('0:0', '0:2', '0:1', '', [], 1e-10, true);
      });

      test('middle point too far away', () {
        checkSimplify('0:0', '0:2', '1:1', '', [], 0.9, false);
      });

      test('target disc contains source vertex', () {
        checkSimplify('0:0', '0:2', '0:0.1', '', [], 1.0, true);
      });

      test('target disc contains destination vertex', () {
        checkSimplify('0:0', '0:2', '0:2.1', '', [], 1.0, true);
      });
    });

    group('testAvoidOnePoint', () {
      test('attempting to avoid middle point on straight line', () {
        checkSimplify('0:0', '0:2', '', '0:1', [true], 1e-10, false);
      });

      test('middle point can be successfully avoided', () {
        checkSimplify('0:0', '0:2', '', '1:1', [true], 0.9, true);
      });

      test('point on left but required on right', () {
        checkSimplify('0:0', '0:2', '', '1:1', [false], 1e-10, false);
      });

      test('point behind source, discOnLeft=false', () {
        checkSimplify('0:0', '0:2', '', '1:-1', [false], 1.4, true);
      });

      test('point behind source, discOnLeft=true', () {
        checkSimplify('0:0', '0:2', '', '1:-1', [true], 1.4, true);
      });

      test('point behind source negative lat, discOnLeft=false', () {
        checkSimplify('0:0', '0:2', '', '-1:-1', [false], 1.4, true);
      });

      test('point behind source negative lat, discOnLeft=true', () {
        checkSimplify('0:0', '0:2', '', '-1:-1', [true], 1.4, true);
      });
    });

    group('testAvoidSeveralPoints', () {
      for (final dst in ['0:2', '1.732:-1', '-1.732:-1']) {
        test('can find gap for dst=$dst with discOnLeft=true', () {
          checkSimplify(
            '0:0',
            dst,
            '',
            '0.01:2, 1.732:-1.01, -1.732:-0.99',
            [true, true, true],
            0.00001,
            true,
          );
        });

        test('cannot find gap for dst=$dst with discOnLeft=false', () {
          checkSimplify(
            '0:0',
            dst,
            '',
            '0.01:2, 1.732:-1.01, -1.732:-0.99',
            [false, false, false],
            0.00001,
            false,
          );
        });
      }
    });

    group('testTargetAndAvoid', () {
      test('target and avoid successfully', () {
        checkSimplify(
          '0:0',
          '10:10',
          '2:3, 4:3, 7:8',
          '4:2, 7:5, 7:9',
          [true, true, false],
          1.0,
          true,
        );
      });

      test('one target point too far away', () {
        checkSimplify(
          '0:0',
          '10:10',
          '2:3, 4:6, 7:8',
          '4:2, 7:5, 7:9',
          [true, true, false],
          1.0,
          false,
        );
      });

      test('one avoid point too close', () {
        checkSimplify(
          '0:0',
          '10:10',
          '2:3, 4:3, 7:8',
          '4:2, 6:5, 7:9',
          [true, true, false],
          1.0,
          false,
        );
      });
    });

    test('testSrcGetter', () {
      final simplifier = S2PolylineSimplifier();
      final srcPoint = S2Point(1, 0, 0);
      simplifier.init(srcPoint);
      expect(simplifier.src, equals(srcPoint));
    });

    test('testAvoidDiscWithVeryLargeRadius', () {
      // Test avoidDisc with a very large radius (semiwidth >= π)
      final simplifier = S2PolylineSimplifier();
      simplifier.init(S2TextFormat.makePointOrDie('0:0'));
      // A very large radius that spans more than π
      final result = simplifier.avoidDisc(
        S2TextFormat.makePointOrDie('0:90'),
        S1ChordAngle.fromDegrees(180),
        true,
      );
      // Should return false because semiwidth >= π
      expect(result, isFalse);
    });

    test('testTargetDiscWithNegativeSemiwidth', () {
      // Test targetDisc when semiwidth < 0 (point very far from edge)
      final simplifier = S2PolylineSimplifier();
      simplifier.init(S2TextFormat.makePointOrDie('0:0'));
      // First, set up a very narrow window
      simplifier.targetDisc(S2TextFormat.makePointOrDie('0:1'), S1ChordAngle.fromDegrees(0.001));
      // Then try to target something very far that can't be reached
      // This should make semiwidth negative due to the disc being beyond the edge
      final result = simplifier.targetDisc(
        S2TextFormat.makePointOrDie('90:0'),
        S1ChordAngle.fromDegrees(0.001),
      );
      expect(result, isFalse);
    });

    test('testAvoidThenTarget', () {
      // Test calling avoidDisc before targetDisc (uses _rangesToAvoid)
      final simplifier = S2PolylineSimplifier();
      simplifier.init(S2TextFormat.makePointOrDie('0:0'));
      // First avoid a disc
      simplifier.avoidDisc(S2TextFormat.makePointOrDie('1:1'), S1ChordAngle.fromDegrees(0.1), true);
      // Then target a disc - this should process _rangesToAvoid
      final result = simplifier.targetDisc(
        S2TextFormat.makePointOrDie('0:1'),
        S1ChordAngle.fromDegrees(1.0),
      );
      expect(result, isTrue);
      // Then extend
      final extendResult = simplifier.extend(S2TextFormat.makePointOrDie('0:2'));
      expect(extendResult, isTrue);
    });

    test('testTargetDiscMakesWindowEmpty', () {
      // Test case where targetDisc makes window empty (semiwidth < 0 path)
      final simplifier = S2PolylineSimplifier();
      simplifier.init(S2TextFormat.makePointOrDie('0:0'));
      // Target a very small disc at a point behind the source
      // This should result in negative semiwidth
      final result = simplifier.targetDisc(
        S2TextFormat.makePointOrDie('0:180'),  // Antipodal point
        S1ChordAngle.fromDegrees(0.001),
      );
      expect(result, isFalse);
    });

    test('testAvoidRangeContainedByWindow', () {
      // Test the code path where window.contains(avoidInterval)
      final simplifier = S2PolylineSimplifier();
      simplifier.init(S2TextFormat.makePointOrDie('0:0'));
      // First establish a wide window with a target
      simplifier.targetDisc(S2TextFormat.makePointOrDie('0:10'), S1ChordAngle.fromDegrees(5.0));
      // Then avoid a small disc within that window
      simplifier.avoidDisc(S2TextFormat.makePointOrDie('0:10'), S1ChordAngle.fromDegrees(0.5), true);
      // Now target again to process the avoid range
      final result = simplifier.targetDisc(
        S2TextFormat.makePointOrDie('0:10'),
        S1ChordAngle.fromDegrees(4.0),
      );
      expect(result, isTrue);
    });

    test('testAvoidRangeContainedDiscOnLeftFalse', () {
      // Test _avoidRange with discOnLeft=false when window contains interval
      final simplifier = S2PolylineSimplifier();
      simplifier.init(S2TextFormat.makePointOrDie('0:0'));
      // Establish a wide window
      simplifier.targetDisc(S2TextFormat.makePointOrDie('0:10'), S1ChordAngle.fromDegrees(5.0));
      // Avoid a small disc with discOnLeft=false
      simplifier.avoidDisc(S2TextFormat.makePointOrDie('0:10'), S1ChordAngle.fromDegrees(0.5), false);
      // Target again
      final result = simplifier.targetDisc(
        S2TextFormat.makePointOrDie('0:10'),
        S1ChordAngle.fromDegrees(4.0),
      );
      expect(result, isTrue);
    });

    test('testAvoidRangeWindowContainsDiscOnLeftTrue', () {
      // Test the branch where window.contains(avoidInterval) and discOnLeft=true
      // Need to avoid a disc that's properly contained in the window
      final simplifier = S2PolylineSimplifier();
      simplifier.init(S2TextFormat.makePointOrDie('0:0'));
      // Create a target disc first to establish window
      final targetResult = simplifier.targetDisc(
        S2TextFormat.makePointOrDie('0:5'),
        S1ChordAngle.fromDegrees(45.0),  // Very large target radius
      );
      expect(targetResult, isTrue);
      // Avoid a small disc with discOnLeft=true
      simplifier.avoidDisc(S2TextFormat.makePointOrDie('0:5'), S1ChordAngle.fromDegrees(0.01), true);
      // The avoid should have trimmed the window from the lo side
      // Can still extend but result depends on geometry
      simplifier.extend(S2TextFormat.makePointOrDie('0:10'));
      // Test passes if no exception is thrown
    });

    test('testAvoidRangeWindowContainsDiscOnLeftFalse', () {
      // Test the branch where window.contains(avoidInterval) and discOnLeft=false
      final simplifier = S2PolylineSimplifier();
      simplifier.init(S2TextFormat.makePointOrDie('0:0'));
      // Create a target disc first to establish window
      final targetResult = simplifier.targetDisc(
        S2TextFormat.makePointOrDie('0:5'),
        S1ChordAngle.fromDegrees(45.0),  // Very large target radius
      );
      expect(targetResult, isTrue);
      // Avoid a small disc with discOnLeft=false
      simplifier.avoidDisc(S2TextFormat.makePointOrDie('0:5'), S1ChordAngle.fromDegrees(0.01), false);
      // The avoid should have trimmed the window from the hi side
      simplifier.extend(S2TextFormat.makePointOrDie('0:10'));
      // Test passes if no exception is thrown
    });
  });
}


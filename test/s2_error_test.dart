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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2Error', () {
    test('testDefaultState', () {
      final error = S2Error();
      expect(error.code, equals(S2ErrorCode.noError));
      expect(error.text, equals(''));
      expect(error.ok, isTrue);
      expect(error.toString(), equals('OK'));
    });

    test('testInitWithNoArgs', () {
      final error = S2Error();
      error.init(S2ErrorCode.invalidArgument, 'Something went wrong');
      expect(error.code, equals(S2ErrorCode.invalidArgument));
      expect(error.text, equals('Something went wrong'));
      expect(error.ok, isFalse);
    });

    test('testInitWithArgs', () {
      final error = S2Error();
      error.init(S2ErrorCode.outOfRange, 'Value %s is out of range [%s, %s]', ['42', '0', '10']);
      expect(error.code, equals(S2ErrorCode.outOfRange));
      expect(error.text, equals('Value 42 is out of range [0, 10]'));
    });

    test('testInitWithDFormat', () {
      final error = S2Error();
      error.init(S2ErrorCode.outOfRange, 'Index %d exceeds max %d', [5, 3]);
      expect(error.text, equals('Index 5 exceeds max 3'));
    });

    test('testInitWithMissingArgs', () {
      final error = S2Error();
      error.init(S2ErrorCode.unknown, 'Missing: %s and %s', ['first']);
      expect(error.text, equals('Missing: first and [missing argument]'));
    });

    test('testClear', () {
      final error = S2Error();
      error.init(S2ErrorCode.internal, 'Bad state');
      expect(error.ok, isFalse);
      
      error.clear();
      expect(error.code, equals(S2ErrorCode.noError));
      expect(error.text, equals(''));
      expect(error.ok, isTrue);
    });

    test('testToStringWithError', () {
      final error = S2Error();
      error.init(S2ErrorCode.duplicateVertices, 'Found duplicate at index 5');
      expect(error.toString(), contains('duplicateVertices'));
      expect(error.toString(), contains('Found duplicate at index 5'));
    });
  });

  group('S2ErrorCode', () {
    test('testNoErrorCode', () {
      expect(S2ErrorCode.noError.code, equals(0));
    });

    test('testGenericErrorCodes', () {
      expect(S2ErrorCode.unknown.code, equals(1000));
      expect(S2ErrorCode.unimplemented.code, equals(1001));
      expect(S2ErrorCode.outOfRange.code, equals(1002));
      expect(S2ErrorCode.invalidArgument.code, equals(1003));
      expect(S2ErrorCode.failedPrecondition.code, equals(1004));
      expect(S2ErrorCode.internal.code, equals(1005));
      expect(S2ErrorCode.dataLoss.code, equals(1006));
      expect(S2ErrorCode.resourceExhausted.code, equals(1007));
      expect(S2ErrorCode.cancelled.code, equals(1008));
    });

    test('testGeometryErrorCodes', () {
      expect(S2ErrorCode.notUnitLength.code, equals(1));
      expect(S2ErrorCode.duplicateVertices.code, equals(2));
      expect(S2ErrorCode.antipodalVertices.code, equals(3));
      expect(S2ErrorCode.notContinuous.code, equals(4));
      expect(S2ErrorCode.invalidVertex.code, equals(5));
    });

    test('testLoopErrorCodes', () {
      expect(S2ErrorCode.loopNotEnoughVertices.code, equals(100));
      expect(S2ErrorCode.loopSelfIntersection.code, equals(101));
    });

    test('testPolygonErrorCodes', () {
      expect(S2ErrorCode.polygonLoopsShareEdge.code, equals(200));
      expect(S2ErrorCode.polygonLoopsCross.code, equals(201));
      expect(S2ErrorCode.polygonEmptyLoop.code, equals(202));
      expect(S2ErrorCode.polygonExcessFullLoop.code, equals(203));
      expect(S2ErrorCode.polygonInconsistentLoopOrientations.code, equals(204));
      expect(S2ErrorCode.polygonInvalidLoopDepth.code, equals(205));
      expect(S2ErrorCode.polygonInvalidLoopNesting.code, equals(206));
      expect(S2ErrorCode.invalidDimension.code, equals(207));
      expect(S2ErrorCode.splitInterior.code, equals(208));
      expect(S2ErrorCode.overlappingGeometry.code, equals(209));
    });

    test('testBuilderErrorCodes', () {
      expect(S2ErrorCode.builderSnapRadiusTooSmall.code, equals(300));
      expect(S2ErrorCode.builderMissingExpectedSiblingEdges.code, equals(301));
      expect(S2ErrorCode.builderUnexpectedDegenerateEdge.code, equals(302));
      expect(S2ErrorCode.builderEdgesDoNotFormLoops.code, equals(303));
      expect(S2ErrorCode.builderEdgesDoNotFormPolyline.code, equals(304));
      expect(S2ErrorCode.builderIsFullPredicateNotSpecified.code, equals(305));
    });

    test('testUserDefinedErrorCodes', () {
      expect(S2ErrorCode.userDefinedStart.code, equals(1000000));
      expect(S2ErrorCode.userDefinedEnd.code, equals(9999999));
    });
  });
}


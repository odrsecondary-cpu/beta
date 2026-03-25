import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:beta/main.dart';

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

Position _fakePosition() => Position(
      latitude: 37.4219983,
      longitude: -122.084,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );

void main() {
  late MockGeolocatorPlatform mockGeolocator;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
  });

  testWidgets('should show loading indicator while fetching location',
      (tester) async {
    // Never completes during the test — keeps the screen in loading state.
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) => Future.value(LocationPermission.always));
    when(() => mockGeolocator.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        )).thenAnswer((_) => Completer<Position>().future);

    await tester.pumpWidget(const MyApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('should show zoom in and zoom out buttons after location loads',
      (tester) async {
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => LocationPermission.always);
    when(() => mockGeolocator.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        )).thenAnswer((_) async => _fakePosition());

    await tester.pumpWidget(const MyApp());
    // Resolve the location future and trigger one rebuild.
    await tester.pump();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  testWidgets('should show error message and retry button when permission denied',
      (tester) async {
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => LocationPermission.denied);
    when(() => mockGeolocator.requestPermission())
        .thenAnswer((_) async => LocationPermission.denied);

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Location permission denied.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

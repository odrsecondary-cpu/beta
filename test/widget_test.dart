import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
    // Never emits during the test — keeps the screen in loading state.
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) => Future.value(LocationPermission.always));
    when(() => mockGeolocator.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        )).thenAnswer((_) => StreamController<Position>().stream);

    await tester.pumpWidget(const MyApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('should show zoom in and zoom out buttons after location loads',
      (tester) async {
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => LocationPermission.always);
    when(() => mockGeolocator.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        )).thenAnswer((_) => Stream.value(_fakePosition()));

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

  testWidgets('should show center pin button after location loads',
      (tester) async {
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => LocationPermission.always);
    when(() => mockGeolocator.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        )).thenAnswer((_) => Stream.value(_fakePosition()));

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byIcon(Icons.my_location), findsOneWidget);
  });

  testWidgets('should center map on pin location when center button is tapped',
      (tester) async {
    final mapController = MapController();
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => LocationPermission.always);
    when(() => mockGeolocator.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        )).thenAnswer((_) => Stream.value(_fakePosition()));

    await tester.pumpWidget(
      MaterialApp(home: MapScreen(mapController: mapController)),
    );
    await tester.pump();

    // Pan away from the pin.
    mapController.move(const LatLng(0, 0), mapController.camera.zoom);

    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();

    expect(mapController.camera.center.latitude, closeTo(37.4219983, 0.0001));
    expect(mapController.camera.center.longitude, closeTo(-122.084, 0.0001));
  });

  group('zoom animation', () {
    void mockLocationGranted() {
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);
      when(() => mockGeolocator.getPositionStream(
            locationSettings: any(named: 'locationSettings'),
          )).thenAnswer((_) => Stream.value(_fakePosition()));
    }

    testWidgets('should complete zoom in to initial zoom plus one',
        (tester) async {
      final mapController = MapController();
      mockLocationGranted();

      await tester.pumpWidget(
        MaterialApp(home: MapScreen(mapController: mapController)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(mapController.camera.zoom, equals(16.0));
    });

    testWidgets('should complete zoom out to initial zoom minus one',
        (tester) async {
      final mapController = MapController();
      mockLocationGranted();

      await tester.pumpWidget(
        MaterialApp(home: MapScreen(mapController: mapController)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      expect(mapController.camera.zoom, equals(14.0));
    });

    testWidgets('should not reach final zoom instantly when zooming in',
        (tester) async {
      final mapController = MapController();
      mockLocationGranted();

      await tester.pumpWidget(
        MaterialApp(home: MapScreen(mapController: mapController)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump(); // register first animation tick at t=0
      await tester.pump(const Duration(milliseconds: 150)); // advance to halfway through animation

      expect(mapController.camera.zoom, greaterThan(15.0));
      expect(mapController.camera.zoom, lessThan(16.0));
    });
  });
}

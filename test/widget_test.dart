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

  testWidgets('should draw route polyline after multiple location updates',
      (tester) async {
    final controller = StreamController<Position>();
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => LocationPermission.always);
    when(() => mockGeolocator.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        )).thenAnswer((_) => controller.stream);

    await tester.pumpWidget(const MyApp());

    controller.add(_fakePosition());
    await tester.pump();

    controller.add(Position(
      latitude: 37.4229983,
      longitude: -122.084,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    ));
    await tester.pump();

    expect(find.byType(PolylineLayer), findsOneWidget);

    await tester.pumpAndSettle();
    await controller.close();
  });

  group('location animation', () {
    testWidgets('should animate marker position when location updates',
        (tester) async {
      final controller = StreamController<Position>();
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);
      when(() => mockGeolocator.getPositionStream(
            locationSettings: any(named: 'locationSettings'),
          )).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(const MyApp());

      controller.add(_fakePosition());
      await tester.pump();

      // Emit a second position further north.
      controller.add(Position(
        latitude: 37.4229983,
        longitude: -122.084,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ));
      await tester.pump();
      // Mid-animation: marker should not have jumped to the final position yet.
      await tester.pump(const Duration(milliseconds: 400));

      final marker = tester.widget<Container>(
        find.descendant(
          of: find.byType(MarkerLayer),
          matching: find.byType(Container),
        ),
      );
      expect(marker, isNotNull);

      // Let the animation finish and verify no errors.
      await tester.pumpAndSettle();
      await controller.close();
    });
  });

  group('activity recording', () {
    void mockLocationGranted(Stream<Position> stream) {
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);
      when(() => mockGeolocator.getPositionStream(
            locationSettings: any(named: 'locationSettings'),
          )).thenAnswer((_) => stream);
    }

    testWidgets('should show record button after location loads',
        (tester) async {
      mockLocationGranted(Stream.value(_fakePosition()));

      await tester.pumpWidget(const MyApp());
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('should show REC indicator and stop button when recording starts',
        (tester) async {
      mockLocationGranted(Stream.value(_fakePosition()));

      await tester.pumpWidget(const MyApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.textContaining('REC'), findsOneWidget);
    });

    testWidgets('should show result card after stopping recording',
        (tester) async {
      final controller = StreamController<Position>();
      mockLocationGranted(controller.stream);

      await tester.pumpWidget(const MyApp());

      controller.add(_fakePosition());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(find.text('Activity Complete'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      await tester.pumpAndSettle();
      await controller.close();
    });

    testWidgets('should accumulate non-zero distance during recording',
        (tester) async {
      final controller = StreamController<Position>();
      mockLocationGranted(controller.stream);

      await tester.pumpWidget(const MyApp());

      controller.add(_fakePosition());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      controller.add(Position(
        latitude: 37.4229983,
        longitude: -122.084,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(find.text('0 m'), findsNothing);

      await tester.pumpAndSettle();
      await controller.close();
    });

    testWidgets('should start new activity when record button tapped after result',
        (tester) async {
      final controller = StreamController<Position>();
      mockLocationGranted(controller.stream);

      await tester.pumpWidget(const MyApp());

      controller.add(_fakePosition());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(find.text('Activity Complete'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(find.text('Activity Complete'), findsNothing);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.textContaining('REC'), findsOneWidget);

      await tester.pumpAndSettle();
      await controller.close();
    });

    testWidgets('should not accumulate distance before recording starts',
        (tester) async {
      final controller = StreamController<Position>();
      mockLocationGranted(controller.stream);

      await tester.pumpWidget(const MyApp());

      // Move around without starting recording
      controller.add(_fakePosition());
      await tester.pump();
      controller.add(Position(
        latitude: 37.4229983,
        longitude: -122.084,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ));
      await tester.pump();

      // Now start and immediately stop recording
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(find.text('0 m'), findsOneWidget);

      await tester.pumpAndSettle();
      await controller.close();
    });
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

import 'dart:async';

import 'package:delivery_app/models/live_location.dart';
import 'package:delivery_app/services/api_service.dart';
import 'package:delivery_app/services/location_reporter.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

LocationFix fix(double lat) => LocationFix(lat: lat, lng: 76.3, recordedAt: DateTime.utc(2026, 10, 27));

void main() {
  group('LocationReporter', () {
    test('sends the first fix at once, then at most once per nextSendSeconds with the newest fix', () {
      fakeAsync((async) {
        final sent = <double>[];
        final r = LocationReporter(send: (f) async {
          sent.add(f.lat);
          return const LocationPingResult(nextSendSeconds: 20);
        })..start();

        r.update(fix(1));
        async.flushMicrotasks();
        expect(sent, [1]);

        async.elapse(const Duration(seconds: 5));
        r.update(fix(2));
        r.update(fix(3));
        async.elapse(const Duration(seconds: 10));
        expect(sent, [1], reason: 'still inside the 20 s window');

        async.elapse(const Duration(seconds: 6));
        expect(sent, [1, 3], reason: 'newest fix goes out when the window opens');
      });
    });

    test('re-sends the last fix every 60 s while standing still', () {
      fakeAsync((async) {
        var count = 0;
        final r = LocationReporter(send: (f) async {
          count++;
          return const LocationPingResult(nextSendSeconds: 20);
        })..start();
        r.update(fix(1));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 59));
        expect(count, 1);
        async.elapse(const Duration(seconds: 2));
        expect(count, 2);
        async.elapse(const Duration(seconds: 60));
        expect(count, 3);
      });
    });

    test('never overlaps requests', () {
      fakeAsync((async) {
        var inFlight = 0;
        var maxInFlight = 0;
        final slow = Completer<LocationPingResult>();
        var calls = 0;
        final r = LocationReporter(send: (f) {
          calls++;
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          final done = calls == 1 ? slow.future : Future.value(const LocationPingResult(nextSendSeconds: 10));
          return done.whenComplete(() => inFlight--);
        })..start();

        r.update(fix(1));
        for (var i = 0; i < 10; i++) {
          async.elapse(const Duration(seconds: 15));
          r.update(fix(2.0 + i));
        }
        expect(calls, 1, reason: 'first request still out');
        slow.complete(const LocationPingResult(nextSendSeconds: 10));
        async.elapse(const Duration(seconds: 11));
        expect(calls, 2);
        expect(maxInFlight, 1);
      });
    });

    test('backs off 1.5x on errors, capped at 2 minutes', () {
      fakeAsync((async) {
        final at = <Duration>[];
        final r = LocationReporter(send: (f) async {
          at.add(async.elapsed);
          throw const ApiException('down', statusCode: 503);
        })..start();
        r.update(fix(1));
        async.elapse(const Duration(minutes: 8));
        final gaps = [for (var i = 1; i < at.length; i++) (at[i] - at[i - 1]).inSeconds];
        expect(gaps.take(4).toList(), [20, 30, 45, 67]);
        expect(gaps.every((g) => g <= 120), isTrue);
        expect(gaps.last, 120);
      });
    });

    test('a missing endpoint (404) waits 5 minutes', () {
      fakeAsync((async) {
        var calls = 0;
        final r = LocationReporter(send: (f) async {
          calls++;
          throw const ApiException('not found', statusCode: 404);
        })..start();
        r.update(fix(1));
        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(calls, 1);
        async.elapse(const Duration(seconds: 2));
        expect(calls, 2);
      });
    });

    test('stop cancels everything and ignores late replies', () {
      fakeAsync((async) {
        var calls = 0;
        final results = <LocationPingResult>[];
        final r = LocationReporter(
          send: (f) async {
            calls++;
            await Future<void>.delayed(const Duration(seconds: 2));
            return const LocationPingResult(nextSendSeconds: 20);
          },
          onResult: results.add,
        )..start();
        r.update(fix(1));
        async.elapse(const Duration(seconds: 1));
        r.stop();
        async.elapse(const Duration(minutes: 5));
        r.update(fix(2)); // ignored while stopped
        async.flushMicrotasks();
        expect(calls, 1);
        expect(results, isEmpty);
      });
    });
  });

  group('LiveEta', () {
    test('formats the next-stop line', () {
      final eta = LiveEta.fromJson({
        'deliveryId': 'd1',
        'nextStop': 'store',
        'nextStopName': 'Fresh Mart',
        'etaMinutes': 12,
        'distanceKm': 3.44,
      })!;
      expect(eta.label, 'Next: Fresh Mart · about 12 min · 3.4 km');
      final customer = LiveEta.fromJson({'deliveryId': 'd2', 'nextStop': 'customer', 'distanceKm': 0.4})!;
      expect(customer.label, 'Next: Customer · 400 m');
    });

    test('parses the location response', () {
      final r = LocationPingResult.fromJson({
        'status': 'success',
        'data': {
          'throttled': true,
          'nextSendSeconds': 20,
          'active': [
            {'deliveryId': 'd1', 'nextStop': 'customer', 'etaMinutes': 4.6, 'distanceKm': 1.2},
            {'nope': true},
          ],
        },
      });
      expect(r.throttled, isTrue);
      expect(r.nextSendSeconds, 20);
      expect(r.active.single.etaMinutes, 5);
    });
  });
}

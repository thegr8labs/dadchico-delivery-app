import 'dart:async';

import '../models/live_location.dart';
import 'api_service.dart';

typedef LocationSendFn = Future<LocationPingResult> Function(LocationFix fix);

/// Decides when GPS fixes are posted to the server. Timers only, no clock reads.
///
/// - The first fix goes out straight away.
/// - After that at most one post per server-chosen interval (`nextSendSeconds`, default 20 s);
///   fixes arriving in between just replace the one waiting to be sent.
/// - The latest fix is re-sent at least every 60 s, so a driver standing still stays "live".
/// - Never two requests at once; errors back off 1.5x up to 2 min (5 min while the endpoint
///   doesn't exist yet on the server).
class LocationReporter {
  LocationReporter({required this.send, this.onResult, this.onError});

  static const Duration defaultInterval = Duration(seconds: 20);
  static const Duration minInterval = Duration(seconds: 10);
  static const Duration heartbeat = Duration(seconds: 60);
  static const Duration maxBackoff = Duration(seconds: 120);
  static const Duration missingEndpointBackoff = Duration(minutes: 5);

  final LocationSendFn send;
  final void Function(LocationPingResult result)? onResult;
  final void Function(Object error)? onError;

  LocationFix? _latest;
  bool _pending = false;
  bool _inFlight = false;
  bool _running = false;
  int _generation = 0;
  Timer? _gate;
  Timer? _heartbeat;
  Duration? _backoff;

  bool get isRunning => _running;
  bool get inFlight => _inFlight;

  void start() {
    if (_running) return;
    _running = true;
    _generation++;
  }

  void stop() {
    _running = false;
    _generation++;
    _gate?.cancel();
    _heartbeat?.cancel();
    _latest = null;
    _pending = false;
    _backoff = null;
  }

  /// A new GPS fix from the stream.
  void update(LocationFix fix) {
    if (!_running) return;
    _latest = fix;
    _pending = true;
    _trySend();
  }

  void _trySend() {
    if (!_running || _inFlight || _latest == null || (_gate?.isActive ?? false)) return;
    _doSend();
  }

  Future<void> _doSend() async {
    final gen = _generation;
    final fix = _latest!;
    _inFlight = true;
    _pending = false;
    _heartbeat?.cancel();
    Duration? wait;
    try {
      final result = await send(fix);
      if (gen == _generation) {
        _backoff = null;
        final secs = result.nextSendSeconds;
        wait = secs == null ? defaultInterval : _clamp(Duration(seconds: secs));
        onResult?.call(result);
      }
    } catch (e) {
      if (gen == _generation) {
        _pending = true; // retry with the newest fix
        final previous = _backoff;
        _backoff = e is ApiException && e.statusCode == 404
            ? missingEndpointBackoff
            : previous == null
                ? defaultInterval
                : _min(previous * 1.5, maxBackoff);
        wait = _backoff;
        onError?.call(e);
      }
    } finally {
      _inFlight = false;
    }
    if (!_running) return;
    if (gen != _generation || wait == null) {
      // Restarted while this request was out; carry on with the new session.
      if (_pending) _trySend();
      return;
    }
    _gate = Timer(wait, () {
      if (_pending) _trySend();
    });
    _heartbeat = Timer(wait > heartbeat ? wait : heartbeat, () {
      _pending = true;
      _trySend();
    });
  }

  static Duration _clamp(Duration d) => d < minInterval ? minInterval : _min(d, maxBackoff);
  static Duration _min(Duration a, Duration b) => a < b ? a : b;
}

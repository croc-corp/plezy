import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';

import '../../../models/audio_channel_limit.dart';
import '../../../utils/app_logger.dart';
import '../../models.dart';
import '../player.dart';

@JS('plezyWebCreate')
external JSObject _create(JSFunction callback, JSBoolean audioOnly);
@JS('plezyWebAttach')
external void _attach(JSObject bridge, JSObject element);
@JS('plezyWebOpen')
external void _open(JSObject bridge, JSString url, JSBoolean play, JSNumber start);
@JS('plezyWebPlay')
external void _play(JSObject bridge);
@JS('plezyWebPause')
external void _pause(JSObject bridge);
@JS('plezyWebStop')
external void _stop(JSObject bridge);
@JS('plezyWebSeek')
external void _seek(JSObject bridge, JSNumber seconds);
@JS('plezyWebVolume')
external void _volume(JSObject bridge, JSNumber volume);
@JS('plezyWebRate')
external void _rate(JSObject bridge, JSNumber rate);
@JS('plezyWebSubtitle')
external void _subtitle(JSObject bridge, JSString url);
@JS('plezyWebDispose')
external void _dispose(JSObject bridge);

class _SilentMethodChannel extends MethodChannel {
  const _SilentMethodChannel() : super('com.plezy/web_player');

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async => null;
}

class _SilentEventChannel extends EventChannel {
  const _SilentEventChannel() : super('com.plezy/web_player/events');

  @override
  Stream<dynamic> receiveBroadcastStream([dynamic arguments]) => const Stream<dynamic>.empty();
}

/// HTML video plus hls.js, adapting browser media events to Plezy's player
/// state contract. The DOM element is attached by [Video] after the route lays
/// out; an early open waits in the JavaScript bridge until then.
class PlayerWeb extends PlayerBase {
  PlayerWeb({this.audioOnly = false}) {
    _bridge = _create(_callback, audioOnly.toJS);
  }

  final bool audioOnly;
  late final JSObject _bridge;
  late final JSFunction _callback = ((JSString event, JSNumber value, JSString? message) {
    _onMediaEvent(event.toDart, value.toDartDouble, message?.toDart);
  }).toJS;
  final Map<String, String> _properties = {};
  int _sourceId = 0;

  @override
  final MethodChannel methodChannel = const _SilentMethodChannel();
  @override
  final EventChannel eventChannel = const _SilentEventChannel();
  @override
  String get logPrefix => 'Web';
  @override
  String get playerType => 'html5';
  @override
  bool get supportsSecondarySubtitles => false;

  void attach(JSObject element) => _attach(_bridge, element);

  void _onMediaEvent(String event, double value, String? message) {
    if (disposed) return;
    switch (event) {
      case 'loaded':
        handlePropertyChange('duration', value);
        handlePropertyChange('seekable', true);
        handlePlayerEvent('file-loaded', {'sourceId': _sourceId});
        primaryMediaReadyController.add(null);
      case 'frame':
        handlePlayerEvent('playback-restart', {'sourceId': _sourceId, 'positionSeconds': value});
      case 'playing':
        handlePropertyChange('pause', false);
        handlePropertyChange('paused-for-cache', false);
      case 'paused':
        handlePropertyChange('pause', true);
      case 'buffering':
        handlePropertyChange('paused-for-cache', true);
      case 'canplay':
        handlePropertyChange('paused-for-cache', false);
      case 'position':
        handlePropertyChange('time-pos', value, sourceId: _sourceId);
      case 'duration':
        handlePropertyChange('duration', value);
      case 'buffer':
        handlePropertyChange('demuxer-cache-time', value);
      case 'ended':
        handlePropertyChange('pause', true);
        handlePlayerEvent('end-file', {'sourceId': _sourceId, 'reason': 'eof'});
      case 'error':
        handlePropertyChange('pause', true);
        handlePlayerEvent('end-file', {
          'sourceId': _sourceId,
          'reason': 'error',
          'message': message ?? 'Browser could not play this stream',
        });
      case 'subtitle-error':
        appLogger.w('Browser subtitle could not load', error: message);
    }
  }

  @override
  Future<void> open(
    Media media, {
    bool play = true,
    bool isLive = false,
    List<SubtitleTrack>? externalSubtitles,
    Duration? timelineDuration,
  }) async {
    if (disposed) return;
    // HTML video and hls.js cannot add arbitrary request headers. Plex URLs
    // carry X-Plex-Token in the query, and Jellyfin URLs carry api_key.
    // Refuse an authenticated source without URL credentials rather than
    // silently playing an unauthenticated request.
    if (media.headers?.isNotEmpty == true &&
        !Uri.parse(
          media.uri,
        ).queryParameters.keys.any((key) => key.toLowerCase() == 'x-plex-token' || key.toLowerCase() == 'api_key')) {
      throw UnsupportedError('This stream requires HTTP headers that a browser video element cannot send');
    }
    _sourceId++;
    clearTracks();
    setExternalSubtitleMetadata(externalSubtitles);
    configureTimeline(duration: timelineDuration);
    handlePlayerEvent('start-file', {'sourceId': _sourceId});
    _open(_bridge, media.uri.toJS, play.toJS, ((media.start?.inMilliseconds ?? 0) / 1000).toJS);
    // The browser has no mpv track-list event. Publish sidecars through the
    // shared parser so source-track matching and automatic selection can use
    // the same track IDs and metadata as native playback.
    final subtitles = externalSubtitles ?? const <SubtitleTrack>[];
    handlePropertyChange('track-list', [
      for (var i = 0; i < subtitles.length; i++)
        if (subtitles[i].uri case final String url when url.isNotEmpty)
          {
            'type': 'sub',
            'id': i + 1,
            'external': true,
            'external-filename': url,
            'title': subtitles[i].title,
            'lang': subtitles[i].language,
            'codec': subtitles[i].codec,
            'default': subtitles[i].isDefault,
            'forced': subtitles[i].isForced,
          },
    ]);
  }

  @override
  Future<void> play() async => _play(_bridge);
  @override
  Future<void> pause() async => _pause(_bridge);
  @override
  Future<void> stop() async {
    _stop(_bridge);
    handlePropertyChange('pause', true);
    handlePlayerEvent('end-file', {'sourceId': _sourceId, 'reason': 'stop'});
  }

  @override
  Future<void> seek(Duration position) => runSeek(position, () async {
    _seek(_bridge, (position.inMilliseconds / 1000).toJS);
  });

  @override
  Future<void> selectAudioTrack(AudioTrack track) async {}

  @override
  Future<void> selectSubtitleTrack(SubtitleTrack track) async {
    _subtitle(_bridge, (track.uri ?? '').toJS);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume(_bridge, (volume.clamp(0, 100) / 100).toJS);
    setVolumeState(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    _rate(_bridge, rate.toJS);
    setRateState(rate);
  }

  @override
  Future<void> setProperty(String name, String value) async {
    _properties[name] = value;
    switch (name) {
      case 'pause':
        if (value == 'yes') {
          await pause();
        } else {
          await play();
        }
      case 'volume':
        final parsed = double.tryParse(value);
        if (parsed != null) await setVolume(parsed);
      case 'speed':
        final parsed = double.tryParse(value);
        if (parsed != null) await setRate(parsed);
      case 'time-pos':
        final parsed = double.tryParse(value);
        if (parsed != null) await seek(Duration(milliseconds: (parsed * 1000).round()));
    }
  }

  @override
  Future<String?> getProperty(String name) async => switch (name) {
    'pause' => state.playing ? 'no' : 'yes',
    'time-pos' => (currentPosition.inMilliseconds / 1000).toString(),
    'duration' => (state.duration.inMilliseconds / 1000).toString(),
    'volume' => state.volume.toString(),
    'speed' => state.rate.toString(),
    _ => _properties[name],
  };

  @override
  Future<void> command(List<String> args) async {
    if (args.isEmpty) return;
    switch (args.first) {
      case 'seek':
        final seconds = args.length > 1 ? double.tryParse(args[1]) : null;
        if (seconds != null) await seek(Duration(milliseconds: (seconds * 1000).round()));
      case 'stop':
        await stop();
      case 'cycle':
        if (args.length > 1 && args[1] == 'pause') await playOrPause();
    }
  }

  @override
  Future<void> configureSubtitleFonts() async {}
  @override
  Future<void> setAudioNormalization(bool enabled) async {}
  @override
  Future<void> setAudioChannelLimit(
    AudioChannelLimit limit, {
    required int centerBoostDb,
    required bool normalize,
  }) async {}
  @override
  Future<bool> setVisible(bool visible, {bool restoreOnWindowVisible = false}) async => true;

  @override
  Future<void> dispose({bool preserveDisplayMode = false}) async {
    if (disposed) return;
    _dispose(_bridge);
    await super.dispose(preserveDisplayMode: preserveDisplayMode);
  }
}

Player createWebPlayer({bool audioOnly = false}) => PlayerWeb(audioOnly: audioOnly);

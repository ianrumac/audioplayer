import 'dart:async';

import 'package:flutter/services.dart';

/// Communicates the current state of the audio player.
enum AudioPlayerState {
  /// Player is stopped. No file is loaded to the player. Calling [resume] or
  /// [pause] will result in exception.
  STOPPED,

  /// Currently playing a file. The user can [pause], [resume] or [stop] the
  /// playback.
  PLAYING,
  LOADING,

  /// Paused. The user can [resume] the playback without providing the URL.
  PAUSED,

  /// The playback has been completed. This state is the same as [STOPPED],
  /// however we differentiate it because some clients might want to know when
  /// the playback is done versus when the user has stopped the playback.
  COMPLETED,
}

enum AudioPlayerControlState {
  MUTE,
  nextTrackCommand,
  previousTrackCommand,
  playCommand,
  pauseCommand,
  togglePlayPauseCommand,
}

const MethodChannel _channel = const MethodChannel('bz.rxla.flutter/audio');

/// A plugin for controlling the on device audio player.
///
/// Due to the async nature of the native APIs, this plugin delegates all control
/// methods to native without informing the caller of the state changes that happen
/// as a result of these calls. The state changes are communicated via the
/// [onPlayerStateChanged] stream instead so clients are expected to subscribe
/// to this.
class AudioPlayer {
  final StreamController<AudioPlayerState> _playerStateController =
  new StreamController.broadcast();

  final StreamController<AudioPlayerControlState> _playerControlController =
  new StreamController.broadcast();

  final StreamController<Duration> _positionController =
  new StreamController.broadcast();

  Stream<AudioPlayerControlState> get iosPlayerControlChanged =>
      _playerControlController.stream;

  AudioPlayerState _state = AudioPlayerState.STOPPED;
  Duration _duration = const Duration();

  AudioPlayer() {
    _channel.setMethodCallHandler(_audioPlayerStateChange);
  }

  /// Play a given url.
  ///
  ///
  Future<void> playAndroid(String url, {bool isLocal: false, int from: 0, double speed = 1.0}) async =>
      await _channel.invokeMethod('play', {
        'url': url,
        'from': from,
        'speed' : speed,
        'isLocal': isLocal,
      });

  Future<void> playIos(String url, String author, String sectionName,
      String bookName,
      {bool isLocal: false}) async =>
      await _channel.invokeMethod('play', {
        'url': url,
        'isLocal': isLocal,
        'sectionName': sectionName,
        'bookName': bookName,
        'author': author
      });

  /// Pause the currently playing stream.
  Future<void> pause() async => await _channel.invokeMethod('pause');

  /// Stop the currently playing stream.
  Future<void> stop() async => await _channel.invokeMethod('stop');

  Future<void> kill() async => await _channel.invokeMethod('kill');

  /// Changes audio playback speed
  Future<void> changeSpeed(double value) async =>
      await _channel.invokeMethod('changeSpeed', value);

  /// Mute sound.
  Future<void> mute(bool muted) async =>
      await _channel.invokeMethod('mute', muted);

  /// Seek to a specific position in the audio stream.
  Future<void> seek(double seconds) async =>
      await _channel.invokeMethod('seek', seconds);

  /// Stream for subscribing to player state change events.
  Stream<AudioPlayerState> get onPlayerStateChanged =>
      _playerStateController.stream;

  /// Reports what the player is currently doing.
  AudioPlayerState get state => _state;

  /// Reports the duration of the current media being played. It might return
  /// 0 if we have not determined the length of the media yet. It is best to
  /// call this from a state listener when the state has become
  /// [AudioPlayerState.PLAYING].
  Duration get duration => _duration;

  /// Stream for subscribing to audio position change events. Roughly fires
  /// every 200 milliseconds. Will continously update the position of the
  /// playback if the status is [AudioPlayerState.PLAYING].
  Stream<Duration> get onAudioPositionChanged => _positionController.stream;

  Stream<AudioPlayerControlState> get playerControlCenterChange =>
      _playerControlController.stream;

  Future<void> _audioPlayerStateChange(MethodCall call) async {
    switch (call.method) {
      case "audio.onCurrentPosition":
        assert(_state == AudioPlayerState.PLAYING);
        _positionController.add(new Duration(milliseconds: call.arguments));
        break;
      case "audio.onStart":
        _state = AudioPlayerState.PLAYING;
        _playerStateController.add(AudioPlayerState.PLAYING);
        _duration = new Duration(milliseconds: call.arguments);
        break;
      case "audio.onPause":
        _state = AudioPlayerState.PAUSED;
        _playerStateController.add(AudioPlayerState.PAUSED);
        break;
      case "audio.onLoading":
        _state = AudioPlayerState.LOADING;
        _playerStateController.add(AudioPlayerState.LOADING);
        break;
      case "audio.onStop":
        _state = AudioPlayerState.STOPPED;
        _playerStateController.add(AudioPlayerState.STOPPED);
        break;
      case "audio.onComplete":
        _state = AudioPlayerState.COMPLETED;
        _playerStateController.add(AudioPlayerState.COMPLETED);
        break;
      case "audio.onMute":
        _playerControlController.add(AudioPlayerControlState.MUTE);
        break;
      case "audio.nextTrackCommand":
        _playerControlController.add(AudioPlayerControlState.nextTrackCommand);
        break;
      case "audio.previousTrackCommand":
        _playerControlController
            .add(AudioPlayerControlState.previousTrackCommand);
        break;
      case "audio.playCommand":
        _playerControlController.add(AudioPlayerControlState.playCommand);
        break;
      case "audio.pauseCommand":
        _playerControlController.add(AudioPlayerControlState.pauseCommand);
        break;
      case "audio.togglePlayPauseCommand":
        _playerControlController
            .add(AudioPlayerControlState.togglePlayPauseCommand);
        break;
      case "audio.onError":
      // If there's an error, we assume the player has stopped.
        _state = AudioPlayerState.STOPPED;
        _playerStateController.addError(call.arguments);
        // TODO: Handle error arguments here. It is not useful to pass this
        // to the client since each platform creates different error string
        // formats so we can't expect client to parse these.
        break;
      default:
        throw new ArgumentError('Unknown method ${call.method} ');
    }
  }
}

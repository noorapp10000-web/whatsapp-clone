import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';
import 'firestore_service.dart';

enum CallState { idle, calling, ringing, active, ended }

typedef CallStateChanged = void Function(CallState state);

class CallService {
  static RTCPeerConnection? _peerConnection;
  static MediaStream? _localStream;
  static MediaStream? _remoteStream;
  static CallState _state = CallState.idle;
  static CallStateChanged? onStateChanged;
  static Function(MediaStream)? onLocalStream;
  static Function(MediaStream)? onRemoteStream;

  static final List<RTCIceCandidate> _iceQueue = [];
  static bool _remoteDescSet = false;
  static String? _currentCallId;

  static final Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
  };

  // Echo-cancellation + noise-suppression mandatory flags
  static Map<String, dynamic> _constraints(bool isVideo) => {
        'audio': {
          'mandatory': {
            'googEchoCancellation':      'true',
            'googEchoCancellation2':     'true',
            'googNoiseSuppression':      'true',
            'googNoiseSuppression2':     'true',
            'googAutoGainControl':       'true',
            'googAutoGainControl2':      'true',
            'googHighpassFilter':        'true',
            'googTypingNoiseDetection':  'true',
            'googAudioMirroring':        'false',
          },
          'optional': <Map>[],
        },
        'video': isVideo
            ? {'mandatory': {'minWidth': '640', 'minHeight': '480', 'minFrameRate': '15'},
               'facingMode': 'user', 'optional': <Map>[]}
            : false,
      };

  static Future<void> startCall({
    required String receiverUid,
    required bool isVideo,
    String? convId,
    String? callId,
  }) async {
    _state = CallState.calling;
    _currentCallId = callId;
    onStateChanged?.call(_state);

    await _setupPeer(receiverUid, isVideo: isVideo);
    // Use earpiece for voice calls — reduces echo significantly
    await Helper.setSpeakerphoneOn(isVideo);

    final offer = await _peerConnection!.createOffer(
        {'offerToReceiveAudio': true, 'offerToReceiveVideo': isVideo});
    await _peerConnection!.setLocalDescription(offer);
    WebSocketService.sendCallOffer(receiverUid, offer.toMap(), isVideo: isVideo);
  }

  static Future<void> acceptCall({
    required String callerUid,
    required Map<String, dynamic> offerSdp,
    required bool isVideo,
    String? callId,
  }) async {
    _state = CallState.active;
    _currentCallId = callId;
    onStateChanged?.call(_state);

    await _setupPeer(callerUid, isVideo: isVideo);
    await Helper.setSpeakerphoneOn(isVideo);

    await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerSdp['sdp'] as String, offerSdp['type'] as String));
    _remoteDescSet = true;
    for (final c in _iceQueue) await _peerConnection?.addCandidate(c);
    _iceQueue.clear();

    final answer = await _peerConnection!.createAnswer(
        {'offerToReceiveAudio': true, 'offerToReceiveVideo': isVideo});
    await _peerConnection!.setLocalDescription(answer);
    WebSocketService.sendCallAnswer(callerUid, answer.toMap());
  }

  static Future<void> handleCallAnswer(Map<String, dynamic> answerSdp) async {
    await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answerSdp['sdp'] as String, answerSdp['type'] as String));
    _remoteDescSet = true;
    for (final c in _iceQueue) await _peerConnection?.addCandidate(c);
    _iceQueue.clear();
  }

  static Future<void> addIceCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(
      data['candidate'] as String? ?? '',
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );
    if (_remoteDescSet && _peerConnection != null) {
      await _peerConnection!.addCandidate(candidate);
    } else {
      _iceQueue.add(candidate);
    }
  }

  static Future<void> endCall(String otherUid, String? callId) async {
    WebSocketService.sendCallEnd(otherUid);
    if (callId != null) await FirestoreService.updateCall(callId, 'ended');
    await _cleanup();
  }

  static Future<void> rejectCall(String callerUid, String? callId) async {
    WebSocketService.sendCallReject(callerUid);
    if (callId != null) await FirestoreService.updateCall(callId, 'rejected');
    await _cleanup();
  }

  static Future<void> startScreenShare(String otherUid) async {
    try {
      final stream = await navigator.mediaDevices
          .getDisplayMedia({'video': {'cursor': 'always'}, 'audio': false});
      final track = stream.getVideoTracks().firstOrNull;
      if (track == null) return;
      final senders = await _peerConnection!.senders;
      for (final s in senders) {
        if (s.track?.kind == 'video') await s.replaceTrack(track);
      }
      WebSocketService.sendScreenShareOffer(otherUid);
    } catch (_) {}
  }

  static void toggleMute() {
    final t = _localStream?.getAudioTracks().firstOrNull;
    if (t != null) t.enabled = !t.enabled;
  }

  static void toggleCamera() {
    final t = _localStream?.getVideoTracks().firstOrNull;
    if (t != null) t.enabled = !t.enabled;
  }

  static Future<void> switchCamera() async {
    final t = _localStream?.getVideoTracks().firstOrNull;
    if (t != null) await Helper.switchCamera(t);
  }

  static Future<void> setSpeaker(bool on) => Helper.setSpeakerphoneOn(on);

  static Future<void> _setupPeer(String otherUid, {required bool isVideo}) async {
    _remoteDescSet = false;
    _iceQueue.clear();
    _peerConnection = await createPeerConnection(_rtcConfig);
    _localStream = await navigator.mediaDevices.getUserMedia(_constraints(isVideo));
    onLocalStream?.call(_localStream!);
    for (final t in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(t, _localStream!);
    }
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        onRemoteStream?.call(_remoteStream!);
      }
    };
    _peerConnection!.onIceCandidate = (c) {
      if (c.candidate != null && c.candidate!.isNotEmpty) {
        WebSocketService.sendIceCandidate(otherUid, c.toMap());
      }
    };
    _peerConnection!.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _state = CallState.active;
        onStateChanged?.call(_state);
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _state = CallState.ended;
        onStateChanged?.call(_state);
      }
    };
  }

  static Future<void> _cleanup() async {
    _remoteDescSet = false;
    _iceQueue.clear();
    _localStream?.getTracks().forEach((t) => t.stop());
    _remoteStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _remoteStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _currentCallId = null;
    _state = CallState.idle;
    onStateChanged?.call(_state);
  }
}

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';
import 'api_service.dart';

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

  static final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  // ─── Start outgoing call ──────────────────────────────────────────────────
  static Future<void> startCall({
    required int receiverId,
    required bool isVideo,
    int? conversationId,
  }) async {
    _state = CallState.calling;
    onStateChanged?.call(_state);

    await ApiService.initiateCall(
      receiverId: receiverId,
      type: isVideo ? 'video' : 'voice',
      conversationId: conversationId,
    );

    await _setupPeerConnection(receiverId, isVideo: isVideo);
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    WebSocketService.sendCallOffer(receiverId, offer.toMap());
  }

  // ─── Accept incoming call ─────────────────────────────────────────────────
  static Future<void> acceptCall({
    required int callerId,
    required Map<String, dynamic> offerSdp,
    required bool isVideo,
  }) async {
    _state = CallState.active;
    onStateChanged?.call(_state);

    await _setupPeerConnection(callerId, isVideo: isVideo);
    final offer = RTCSessionDescription(offerSdp['sdp'], offerSdp['type']);
    await _peerConnection!.setRemoteDescription(offer);
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    WebSocketService.sendCallAnswer(callerId, answer.toMap());
  }

  // ─── End/reject call ──────────────────────────────────────────────────────
  static Future<void> endCall(int otherUserId, int? callId) async {
    WebSocketService.sendCallEnd(otherUserId);
    if (callId != null) await ApiService.updateCallStatus(callId, 'ended');
    await _cleanup();
  }

  static Future<void> rejectCall(int callerId, int? callId) async {
    WebSocketService.sendCallReject(callerId);
    if (callId != null) await ApiService.updateCallStatus(callId, 'rejected');
    await _cleanup();
  }

  // ─── Screen sharing ───────────────────────────────────────────────────────
  static Future<void> startScreenShare(int otherUserId) async {
    final stream = await navigator.mediaDevices.getDisplayMedia({
      'video': true,
      'audio': false,
    });
    final videoTrack = stream.getVideoTracks().first;
    final senders = await _peerConnection!.senders;
    for (final sender in senders) {
      if (sender.track?.kind == 'video') {
        await sender.replaceTrack(videoTrack);
      }
    }
    WebSocketService.sendScreenShareOffer(otherUserId, {'type': 'screen'});
  }

  // ─── Toggle audio/video ───────────────────────────────────────────────────
  static void toggleMute() {
    if (_localStream != null) {
      final track = _localStream!.getAudioTracks().firstOrNull;
      if (track != null) track.enabled = !track.enabled;
    }
  }

  static void toggleCamera() {
    if (_localStream != null) {
      final track = _localStream!.getVideoTracks().firstOrNull;
      if (track != null) track.enabled = !track.enabled;
    }
  }

  static Future<void> switchCamera() async {
    if (_localStream != null) {
      final track = _localStream!.getVideoTracks().firstOrNull;
      if (track != null) await Helper.switchCamera(track);
    }
  }

  // ─── Internal setup ───────────────────────────────────────────────────────
  static Future<void> _setupPeerConnection(int otherUserId,
      {required bool isVideo}) async {
    _peerConnection = await createPeerConnection(_iceConfig);

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo
          ? {'facingMode': 'user', 'width': 640, 'height': 480}
          : false,
    });

    onLocalStream?.call(_localStream!);

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        onRemoteStream?.call(_remoteStream!);
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      WebSocketService.sendIceCandidate(otherUserId, candidate.toMap());
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _state = CallState.active;
        onStateChanged?.call(_state);
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _state = CallState.ended;
        onStateChanged?.call(_state);
      }
    };

    // Handle incoming ICE from WebSocket
    WebSocketService.on('call-ice', (msg) async {
      final candidate = RTCIceCandidate(
        msg['candidate']['candidate'],
        msg['candidate']['sdpMid'],
        msg['candidate']['sdpMLineIndex'],
      );
      await _peerConnection?.addCandidate(candidate);
    });
  }

  static Future<void> _cleanup() async {
    _state = CallState.ended;
    onStateChanged?.call(_state);
    _localStream?.dispose();
    _remoteStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _state = CallState.idle;
  }
}

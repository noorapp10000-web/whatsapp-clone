import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';
import '../services/websocket_service.dart';
import '../services/firestore_service.dart';

class CallScreen extends StatefulWidget {
  final String otherUid;
  final String otherName;
  final String? otherPhoto;
  final bool isVideo;
  final bool isIncoming;
  final Map<String, dynamic>? offerSdp;
  final String? convId;
  final String? callId;

  const CallScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
    this.otherPhoto,
    required this.isVideo,
    required this.isIncoming,
    this.offerSdp,
    this.convId,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _localRenderer  = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  CallState _callState = CallState.idle;
  bool _isMuted    = false;
  bool _cameraOff  = false;
  bool _speakerOn  = true;
  bool _screenSharing = false;

  String?  _callId;
  Duration _elapsed = Duration.zero;
  final    _watch = Stopwatch();
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _callId = widget.callId;

    CallService.onStateChanged = _onState;
    CallService.onLocalStream  = (s) { if (mounted) _localRenderer.srcObject = s; };
    CallService.onRemoteStream = (s) { if (mounted) setState(() { _remoteRenderer.srcObject = s; }); };

    WebSocketService.on('call_answer', _onAnswer);
    WebSocketService.on('call_ice',    _onIce);
    WebSocketService.on('call_end',    _onEnd);
    WebSocketService.on('call_reject', _onReject);

    _initFuture = _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (widget.isIncoming) {
      setState(() => _callState = CallState.ringing);
    } else {
      _callId ??= await FirestoreService.logCall(
          '', widget.otherUid, widget.isVideo ? 'video' : 'voice');
      await CallService.startCall(
        receiverUid: widget.otherUid,
        isVideo: widget.isVideo,
        convId: widget.convId,
        callId: _callId,
      );
      setState(() => _callState = CallState.calling);
    }
  }

  void _onState(CallState s) {
    if (!mounted) return;
    setState(() => _callState = s);
    if (s == CallState.active && !_watch.isRunning) {
      _watch.start();
      _tick();
    }
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _callState != CallState.active) return;
      setState(() => _elapsed = _watch.elapsed);
      _tick();
    });
  }

  void _onAnswer(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') == widget.otherUid) {
      CallService.handleCallAnswer(msg['sdp'] as Map<String, dynamic>);
    }
  }

  void _onIce(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') == widget.otherUid) {
      CallService.addIceCandidate(msg['candidate'] as Map<String, dynamic>);
    }
  }

  void _onEnd(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') == widget.otherUid) _hangUp(remote: true);
  }

  void _onReject(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') == widget.otherUid) _hangUp(remote: true);
  }

  Future<void> _accept() async {
    if (widget.offerSdp == null) return;
    _callId ??= await FirestoreService.logCall(
        widget.otherUid, '', widget.isVideo ? 'video' : 'voice');
    await CallService.acceptCall(
      callerUid: widget.otherUid,
      offerSdp: widget.offerSdp!,
      isVideo: widget.isVideo,
      callId: _callId,
    );
  }

  Future<void> _reject() async {
    await CallService.rejectCall(widget.otherUid, _callId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _hangUp({bool remote = false}) async {
    if (!remote) await CallService.endCall(widget.otherUid, _callId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    WebSocketService.off('call_answer', _onAnswer);
    WebSocketService.off('call_ice',    _onIce);
    WebSocketService.off('call_end',    _onEnd);
    WebSocketService.off('call_reject', _onReject);
    CallService.onStateChanged = null;
    CallService.onLocalStream  = null;
    CallService.onRemoteStream = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2,'0')}:${(d.inSeconds % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1A1A2E),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            // Remote fullscreen
            if (widget.isVideo && _callState == CallState.active)
              Positioned.fill(
                child: RTCVideoView(_remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),

            // Background gradient when no video
            if (!widget.isVideo || _callState != CallState.active)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A884), Color(0xFF005C4B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

            // Name + status
            Positioned(
              top: 80, left: 0, right: 0,
              child: Column(children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white24,
                  backgroundImage: widget.otherPhoto != null
                      ? NetworkImage(widget.otherPhoto!) : null,
                  child: widget.otherPhoto == null
                      ? Text(widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 36, color: Colors.white))
                      : null,
                ),
                const SizedBox(height: 16),
                Text(widget.otherName,
                    style: const TextStyle(color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _callState == CallState.active   ? _fmt(_elapsed)
                  : _callState == CallState.calling ? 'Calling…'
                  : _callState == CallState.ringing
                      ? 'Incoming ${widget.isVideo ? 'Video' : 'Voice'} Call'
                      : '',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ]),
            ),

            // Local PiP
            if (widget.isVideo && _callState == CallState.active)
              Positioned(
                top: 48, right: 16, width: 100, height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(_localRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: true),
                ),
              ),

            // Controls
            Positioned(bottom: 48, left: 0, right: 0, child: _controls()),
          ]),
        );
      },
    );
  }

  Widget _controls() {
    if (_callState == CallState.ringing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _btn(Icons.call_end, Colors.red,   _reject, label: 'Decline'),
          _btn(Icons.call,     Colors.green, _accept, label: 'Accept'),
        ],
      );
    }
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _btn(_isMuted ? Icons.mic_off : Icons.mic,
              _isMuted ? Colors.red : Colors.white24,
              () { setState(() => _isMuted = !_isMuted); CallService.toggleMute(); },
              label: _isMuted ? 'Unmute' : 'Mute'),
          if (widget.isVideo)
            _btn(_cameraOff ? Icons.videocam_off : Icons.videocam,
                _cameraOff ? Colors.red : Colors.white24,
                () { setState(() => _cameraOff = !_cameraOff); CallService.toggleCamera(); },
                label: _cameraOff ? 'Start Cam' : 'Stop Cam'),
          _btn(_speakerOn ? Icons.volume_up : Icons.hearing,
              Colors.white24,
              () { setState(() => _speakerOn = !_speakerOn); CallService.setSpeaker(_speakerOn); },
              label: _speakerOn ? 'Earpiece' : 'Speaker'),
          if (widget.isVideo)
            _btn(Icons.screen_share,
                _screenSharing ? Colors.green : Colors.white24,
                () async {
                  setState(() => _screenSharing = !_screenSharing);
                  if (_screenSharing) await CallService.startScreenShare(widget.otherUid);
                },
                label: 'Screen'),
        ],
      ),
      const SizedBox(height: 24),
      _btn(Icons.call_end, Colors.red, _hangUp, size: 64, label: 'End'),
    ]);
  }

  Widget _btn(IconData icon, Color bg, dynamic onTap, {double size = 54, String? label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap is Future<void> Function() ? () => onTap() : onTap as VoidCallback,
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ],
    );
  }
}

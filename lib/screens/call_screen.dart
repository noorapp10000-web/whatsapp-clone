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
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  CallState _callState = CallState.idle;
  bool _isMuted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _screenSharing = false;
  bool _isVideo = false; // mutable — can be toggled during call

  String? _callId;
  Duration _elapsed = Duration.zero;
  final _watch = Stopwatch();
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _isVideo = widget.isVideo;
    _callId = widget.callId;

    CallService.onStateChanged = _onState;
    CallService.onLocalStream =
        (s) { if (mounted) _localRenderer.srcObject = s; };
    CallService.onRemoteStream =
        (s) { if (mounted) setState(() { _remoteRenderer.srcObject = s; }); };

    WebSocketService.on('call_answer', _onAnswer);
    WebSocketService.on('call_ice', _onIce);
    WebSocketService.on('call_end', _onEnd);
    WebSocketService.on('call_reject', _onReject);
    WebSocketService.on('call_toggle_video', _onToggleVideo);

    _initFuture = _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (widget.isIncoming) {
      setState(() => _callState = CallState.ringing);
    } else {
      _callId ??= await FirestoreService.logCall(
          '', widget.otherUid, _isVideo ? 'video' : 'voice');
      await CallService.startCall(
        receiverUid: widget.otherUid,
        isVideo: _isVideo,
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

  void _onToggleVideo(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') == widget.otherUid) {
      // Remote side switched camera on/off — we can show indicator
      if (mounted) setState(() {});
    }
  }

  Future<void> _accept() async {
    if (widget.offerSdp == null) return;
    _callId ??= await FirestoreService.logCall(
        widget.otherUid, '', _isVideo ? 'video' : 'voice');
    await CallService.acceptCall(
      callerUid: widget.otherUid,
      offerSdp: widget.offerSdp!,
      isVideo: _isVideo,
      callId: _callId,
    );
  }

  Future<void> _reject() async {
    await CallService.rejectCall(widget.otherUid, _callId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _hangUp({bool remote = false}) async {
    _watch.stop();
    if (!remote) await CallService.endCall(widget.otherUid, _callId);
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    if (mounted) Navigator.pop(context);
  }

  /// Toggle between voice and video during an active call
  Future<void> _toggleVideoMode() async {
    setState(() => _isVideo = !_isVideo);
    // Notify other side about video toggle
    WebSocketService.send({
      'type': 'call_toggle_video',
      'targetUid': widget.otherUid,
      'isVideo': _isVideo,
    });
    if (_isVideo) {
      // Re-init with video
      await CallService.toggleCamera();
    } else {
      // Turn off camera
      await CallService.toggleCamera();
    }
  }

  String _fmtElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    WebSocketService.off('call_answer', _onAnswer);
    WebSocketService.off('call_ice', _onIce);
    WebSocketService.off('call_end', _onEnd);
    WebSocketService.off('call_reject', _onReject);
    WebSocketService.off('call_toggle_video', _onToggleVideo);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: FutureBuilder(
        future: _initFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00A884)));
          }
          return Stack(
            children: [
              // Remote video (full screen)
              if (_isVideo && _remoteRenderer.srcObject != null)
                RTCVideoView(_remoteRenderer, objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              else
                _buildVoiceBackground(),

              // Local video (PiP)
              if (_isVideo && _localRenderer.srcObject != null && !_cameraOff)
                Positioned(
                  top: 60,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 100,
                      height: 140,
                      child: RTCVideoView(_localRenderer, mirror: true,
                          objectFit: RTCVideoViewObjectFit
                              .RTCVideoViewObjectFitCover),
                    ),
                  ),
                ),

              // Safe area overlay
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const Spacer(),
                    _buildControls(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoiceBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF005C4B), Color(0xFF1A1A2E)],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFF00A884).withOpacity(0.3),
          backgroundImage: widget.otherPhoto != null
              ? NetworkImage(widget.otherPhoto!)
              : null,
          child: widget.otherPhoto == null
              ? Text(
                  widget.otherName.isNotEmpty
                      ? widget.otherName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white))
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          widget.otherName,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _callState == CallState.ringing
              ? 'مكالمة واردة...'
              : _callState == CallState.calling
                  ? 'جارٍ الاتصال...'
                  : _callState == CallState.active
                      ? _fmtElapsed(_elapsed)
                      : 'انتهت المكالمة',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        if (_isVideo)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, color: Color(0xFF00A884), size: 14),
                SizedBox(width: 4),
                Text('مكالمة فيديو',
                    style: TextStyle(color: Color(0xFF00A884), fontSize: 12)),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call, color: Color(0xFF00A884), size: 14),
                SizedBox(width: 4),
                Text('مكالمة صوتية',
                    style: TextStyle(color: Color(0xFF00A884), fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControls() {
    if (_callState == CallState.ringing) {
      // Incoming call — accept/reject
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _btn(Icons.call_end, Colors.red, _reject, size: 64, label: 'رفض'),
          _btn(Icons.call, Colors.green, _accept, size: 64, label: 'قبول'),
        ],
      );
    }

    return Column(
      children: [
        // Row 1 — Mute, Video/Camera, Speaker, Toggle Voice↔Video
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _btn(
              _isMuted ? Icons.mic_off : Icons.mic,
              _isMuted ? Colors.red : Colors.white24,
              () {
                setState(() => _isMuted = !_isMuted);
                CallService.toggleMute();
              },
              label: _isMuted ? 'إلغاء كتم' : 'كتم',
            ),
            if (_isVideo)
              _btn(
                _cameraOff ? Icons.videocam_off : Icons.videocam,
                _cameraOff ? Colors.red : Colors.white24,
                () {
                  setState(() => _cameraOff = !_cameraOff);
                  CallService.toggleCamera();
                },
                label: _cameraOff ? 'تشغيل الكاميرا' : 'إيقاف الكاميرا',
              ),
            _btn(
              _speakerOn ? Icons.volume_up : Icons.hearing,
              Colors.white24,
              () {
                setState(() => _speakerOn = !_speakerOn);
                CallService.setSpeaker(_speakerOn);
              },
              label: _speakerOn ? 'سماعة الأذن' : 'مكبر الصوت',
            ),
            // ── Toggle Voice ↔ Video ──
            _btn(
              _isVideo ? Icons.call : Icons.videocam,
              const Color(0xFF00A884).withOpacity(0.8),
              _callState == CallState.active ? _toggleVideoMode : null,
              label: _isVideo ? 'صوت فقط' : 'إضافة فيديو',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 2 — Screen share + Flip camera
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (_isVideo)
              _btn(
                Icons.screen_share,
                _screenSharing ? Colors.green : Colors.white24,
                () async {
                  setState(() => _screenSharing = !_screenSharing);
                  if (_screenSharing) {
                    await CallService.startScreenShare(widget.otherUid);
                  }
                },
                label: 'مشاركة الشاشة',
              ),
            if (_isVideo)
              _btn(
                Icons.flip_camera_ios,
                Colors.white24,
                () => CallService.switchCamera(),
                label: 'قلب الكاميرا',
              ),
          ],
        ),
        const SizedBox(height: 24),
        // End call
        _btn(Icons.call_end, Colors.red, _hangUp, size: 64, label: 'إنهاء'),
      ],
    );
  }

  Widget _btn(IconData icon, Color bg, dynamic onTap,
      {double size = 54, String? label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap == null
              ? null
              : onTap is Future<void> Function()
                  ? () => onTap()
                  : onTap as VoidCallback,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: onTap == null ? Colors.grey.withOpacity(0.3) : bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.42),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ],
    );
  }
}

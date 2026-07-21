import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';
import '../services/websocket_service.dart';

class CallScreen extends StatefulWidget {
  final int otherUserId;
  final String otherName;
  final String? otherPhoto;
  final bool isVideo;
  final bool isIncoming;
  final int? conversationId;
  final int? callId;
  final Map<String, dynamic>? offerSdp;

  const CallScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
    this.otherPhoto,
    required this.isVideo,
    required this.isIncoming,
    this.conversationId,
    this.callId,
    this.offerSdp,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  CallState _state = CallState.idle;
  bool _muted = false;
  bool _cameraOff = false;
  bool _screenSharing = false;
  String _statusText = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupCallService();
    if (widget.isIncoming) {
      setState(() => _statusText = 'Incoming call...');
    } else {
      _startCall();
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupCallService() {
    CallService.onStateChanged = (state) {
      if (mounted) {
        setState(() {
          _state = state;
          _statusText = _stateText(state);
        });
        if (state == CallState.ended) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    };

    CallService.onLocalStream = (stream) {
      if (mounted) setState(() => _localRenderer.srcObject = stream);
    };

    CallService.onRemoteStream = (stream) {
      if (mounted) setState(() => _remoteRenderer.srcObject = stream);
    };

    // Handle call events from WebSocket
    WebSocketService.on('call-answer', (msg) async {
      final sdp = msg['sdp'];
      if (sdp != null) {
        // handled inside CallService
      }
    });

    WebSocketService.on('call-end', (msg) async {
      await CallService.endCall(widget.otherUserId, widget.callId);
      if (mounted) Navigator.pop(context);
    });

    WebSocketService.on('call-reject', (msg) async {
      setState(() => _statusText = 'Call rejected');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _startCall() async {
    setState(() => _statusText = 'Ringing...');
    await CallService.startCall(
      receiverId: widget.otherUserId,
      isVideo: widget.isVideo,
      conversationId: widget.conversationId,
    );
  }

  Future<void> _acceptCall() async {
    if (widget.offerSdp == null) return;
    await CallService.acceptCall(
      callerId: widget.otherUserId,
      offerSdp: widget.offerSdp!,
      isVideo: widget.isVideo,
    );
  }

  Future<void> _endCall() async {
    await CallService.endCall(widget.otherUserId, widget.callId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _rejectCall() async {
    await CallService.rejectCall(widget.otherUserId, widget.callId);
    if (mounted) Navigator.pop(context);
  }

  String _stateText(CallState s) {
    switch (s) {
      case CallState.calling:
        return 'Ringing...';
      case CallState.ringing:
        return 'Incoming call...';
      case CallState.active:
        return widget.isVideo ? 'Video call active' : 'Voice call active';
      case CallState.ended:
        return 'Call ended';
      default:
        return 'Connecting...';
    }
  }

  @override
  void dispose() {
    CallService.onStateChanged = null;
    CallService.onLocalStream = null;
    CallService.onRemoteStream = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen)
            if (widget.isVideo && _state == CallState.active)
              RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            else
              _buildAudioBackground(),

            // Local video (small overlay)
            if (widget.isVideo && _state == CallState.active)
              Positioned(
                top: 20,
                right: 20,
                width: 100,
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),

            // Status & controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBackground() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 70,
            backgroundImage: widget.otherPhoto != null
                ? NetworkImage(widget.otherPhoto!)
                : null,
            child: widget.otherPhoto == null
                ? Text(
                    widget.otherName.isNotEmpty
                        ? widget.otherName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 48, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            widget.otherName,
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _statusText,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: widget.isIncoming && _state != CallState.active
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _callButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  label: 'Decline',
                  onTap: _rejectCall,
                ),
                _callButton(
                  icon: Icons.call,
                  color: Colors.green,
                  label: 'Accept',
                  onTap: _acceptCall,
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _toggleButton(
                      icon: _muted ? Icons.mic_off : Icons.mic,
                      label: _muted ? 'Unmute' : 'Mute',
                      active: _muted,
                      onTap: () {
                        setState(() => _muted = !_muted);
                        CallService.toggleMute();
                      },
                    ),
                    if (widget.isVideo)
                      _toggleButton(
                        icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                        label: _cameraOff ? 'Start cam' : 'Stop cam',
                        active: _cameraOff,
                        onTap: () {
                          setState(() => _cameraOff = !_cameraOff);
                          CallService.toggleCamera();
                        },
                      ),
                    if (widget.isVideo)
                      _toggleButton(
                        icon: Icons.screen_share,
                        label: 'Share screen',
                        active: _screenSharing,
                        onTap: () async {
                          await CallService.startScreenShare(widget.otherUserId);
                          setState(() => _screenSharing = true);
                        },
                      ),
                    if (widget.isVideo)
                      _toggleButton(
                        icon: Icons.flip_camera_android,
                        label: 'Flip',
                        active: false,
                        onTap: () => CallService.switchCamera(),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _callButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  label: 'End call',
                  onTap: _endCall,
                ),
              ],
            ),
    );
  }

  Widget _callButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: active ? Colors.black87 : Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

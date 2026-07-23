import 'package:flutter/material.dart';
import 'dart:async';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String otherUid;
  final String otherName;
  final String? otherPhoto;
  final bool isVideo;
  final bool isIncoming;
  final String? callId;
  const CallScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
    this.otherPhoto,
    this.isVideo = false,
    this.isIncoming = false,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _muted = false;
  bool _speakerOn = true;
  bool _cameraOff = false;
  bool _connected = false;
  String? _callId;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _callId = widget.callId;
    if (!widget.isIncoming) _startCall();
    else if (widget.isIncoming && widget.callId != null) _connected = true;
  }

  Future<void> _startCall() async {
    try {
      final result = await CallService.initiateCall(
        calleeUid: widget.otherUid,
        calleeName: widget.otherName,
        isVideo: widget.isVideo,
        calleePhoto: widget.otherPhoto,
      );
      setState(() {
        _callId = result['callId'] as String?;
        _connected = true;
      });
      _startTimer();
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    if (_callId != null) {
      await CallService.endCall(_callId!, durationSeconds: _seconds);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _acceptCall() async {
    if (_callId != null) {
      await CallService.acceptCall(_callId!, widget.otherUid);
    }
    setState(() => _connected = true);
    _startTimer();
  }

  Future<void> _rejectCall() async {
    if (_callId != null) {
      await CallService.rejectCall(_callId!, widget.otherUid);
    }
    if (mounted) Navigator.pop(context);
  }

  String get _duration {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2137),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.isVideo)
                    IconButton(
                      icon: Icon(_cameraOff ? Icons.videocam_off : Icons.videocam, color: Colors.white),
                      onPressed: () => setState(() => _cameraOff = !_cameraOff),
                    ),
                ],
              ),
            ),

            // Avatar and name
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF00A884).withOpacity(0.3),
                    backgroundImage: widget.otherPhoto != null ? NetworkImage(widget.otherPhoto!) : null,
                    child: widget.otherPhoto == null
                        ? Text(
                            widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(widget.otherName,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    _connected
                        ? _duration
                        : widget.isIncoming
                            ? 'مكالمة واردة...'
                            : 'جارٍ الاتصال...',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isVideo ? Icons.videocam : Icons.call,
                          color: const Color(0xFF00A884),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isVideo ? 'مكالمة فيديو' : 'مكالمة صوتية',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Controls
            if (widget.isIncoming && !_connected)
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject
                    GestureDetector(
                      onTap: _rejectCall,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                      ),
                    ),
                    // Accept
                    GestureDetector(
                      onTap: _acceptCall,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(color: Color(0xFF00A884), shape: BoxShape.circle),
                        child: const Icon(Icons.call, color: Colors.white, size: 32),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _controlBtn(
                          icon: _muted ? Icons.mic_off : Icons.mic,
                          label: _muted ? 'إلغاء كتم' : 'كتم',
                          active: _muted,
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                        _controlBtn(
                          icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                          label: 'مكبر',
                          active: _speakerOn,
                          onTap: () => setState(() => _speakerOn = !_speakerOn),
                        ),
                        if (widget.isVideo)
                          _controlBtn(
                            icon: Icons.cameraswitch,
                            label: 'قلب',
                            active: false,
                            onTap: () {},
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn({
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF00A884) : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

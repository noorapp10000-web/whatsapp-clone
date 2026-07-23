import 'package:flutter/material.dart';

class MusicPlayerScreen extends StatefulWidget {
  final String audioUrl;
  final String title;
  final String? senderName;
  final String? sessionId;
  final String? otherUid;
  final bool isHost;
  const MusicPlayerScreen({
    super.key,
    this.audioUrl = '',
    this.title = 'استماع معاً',
    this.senderName,
    this.sessionId,
    this.otherUid,
    this.isHost = false,
  });

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with SingleTickerProviderStateMixin {
  bool _playing = false;
  late AnimationController _vinylCtrl;
  double _position = 0.0;
  final double _duration = 180.0;

  @override
  void initState() {
    super.initState();
    _vinylCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _vinylCtrl.stop();
  }

  @override
  void dispose() {
    _vinylCtrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _vinylCtrl.repeat();
    } else {
      _vinylCtrl.stop();
    }
  }

  String _fmtTime(double secs) {
    final m = secs ~/ 60;
    final s = secs.toInt() % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title,
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Vinyl record animation
          RotationTransition(
            turns: _vinylCtrl,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2D2D44),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A884).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFF00A884),
                  child: Icon(Icons.music_note, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.senderName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.senderName!,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Slider(
                  value: _position,
                  min: 0,
                  max: _duration,
                  activeColor: const Color(0xFF00A884),
                  inactiveColor: Colors.white24,
                  onChanged: (v) => setState(() => _position = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmtTime(_position), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    Text(_fmtTime(_duration), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white60, size: 36),
                onPressed: () {},
              ),
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFF00A884),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                  onPressed: _togglePlay,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white60, size: 36),
                onPressed: () {},
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Extra controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.repeat, color: Colors.white38), onPressed: () {}),
              IconButton(icon: const Icon(Icons.volume_up, color: Colors.white38), onPressed: () {}),
              IconButton(icon: const Icon(Icons.shuffle, color: Colors.white38), onPressed: () {}),
              IconButton(icon: const Icon(Icons.playlist_add, color: Colors.white38), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

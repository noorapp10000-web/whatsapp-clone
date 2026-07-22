import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/firestore_service.dart';
import '../services/websocket_service.dart';

class MusicPlayerScreen extends StatefulWidget {
  final String sessionId;
  final String myUid;
  final String otherUid;
  final String otherName;
  final bool isCreator;

  const MusicPlayerScreen({
    super.key,
    required this.sessionId,
    required this.myUid,
    required this.otherUid,
    required this.otherName,
    required this.isCreator,
  });

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final _player = AudioPlayer();
  List<Map<String, dynamic>> _playlist = [];
  int _currentIndex = 0;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _syncing = false;
  StreamSubscription? _sessionSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _listenSession();
    _listenWs();
  }

  void _initPlayer() {
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
    _player.onPlayerComplete.listen((_) => _next());
  }

  void _listenSession() {
    _sessionSub =
        FirestoreService.listenSessionStream(widget.sessionId).listen((data) {
      if (data == null || !mounted) return;
      final updatedBy = data['lastUpdatedBy'] as String? ?? '';
      if (updatedBy == widget.myUid) return; // ignore own updates

      final playlist = (data['playlist'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final idx = (data['currentIndex'] as int?) ?? 0;
      final isPlaying = (data['isPlaying'] as bool?) ?? false;
      final posMs = (data['positionMs'] as int?) ?? 0;

      if (mounted) {
        setState(() {
          _playlist = playlist;
          _currentIndex = idx;
        });
        _syncPlayback(isPlaying, posMs, idx);
      }
    });
  }

  void _listenWs() {
    WebSocketService.on('lt_play', _onLtPlay);
    WebSocketService.on('lt_pause', _onLtPause);
    WebSocketService.on('lt_seek', _onLtSeek);
    WebSocketService.on('lt_next', _onLtNext);
    WebSocketService.on('lt_end', _onLtEnd);
  }

  void _onLtPlay(Map<String, dynamic> msg) {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    _syncPlayback(true, (msg['positionMs'] as int?) ?? 0, _currentIndex);
  }

  void _onLtPause(Map<String, dynamic> msg) {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    _syncPlayback(false, (msg['positionMs'] as int?) ?? 0, _currentIndex);
  }

  void _onLtSeek(Map<String, dynamic> msg) {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    _player.seek(Duration(milliseconds: (msg['positionMs'] as int?) ?? 0));
  }

  void _onLtNext(Map<String, dynamic> msg) {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    final idx = (msg['index'] as int?) ?? 0;
    _loadTrack(idx);
  }

  void _onLtEnd(Map<String, dynamic> msg) {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _syncPlayback(bool shouldPlay, int posMs, int trackIdx) async {
    if (_syncing) return;
    _syncing = true;
    try {
      if (trackIdx != _currentIndex) {
        await _loadTrack(trackIdx, autoPlay: shouldPlay, startMs: posMs);
      } else {
        final diff = (_position.inMilliseconds - posMs).abs();
        if (diff > 2000) {
          await _player.seek(Duration(milliseconds: posMs));
        }
        if (shouldPlay && !_playing) {
          await _player.resume();
        } else if (!shouldPlay && _playing) {
          await _player.pause();
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _loadTrack(int idx,
      {bool autoPlay = true, int startMs = 0}) async {
    if (idx < 0 || idx >= _playlist.length) return;
    setState(() => _currentIndex = idx);
    final url = _playlist[idx]['url'] as String? ?? '';
    if (url.isEmpty) return;
    await _player.stop();
    await _player.setSource(UrlSource(url));
    if (startMs > 0) await _player.seek(Duration(milliseconds: startMs));
    if (autoPlay) await _player.resume();
  }

  Future<void> _togglePlay() async {
    final posMs = _position.inMilliseconds;
    if (_playing) {
      await _player.pause();
      WebSocketService.sendLTPause(widget.otherUid, widget.sessionId, posMs);
      await FirestoreService.updateListenSession(
          widget.sessionId, {'isPlaying': false, 'positionMs': posMs}, widget.myUid);
    } else {
      await _player.resume();
      WebSocketService.sendLTPlay(widget.otherUid, widget.sessionId, posMs);
      await FirestoreService.updateListenSession(
          widget.sessionId, {'isPlaying': true, 'positionMs': posMs}, widget.myUid);
    }
  }

  Future<void> _next() async {
    final next = (_currentIndex + 1) % _playlist.length;
    await _loadTrack(next);
    WebSocketService.sendLTNext(widget.otherUid, widget.sessionId, next);
    await FirestoreService.updateListenSession(
        widget.sessionId, {'currentIndex': next, 'positionMs': 0, 'isPlaying': true}, widget.myUid);
  }

  Future<void> _prev() async {
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final prev = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    await _loadTrack(prev);
    WebSocketService.sendLTNext(widget.otherUid, widget.sessionId, prev);
    await FirestoreService.updateListenSession(
        widget.sessionId, {'currentIndex': prev, 'positionMs': 0, 'isPlaying': true}, widget.myUid);
  }

  Future<void> _endSession() async {
    WebSocketService.sendLTEnd(widget.otherUid, widget.sessionId);
    await FirestoreService.updateListenSession(
        widget.sessionId, {'status': 'ended'}, widget.myUid);
    if (mounted) Navigator.pop(context);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    WebSocketService.off('lt_play', _onLtPlay);
    WebSocketService.off('lt_pause', _onLtPause);
    WebSocketService.off('lt_seek', _onLtSeek);
    WebSocketService.off('lt_next', _onLtNext);
    WebSocketService.off('lt_end', _onLtEnd);
    _sessionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String get _currentTitle {
    if (_playlist.isEmpty) return 'No song';
    return (_playlist[_currentIndex]['title'] as String? ?? 'Unknown');
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎵 Listen Together',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('with ${widget.otherName}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: _endSession,
            tooltip: 'End session',
          ),
        ],
      ),
      body: Column(
        children: [
          // Album art placeholder
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2333),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00A884).withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.music_note,
                        size: 80, color: Color(0xFF00A884)),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _currentTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_currentIndex + 1} / ${_playlist.length} songs',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF00A884),
                    inactiveTrackColor: Colors.grey[800],
                    thumbColor: const Color(0xFF00A884),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) async {
                      final pos =
                          Duration(milliseconds: (v * _total.inMilliseconds).round());
                      await _player.seek(pos);
                      WebSocketService.sendLTSeek(widget.otherUid,
                          widget.sessionId, pos.inMilliseconds);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(_position),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(_fmt(_total),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous,
                      color: Colors.white, size: 32),
                  onPressed: _playlist.length > 1 ? _prev : null,
                ),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A884),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next,
                      color: Colors.white, size: 32),
                  onPressed: _playlist.length > 1 ? _next : null,
                ),
              ],
            ),
          ),

          // Playlist
          if (_playlist.length > 1)
            Container(
              height: 160,
              color: const Color(0xFF0D1117),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Playlist',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _playlist.length,
                      itemBuilder: (_, i) {
                        final track = _playlist[i];
                        final isActive = i == _currentIndex;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.music_note,
                            color: isActive
                                ? const Color(0xFF00A884)
                                : Colors.grey,
                            size: 18,
                          ),
                          title: Text(
                            track['title'] as String? ?? 'Track ${i + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? const Color(0xFF00A884)
                                  : Colors.white70,
                              fontSize: 13,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () async {
                            await _loadTrack(i);
                            WebSocketService.sendLTNext(
                                widget.otherUid, widget.sessionId, i);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import '../services/websocket_service.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';

class MusicPlayerScreen extends StatefulWidget {
  final String sessionId;
  final String otherUid;
  final bool isHost;
  final List<Map<String, dynamic>>? initialPlaylist;

  const MusicPlayerScreen({
    super.key,
    required this.sessionId,
    required this.otherUid,
    required this.isHost,
    this.initialPlaylist,
  });

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final _player = AudioPlayer();
  List<Map<String, dynamic>> _playlist = [];
  int _currentIndex = 0;
  bool _playing = false;
  bool _uploading = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _syncLock = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlaylist != null) {
      _playlist = List.from(widget.initialPlaylist!);
    }

    // Audio player events
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _total = dur);
    });
    _player.onPlayerComplete.listen((_) => _nextTrack());

    // WebSocket events
    WebSocketService.on('lt_play', _onRemotePlay);
    WebSocketService.on('lt_pause', _onRemotePause);
    WebSocketService.on('lt_seek', _onRemoteSeek);
    WebSocketService.on('lt_next', _onRemoteNext);
    WebSocketService.on('lt_end', _onRemoteEnd);

    // Load Firestore session
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session =
          await FirestoreService.getListenSession(widget.sessionId);
      if (session != null && mounted) {
        final pl = List<Map<String, dynamic>>.from(
            session['playlist'] as List? ?? []);
        final idx = (session['currentIndex'] as int?) ?? 0;
        setState(() {
          _playlist = pl;
          _currentIndex = idx.clamp(0, pl.isEmpty ? 0 : pl.length - 1);
        });
        if (_playlist.isNotEmpty) {
          await _loadTrack(_currentIndex, autoPlay: false);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadTrack(int index, {bool autoPlay = true}) async {
    if (_playlist.isEmpty || index >= _playlist.length) return;
    await _player.stop();
    setState(() {
      _currentIndex = index;
      _position = Duration.zero;
      _total = Duration.zero;
    });
    final url = _playlist[index]['url'] as String? ?? '';
    if (url.isNotEmpty) {
      await _player.setSourceUrl(url);
      if (autoPlay) await _player.resume();
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Future<void> _play() async {
    await _player.resume();
    WebSocketService.sendLTPlay(
        widget.otherUid, widget.sessionId, _position.inMilliseconds);
  }

  Future<void> _pause() async {
    await _player.pause();
    WebSocketService.sendLTPause(
        widget.otherUid, widget.sessionId, _position.inMilliseconds);
  }

  Future<void> _nextTrack() async {
    if (_playlist.isEmpty) return;
    final next = (_currentIndex + 1) % _playlist.length;
    await _loadTrack(next);
    WebSocketService.sendLTNext(widget.otherUid, widget.sessionId, next);
  }

  Future<void> _prevTrack() async {
    if (_playlist.isEmpty) return;
    final prev =
        (_currentIndex - 1 + _playlist.length) % _playlist.length;
    await _loadTrack(prev);
    WebSocketService.sendLTNext(widget.otherUid, widget.sessionId, prev);
  }

  // ── Remote events ──────────────────────────────────────────────────────────

  void _onRemotePlay(Map<String, dynamic> msg) async {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    _syncLock = true;
    final pos = (msg['positionMs'] as int?) ?? 0;
    await _player.seek(Duration(milliseconds: pos));
    await _player.resume();
    _syncLock = false;
  }

  void _onRemotePause(Map<String, dynamic> msg) async {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    await _player.pause();
  }

  void _onRemoteSeek(Map<String, dynamic> msg) async {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    final pos = (msg['positionMs'] as int?) ?? 0;
    await _player.seek(Duration(milliseconds: pos));
  }

  void _onRemoteNext(Map<String, dynamic> msg) async {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    final idx = (msg['index'] as int?) ?? 0;
    await _loadTrack(idx);
  }

  void _onRemoteEnd(Map<String, dynamic> msg) {
    if ((msg['sessionId'] ?? '') != widget.sessionId) return;
    _player.stop();
    if (mounted) Navigator.pop(context);
  }

  // ── Upload audio file (host only) ──────────────────────────────────────────

  Future<void> _uploadAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    try {
      for (final file in result.files) {
        if (file.path == null) continue;
        final bytes = await File(file.path!).readAsBytes();
        final ext = file.extension ?? 'mp3';
        final mime = _mimeForExt(ext);
        final base64Str = base64Encode(bytes);
        final uploaded = await ApiService.uploadFile(
          base64: 'data:$mime;base64,$base64Str',
          mimeType: mime,
          fileName: file.name,
        );
        final url = uploaded['url'] as String? ?? '';
        if (url.isNotEmpty) {
          final track = {'title': file.name.replaceAll(RegExp(r'\.\w+$'), ''), 'url': url};
          setState(() => _playlist.add(track));
          // Persist to Firestore
          await FirestoreService.updateListenSessionData(widget.sessionId, {
            'playlist': _playlist,
          });
        }
      }
      if (_playlist.length == result.files.length && _currentIndex == 0) {
        await _loadTrack(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الرفع: $e')));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  String _mimeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp3': return 'audio/mpeg';
      case 'm4a': return 'audio/mp4';
      case 'ogg': return 'audio/ogg';
      case 'wav': return 'audio/wav';
      case 'flac': return 'audio/flac';
      default: return 'audio/mpeg';
    }
  }

  // ── End session ────────────────────────────────────────────────────────────

  Future<void> _endSession() async {
    WebSocketService.sendLTEnd(widget.otherUid, widget.sessionId);
    await _player.stop();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    WebSocketService.off('lt_play', _onRemotePlay);
    WebSocketService.off('lt_pause', _onRemotePause);
    WebSocketService.off('lt_seek', _onRemoteSeek);
    WebSocketService.off('lt_next', _onRemoteNext);
    WebSocketService.off('lt_end', _onRemoteEnd);
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final currentTrack = _playlist.isNotEmpty
        ? _playlist[_currentIndex]
        : <String, dynamic>{};
    final title =
        currentTrack['title'] as String? ?? 'اختر أغنية';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF005C4B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ──
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'الاستماع معاً',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (widget.isHost)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'إنهاء الجلسة',
                        onPressed: _endSession,
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              // ── Album art ──
              const SizedBox(height: 24),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884).withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A884).withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  _playing ? Icons.music_note : Icons.headphones,
                  size: 80,
                  color: const Color(0xFF00A884),
                ),
              ),
              const SizedBox(height: 24),

              // ── Track info ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentIndex + 1} / ${_playlist.length}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Progress ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF00A884),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: const Color(0xFF00A884),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: widget.isHost
                            ? (v) async {
                                final ms =
                                    (v * _total.inMilliseconds).round();
                                await _player.seek(
                                    Duration(milliseconds: ms));
                                WebSocketService.sendLTSeek(widget.otherUid,
                                    widget.sessionId, ms);
                              }
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(_position),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          Text(_fmt(_total),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Controls ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous,
                        color: Colors.white, size: 36),
                    onPressed: widget.isHost ? _prevTrack : null,
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A884),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: widget.isHost
                          ? () => _playing ? _pause() : _play()
                          : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next,
                        color: Colors.white, size: 36),
                    onPressed: widget.isHost ? _nextTrack : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Host: upload audio files ──
              if (widget.isHost) ...[
                _uploading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00A884))),
                            SizedBox(width: 8),
                            Text('جارٍ رفع الملف...',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _uploadAudioFile,
                        icon: const Icon(Icons.upload_file,
                            color: Color(0xFF00A884)),
                        label: const Text('رفع ملف صوتي',
                            style: TextStyle(color: Color(0xFF00A884))),
                      ),
              ],

              // ── Playlist ──
              Expanded(
                child: _playlist.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.queue_music,
                                size: 48, color: Colors.white24),
                            const SizedBox(height: 8),
                            Text(
                              widget.isHost
                                  ? 'ارفع ملفات صوتية لتبدأ الجلسة'
                                  : 'في انتظار المضيف لإضافة موسيقى...',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.queue_music,
                                    color: Colors.white54, size: 16),
                                const SizedBox(width: 6),
                                Text('قائمة التشغيل (${_playlist.length})',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13)),
                              ],
                            ),
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
                                    isActive && _playing
                                        ? Icons.graphic_eq
                                        : Icons.music_note,
                                    color: isActive
                                        ? const Color(0xFF00A884)
                                        : Colors.white38,
                                    size: 18,
                                  ),
                                  title: Text(
                                    track['title'] as String? ??
                                        'مقطع ${i + 1}',
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
                                  onTap: widget.isHost
                                      ? () async {
                                          await _loadTrack(i);
                                          WebSocketService.sendLTNext(
                                              widget.otherUid,
                                              widget.sessionId,
                                              i);
                                        }
                                      : null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

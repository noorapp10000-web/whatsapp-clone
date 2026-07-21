import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getCallHistory();
      if (mounted) {
        setState(() {
          _calls = List<Map<String, dynamic>>.from(data['calls']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No calls yet', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _calls.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, i) {
        final call = _calls[i];
        final isVideo = call['type'] == 'video';
        final status = call['status'] as String;
        final missed = status == 'missed' || status == 'rejected';
        final time = DateTime.tryParse(call['startedAt'] ?? '');

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF00A884),
            child: Icon(
              isVideo ? Icons.videocam : Icons.call,
              color: Colors.white,
            ),
          ),
          title: Text('User #${call['receiverId']}'),
          subtitle: Row(
            children: [
              Icon(
                missed ? Icons.call_missed : Icons.call_made,
                size: 14,
                color: missed ? Colors.red : const Color(0xFF00A884),
              ),
              const SizedBox(width: 4),
              Text(
                isVideo ? 'Video call' : 'Voice call',
                style: TextStyle(
                  color: missed ? Colors.red : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          trailing: Text(
            time != null
                ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                : '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      },
    );
  }
}

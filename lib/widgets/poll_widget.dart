import 'package:flutter/material.dart';
import '../models/poll_model.dart';

class PollWidget extends StatelessWidget {
  final PollModel poll;
  final String myUid;
  final void Function(int optionIndex) onVote;

  const PollWidget({
    super.key,
    required this.poll,
    required this.myUid,
    required this.onVote,
  });

  bool get _hasVoted => poll.options.any((o) => o.votes.contains(myUid));

  @override
  Widget build(BuildContext context) {
    final total = poll.totalVotes;
    final myVotedIndex = _hasVoted
        ? poll.options.indexWhere((o) => o.votes.contains(myUid))
        : -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.poll, color: Color(0xFF00A884), size: 18),
            const SizedBox(width: 8),
            const Text('استطلاع رأي',
                style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          poll.question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        ...List.generate(poll.options.length, (i) {
          final option = poll.options[i];
          final count = option.votes.length;
          final percent = total > 0 ? count / total : 0.0;
          final isVoted = option.votes.contains(myUid);

          return GestureDetector(
            onTap: () => onVote(i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Stack(
                children: [
                  // Background progress bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isVoted
                            ? const Color(0xFF00A884)
                            : Colors.grey.withOpacity(0.3),
                        width: isVoted ? 2 : 1,
                      ),
                    ),
                  ),
                  // Progress fill
                  if (_hasVoted)
                    FractionallySizedBox(
                      widthFactor: percent,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A884).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  // Content
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          if (isVoted)
                            const Icon(Icons.check_circle, color: Color(0xFF00A884), size: 18)
                          else
                            Icon(Icons.circle_outlined, color: Colors.grey[400], size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                fontWeight: isVoted ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (_hasVoted)
                            Text(
                              '${(percent * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: isVoted ? const Color(0xFF00A884) : Colors.grey[600],
                                fontWeight: isVoted ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '$total ${total == 1 ? 'صوت' : 'أصوات'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (poll.allowMultiple) ...[
              const SizedBox(width: 8),
              Text(
                '• تحديد متعدد',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
            if (poll.expiresAt != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.timer_outlined, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 2),
              Text(
                _timeLeft(poll.expiresAt!),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _timeLeft(DateTime expires) {
    final diff = expires.difference(DateTime.now());
    if (diff.isNegative) return 'انتهى';
    if (diff.inDays > 0) return '${diff.inDays} يوم';
    if (diff.inHours > 0) return '${diff.inHours} ساعة';
    return '${diff.inMinutes} دقيقة';
  }
}

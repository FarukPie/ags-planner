import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/lesson_style.dart';
import '../../../core/widgets/decor.dart';
import '../../../providers/app_provider.dart';

/// Today's (and overdue) 7th/30th-day spaced-repetition reviews.
class ReviewAlertsCard extends StatelessWidget {
  const ReviewAlertsCard({super.key, required this.reviews});

  final List<DueReview> reviews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SoftShadow(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBadge(icon: Icons.replay_rounded, color: Color(0xFFFF7A59), size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bugünkü Tekrarlar',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (reviews.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Badge(
                          label: Text('${reviews.length}'),
                          backgroundColor: const Color(0xFFFF7A59),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (reviews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
                    child: Row(
                      children: [
                        const Text('🎉 ', style: TextStyle(fontSize: 18)),
                        Expanded(
                          child: Text(
                            'Bugün yapılacak tekrar yok. Konu bitirdikçe 7. ve 30. gün tekrarları burada görünür.',
                            style: TextStyle(color: theme.colorScheme.outline),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final r in reviews) _ReviewTile(review: r, overdue: r.dueDate.isBefore(today)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.overdue});

  final DueReview review;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = LessonStyle.of(review.topic.lessonName);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconBadge(icon: style.icon, color: style.color, size: 40),
      title: Text(review.topic.topicName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        overdue
            ? '${review.day}. gün • Gecikti (${DateFormat('d MMM', 'tr_TR').format(review.dueDate)})'
            : '${review.topic.lessonName} • ${review.day}. gün tekrarı',
        style: overdue ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      trailing: IconButton.filledTonal(
        tooltip: 'Tekrar yapıldı',
        icon: const Icon(Icons.check_rounded),
        onPressed: () => context.read<AppProvider>().completeReview(review.topic.id, review.day),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/lesson_style.dart';
import '../../../core/widgets/decor.dart';
import '../../../providers/app_provider.dart';
import '../../curriculum/curriculum_screen.dart';

/// Opens the full topics screen (search, filters, completing topics).
void openTopics(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CurriculumScreen()));

/// Panel card with every lesson's progress, cut off at about half height with
/// a fade; tapping anywhere opens the full topics screen.
class TopicsPreviewCard extends StatelessWidget {
  const TopicsPreviewCard({super.key});

  static const _peekHeight = 168.0;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final lessons = p.topicsByLesson.entries.toList();
    final open = p.topics.where((t) => !t.isCompleted).length;

    final rows = Column(
      children: [
        for (final e in lessons)
          _LessonProgress(
            name: e.key,
            done: e.value.where((t) => t.isCompleted).length,
            total: e.value.length,
          ),
      ],
    );

    return SoftShadow(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openTopics(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBadge(icon: Icons.menu_book_rounded, color: Color(0xFF7B5CFA)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Konular', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text(
                            open == 0 ? 'Tüm konular tamamlandı 🎉' : '$open konu seni bekliyor',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
                  ],
                ),
                const SizedBox(height: 12),
                // Only the top part shows, fading out, as a teaser for the full list.
                SizedBox(
                  height: _peekHeight,
                  child: ClipRect(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.black, Colors.transparent],
                        stops: [0, 0.55, 1],
                      ).createShader(r),
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: double.infinity,
                        child: rows,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () => openTopics(context),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    label: const Text('Tüm konuları aç'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonProgress extends StatelessWidget {
  const _LessonProgress({required this.name, required this.done, required this.total});

  final String name;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = LessonStyle.of(name);
    final ratio = total == 0 ? 0.0 : done / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(style.icon, size: 20, color: style.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text('$done / $total', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: ratio),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: ratio == 1 ? const Color(0xFF3FC380) : style.color,
                      backgroundColor: style.color.withValues(alpha: 0.14),
                    ),
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

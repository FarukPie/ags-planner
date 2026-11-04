import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/lesson_style.dart';
import '../../core/services/image_store.dart';
import '../../core/widgets/animations.dart';
import '../../models/note_model.dart';
import 'note_palette.dart';

/// Notes as a two-column grid or a single-column list. With [onMove] set,
/// a long press picks a card up and dropping it on another card moves it there.
class NoteBoard extends StatelessWidget {
  const NoteBoard({
    super.key,
    required this.notes,
    required this.grid,
    required this.onOpen,
    this.onMove,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final List<NoteModel> notes;
  final bool grid;
  final ValueChanged<NoteModel> onOpen;
  final void Function(String draggedId, String targetId)? onMove;

  /// Global pointer position while dragging (for edge auto-scroll).
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (!grid) {
          return Column(
            children: [
              for (var i = 0; i < notes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: _tile(notes[i], i, c.maxWidth, compact: true),
                ),
            ],
          );
        }
        // Alternating columns keep reading (and drag) order predictable.
        final w = (c.maxWidth - _gap) / 2;
        Widget column(int parity) => Expanded(
              child: Column(
                children: [
                  for (var i = parity; i < notes.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: _gap),
                      child: _tile(notes[i], i, w, compact: false),
                    ),
                ],
              ),
            );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [column(0), const SizedBox(width: _gap), column(1)],
        );
      },
    );
  }

  Widget _tile(NoteModel n, int index, double width, {required bool compact}) {
    final card = NoteCard(note: n, compact: compact, onTap: () => onOpen(n));
    final move = onMove;
    final animated = FadeSlideIn(key: ValueKey(n.id), index: index.clamp(0, 8), child: card);
    if (move == null) return animated;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != n.id,
      onAcceptWithDetails: (d) => move(d.data, n.id),
      builder: (context, candidates, _) => AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: candidates.isEmpty ? 1 : 0.95,
        child: LongPressDraggable<String>(
          data: n.id,
          hapticFeedbackOnStart: true,
          onDragStarted: HapticFeedback.mediumImpact,
          onDragUpdate: (d) => onDragUpdate?.call(d.globalPosition),
          onDragEnd: (_) => onDragEnd?.call(),
          onDraggableCanceled: (_, _) => onDragEnd?.call(),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: width,
              child: Transform.rotate(
                angle: 0.03,
                child: NoteCard(note: n, compact: compact, lifted: true),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: card),
          child: Stack(
            children: [
              animated,
              if (candidates.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: const Color(0xFF6C4CF1), width: 2.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One note preview: photo, title, text or checklist, lesson tag.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, this.compact = false, this.onTap, this.lifted = false});

  final NoteModel note;

  /// List layout: shorter preview, photo as a thumbnail on the side.
  final bool compact;
  final VoidCallback? onTap;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = NotePalette.background(context, note.colorIndex) ?? theme.cardTheme.color ?? scheme.surface;
    final dark = theme.brightness == Brightness.dark;
    final n = note;
    final images = ImageStore.isSupported ? n.imagePaths : const <String>[];

    final body = <Widget>[
      if (n.title.trim().isNotEmpty)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                n.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
              ),
            ),
            if (n.isPinned && n.status == NoteStatus.active)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.push_pin_rounded, size: 16, color: scheme.primary),
              ),
          ],
        ),
      if (n.isChecklist) ..._checklistPreview(context) else if (n.content.trim().isNotEmpty)
        Padding(
          padding: EdgeInsets.only(top: n.title.trim().isEmpty ? 0 : 6),
          child: Text(
            n.content.trim(),
            maxLines: compact ? 3 : 9,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35, color: scheme.onSurface.withValues(alpha: 0.8)),
          ),
        ),
      if (n.lessonName != null || (compact && images.isNotEmpty) || n.status != NoteStatus.active)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (n.lessonName != null) LessonTag(lessonName: n.lessonName!),
              if (n.status == NoteStatus.trashed && n.trashedAt != null)
                Text(
                  'Silindi: ${DateFormat('d MMM', 'tr_TR').format(n.trashedAt!)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
            ],
          ),
        ),
    ];

    final photo = images.isEmpty
        ? null
        : _Photo(path: images.first, extra: images.length - 1, height: compact ? 72 : 130, width: compact ? 72 : null);

    final content = compact
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body)),
              if (photo != null) ...[const SizedBox(width: 12), photo],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grid cards show the photo edge to edge (8px frame), text inset below.
              ?photo,
              if (body.isNotEmpty)
                Padding(
                  padding: photo == null ? EdgeInsets.zero : const EdgeInsets.fromLTRB(6, 10, 6, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
                ),
            ],
          );

    return Material(
      color: bg,
      elevation: lifted ? 10 : 0,
      shadowColor: const Color(0xFF6C4CF1).withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(photo != null && !compact ? 8 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: n.colorIndex == 0
                ? Border.all(color: scheme.outlineVariant.withValues(alpha: dark ? 0.4 : 0.6))
                : null,
            boxShadow: lifted || dark
                ? null
                : [BoxShadow(color: const Color(0xFF6C4CF1).withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: content,
        ),
      ),
    );
  }

  List<Widget> _checklistPreview(BuildContext context) {
    final theme = Theme.of(context);
    final items = note.checklist.where((i) => i.text.trim().isNotEmpty).toList();
    final open = items.where((i) => !i.done).toList();
    final done = items.length - open.length;
    final shown = open.take(compact ? 3 : 6).toList();
    final hidden = open.length - shown.length;
    return [
      if (note.title.trim().isNotEmpty) const SizedBox(height: 6),
      for (final i in shown)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_box_outline_blank_rounded, size: 18, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(child: Text(i.text, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      if (hidden > 0 || done > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [if (hidden > 0) '+$hidden madde', if (done > 0) '$done tamamlandı ✓'].join(' • '),
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
    ];
  }
}

/// Small colored lesson chip.
class LessonTag extends StatelessWidget {
  const LessonTag({super.key, required this.lessonName, this.onDeleted, this.onTap});

  final String lessonName;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = LessonStyle.of(lessonName);
    return Material(
      color: style.color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 4, onDeleted == null ? 10 : 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 14, color: style.color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  lessonName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: style.color),
                ),
              ),
              if (onDeleted != null)
                InkWell(
                  onTap: onDeleted,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(Icons.close_rounded, size: 16, color: style.color),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path, required this.extra, required this.height, this.width});

  final String path;
  final int extra;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius - 6),
      child: Stack(
        children: [
          Image.file(
            File(path),
            height: height,
            width: width ?? double.infinity,
            fit: BoxFit.cover,
            cacheWidth: 600,
            errorBuilder: (_, _, _) => Container(
              height: height,
              width: width ?? double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
          if (extra > 0)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text('+$extra', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

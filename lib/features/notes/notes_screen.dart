import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/lesson_style.dart';
import '../../core/widgets/decor.dart';
import '../../models/note_model.dart';
import '../../providers/app_provider.dart';
import 'note_board.dart';
import 'note_editor_page.dart';

/// Quick filters above the notes.
enum _Filter { all, checklists }

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  _Filter _filter = _Filter.all;
  String? _lesson;
  bool _grid = true;

  // Edge auto-scroll while dragging a note.
  Timer? _autoScroll;
  double _dragY = 0;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _autoScroll?.cancel();
    super.dispose();
  }

  void _onDragUpdate(Offset global) {
    _dragY = global.dy;
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) return;
      final h = MediaQuery.sizeOf(context).height;
      const edge = 110.0;
      double speed = 0;
      if (_dragY < edge + 80) speed = -14 * (1 - (_dragY - 80).clamp(0, edge) / edge);
      if (_dragY > h - edge - 80) speed = 14 * (1 - (h - 80 - _dragY).clamp(0, edge) / edge);
      if (speed == 0) return;
      final p = _scroll.position;
      _scroll.jumpTo((p.pixels + speed).clamp(p.minScrollExtent, p.maxScrollExtent));
    });
  }

  void _onDragEnd() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  Future<void> _open({NoteModel? note, NoteStart start = NoteStart.text}) async {
    final result = await openNoteEditor(context, note: note, start: start);
    if (mounted && result != null) showNoteExitSnack(context, result);
  }

  bool _matches(NoteModel n) {
    final q = _search.text.trim().toLowerCase();
    return (q.isEmpty || n.searchText.contains(q)) &&
        (_lesson == null || n.lessonName == _lesson) &&
        switch (_filter) {
          _Filter.all => true,
          _Filter.checklists => n.isChecklist,
        };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final all = p.notesIn(NoteStatus.active);
    final notes = all.where(_matches).toList();
    final pinned = notes.where((n) => n.isPinned).toList();
    final others = notes.where((n) => !n.isPinned).toList();
    final lessons = {for (final n in all) ?n.lessonName}.toList()..sort();
    final filtering = _search.text.isNotEmpty || _filter != _Filter.all || _lesson != null;

    Widget board(List<NoteModel> list) => NoteBoard(
      notes: list,
      grid: _grid,
      onOpen: (n) => _open(note: n),
      onMove: (dragged, target) => p.moveNote(dragged, target),
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notlarım'),
        actions: [
          IconButton(
            tooltip: _grid ? 'Liste görünümü' : 'Izgara görünümü',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(_grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded, key: ValueKey(_grid)),
            ),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          PopupMenuButton<NoteStatus>(
            tooltip: 'Diğer',
            onSelected: (s) =>
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => NoteCollectionPage(status: s))),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: NoteStatus.archived,
                child: ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: Text('Arşiv (${p.notesIn(NoteStatus.archived).length})'),
                ),
              ),
              PopupMenuItem(
                value: NoteStatus.trashed,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text('Çöp kutusu (${p.notesIn(NoteStatus.trashed).length})'),
                ),
              ),
            ],
          ),
        ],
      ),
      // The capture card is the single way to add a note; it stays pinned on
      // top so it is always one tap away, however far the list is scrolled.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _QuickCapture(
              onText: () => _open(),
              onChecklist: () => _open(start: NoteStart.checklist),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                if (all.isNotEmpty) ...[
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Notlarda ara',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Temizle',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (f, label, icon) in [
                          (_Filter.all, 'Tümü', Icons.notes_rounded),
                          (_Filter.checklists, 'Yapılacaklar', Icons.checklist_rounded),
                              ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              showCheckmark: false,
                              avatar: Icon(icon, size: 18),
                              label: Text(label),
                              selected: _filter == f && (f != _Filter.all || _lesson == null),
                              onSelected: (_) => setState(() {
                                _filter = f;
                                if (f == _Filter.all) _lesson = null;
                              }),
                            ),
                          ),
                        for (final l in lessons)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              showCheckmark: false,
                              avatar: Icon(LessonStyle.of(l).icon, size: 18, color: LessonStyle.of(l).color),
                              label: Text(l),
                              selected: _lesson == l,
                              onSelected: (v) => setState(() => _lesson = v ? l : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (all.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.sticky_note_2_rounded,
                    title: 'İlk notunu al',
                    message:
                        'Yukarıdaki karta dokunup aklına geleni hemen yaz ya da yapılacaklar listesi tut. '
                        'Notların otomatik kaydedilir; renklendir, sabitle, sürükleyip istediğin gibi sırala.',
                  )
                else if (notes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 44, color: theme.colorScheme.outline),
                        const SizedBox(height: 8),
                        Text('Bu aramaya uyan not yok.', style: TextStyle(color: theme.colorScheme.outline)),
                      ],
                    ),
                  )
                else ...[
                  if (pinned.isNotEmpty) ...[
                    _Header(icon: Icons.push_pin_rounded, text: 'Sabitlenenler'),
                    board(pinned),
                    if (others.isNotEmpty) _Header(icon: Icons.notes_rounded, text: 'Diğer notlar'),
                  ],
                  if (others.isNotEmpty) board(others),
                  if (!filtering && all.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'İpucu: Bir notu basılı tutup başka bir notun üzerine bırakarak sıralayabilirsin.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells what happened to the note, with "undo" back to its previous place.
void showNoteExitSnack(BuildContext context, NoteEditorResult r) {
  final app = context.read<AppProvider>();
  final text = switch (r.exit) {
    NoteEditorExit.archived => 'Not arşivlendi',
    NoteEditorExit.unarchived => 'Not arşivden çıkarıldı',
    NoteEditorExit.trashed => 'Not çöp kutusuna taşındı',
    NoteEditorExit.discarded => 'Boş not silindi',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        // Snack bars with an action stay until tapped by default; the undo
        // offer should disappear on its own after a few seconds.
        persist: false,
        duration: const Duration(seconds: 4),
        action: r.exit == NoteEditorExit.discarded
            ? null
            : SnackBarAction(label: 'Geri al', onPressed: () => app.setNoteStatus(r.id, r.from)),
      ),
    );
}

class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: outline),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: outline),
          ),
        ],
      ),
    );
  }
}

/// The single "take a note" entry point: tap to write, or start a list
/// straight away. Uses the brand gradient so it stands out.
class _QuickCapture extends StatelessWidget {
  const _QuickCapture({required this.onText, required this.onChecklist});

  final VoidCallback onText;
  final VoidCallback onChecklist;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radius + 4);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: const Color(0xFF6C4CF1).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onText,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bir not al…',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hemen yaz ya da liste yap',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _CaptureAction(tooltip: 'Yeni liste', icon: Icons.checklist_rounded, onTap: onChecklist),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureAction extends StatelessWidget {
  const _CaptureAction({required this.tooltip, required this.icon, required this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

/// Archive or trash.
class NoteCollectionPage extends StatelessWidget {
  const NoteCollectionPage({super.key, required this.status});

  final NoteStatus status;

  Future<void> _trashAction(BuildContext context, NoteModel n) async {
    final app = context.read<AppProvider>();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('Geri yükle'),
              onTap: () => Navigator.pop(c, 'restore'),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: Theme.of(c).colorScheme.error),
              title: Text('Kalıcı olarak sil', style: TextStyle(color: Theme.of(c).colorScheme.error)),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'restore') await app.setNoteStatus(n.id, NoteStatus.active);
    if (action == 'delete') await app.deleteNoteForever(n.id);
  }

  Future<void> _empty(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Çöp kutusu boşaltılsın mı?'),
        content: const Text('Buradaki tüm notlar kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Boşalt')),
        ],
      ),
    );
    if (ok == true && context.mounted) await context.read<AppProvider>().emptyTrash();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final notes = app.notesIn(status);
    final trash = status == NoteStatus.trashed;
    final outline = Theme.of(context).colorScheme.outline;
    return Scaffold(
      appBar: AppBar(
        title: Text(trash ? 'Çöp Kutusu' : 'Arşiv'),
        actions: [
          if (trash && notes.isNotEmpty) TextButton(onPressed: () => _empty(context), child: const Text('Boşalt')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              trash
                  ? 'Çöp kutusundaki notlar ${AppProvider.trashRetention.inDays} gün sonra kalıcı olarak silinir.'
                  : 'Arşivdeki notlar ana listede görünmez; istediğin zaman geri alabilirsin.',
              style: TextStyle(color: outline),
            ),
          ),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(trash ? Icons.delete_outline_rounded : Icons.archive_outlined, size: 56, color: outline),
                  const SizedBox(height: 8),
                  Text(trash ? 'Çöp kutusu boş' : 'Arşivde not yok', style: TextStyle(color: outline)),
                ],
              ),
            )
          else
            NoteBoard(
              notes: notes,
              grid: true,
              onOpen: (n) async {
                if (trash) return _trashAction(context, n);
                final result = await openNoteEditor(context, note: n);
                if (result != null && context.mounted) showNoteExitSnack(context, result);
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/lesson_style.dart';
import '../../models/note_model.dart';
import '../../models/topic_model.dart';
import '../../providers/app_provider.dart';
import 'note_board.dart';
import 'note_palette.dart';

/// What happened to the note when the editor closed, so the list can offer "undo".
enum NoteEditorExit { archived, unarchived, trashed, discarded }

/// [exit] for note [id], which was in [from] before.
typedef NoteEditorResult = ({NoteEditorExit exit, String id, NoteStatus from});

/// How a new note starts.
enum NoteStart { text, checklist }

/// Opens the editor for [note] (or a new note); null when it was simply closed.
Future<NoteEditorResult?> openNoteEditor(BuildContext context, {NoteModel? note, NoteStart start = NoteStart.text}) =>
    Navigator.push<NoteEditorResult>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorPage(note: note, start: start)),
    );

/// Full-screen editor. There is no save button: the note is saved when the
/// user leaves (or the app goes to the background); an empty new note is dropped.
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.note, this.start = NoteStart.text});

  final NoteModel? note;
  final NoteStart start;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _Item {
  _Item(this.id, String text, this.done) : controller = TextEditingController(text: text);

  final String id;
  final TextEditingController controller;
  final FocusNode focus = FocusNode();
  bool done;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _NoteEditorPageState extends State<NoteEditorPage> with WidgetsBindingObserver {
  late final AppProvider _app = context.read<AppProvider>();
  late final String _id = widget.note?.id ?? AppProvider.newId();
  late final DateTime _createdAt = widget.note?.createdAt ?? DateTime.now();
  late final TextEditingController _title = TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _content = TextEditingController(text: widget.note?.content ?? '');
  final _contentFocus = FocusNode();
  final _titleFocus = FocusNode();

  late bool _checklist = widget.note?.isChecklist ?? widget.start == NoteStart.checklist;
  late final List<_Item> _items = [
    for (final i in widget.note?.checklist ?? const <ChecklistItem>[]) _Item(i.id, i.text, i.done),
  ];
  late int _color = widget.note?.colorIndex ?? 0;
  late bool _pinned = widget.note?.isPinned ?? false;
  late String? _lesson = widget.note?.lessonName;
  late String? _topicId = widget.note?.topicId;
  late DateTime _updatedAt = widget.note?.updatedAt ?? _createdAt;

  /// Whether this note exists in the provider (saved at least once).
  late bool _stored = widget.note != null;
  bool _dirty = false;
  bool _showDone = true;

  NoteStatus get _status => _app.noteById(_id)?.status ?? widget.note?.status ?? NoteStatus.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final c in [_title, _content]) {
      c.addListener(_markDirty);
    }
    for (final i in _items) {
      i.controller.addListener(_markDirty);
    }
    if (widget.note == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (widget.start) {
          case NoteStart.text:
            _contentFocus.requestFocus();
          case NoteStart.checklist:
            _addItem();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The app may be killed in the background: keep what was typed.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _save();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    _titleFocus.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _markDirty() => _dirty = true;

  void _change(VoidCallback fn) {
    _dirty = true;
    setState(fn);
  }

  NoteModel _build() => NoteModel(
        id: _id,
        title: _title.text.trim(),
        content: _content.text.trimRight(),
        isChecklist: _checklist,
        checklist: [
          for (final i in _items)
            if (i.controller.text.trim().isNotEmpty) ChecklistItem(id: i.id, text: i.controller.text.trim(), done: i.done),
        ],
        colorIndex: _color,
        isPinned: _pinned,
        status: _status,
        trashedAt: _app.noteById(_id)?.trashedAt,
        lessonName: _lesson,
        topicId: _topicId,
        sortKey: _app.noteById(_id)?.sortKey ?? _app.topNoteSortKey,
        createdAt: _createdAt,
        updatedAt: _dirty ? DateTime.now() : _updatedAt,
      );

  /// Saves pending changes. Returns false when the note is empty.
  Future<bool> _save() async {
    final note = _build();
    if (note.isEmpty) return false;
    if (!_dirty && _stored) return true;
    _updatedAt = note.updatedAt;
    _dirty = false;
    _stored = true;
    await _app.saveNote(note);
    return true;
  }

  Future<void> _close() async {
    NoteEditorResult? result;
    if (!await _save()) {
      if (_stored) {
        // An existing note that was emptied is removed.
        await _app.deleteNoteForever(_id);
        result = (exit: NoteEditorExit.discarded, id: _id, from: _status);
      }
    }
    if (mounted) Navigator.pop(context, result);
  }

  Future<void> _setStatus(NoteStatus status, NoteEditorExit exit) async {
    final note = _build();
    if (note.isEmpty) return _close();
    final from = _status;
    await _save();
    await _app.setNoteStatus(_id, status);
    if (mounted) Navigator.pop<NoteEditorResult>(context, (exit: exit, id: _id, from: from));
  }

  // ------------------------------------------------------------ checklist

  void _addItem({int? at, String text = ''}) {
    final item = _Item(AppProvider.newId(), text, false)..controller.addListener(_markDirty);
    _change(() => _items.insert(at ?? _openCount, item));
    WidgetsBinding.instance.addPostFrameCallback((_) => item.focus.requestFocus());
  }

  int get _openCount => _items.where((i) => !i.done).length;

  void _removeItem(_Item item) {
    _change(() => _items.remove(item));
    item.dispose();
  }

  void _toggleItem(_Item item) => _change(() {
        item.done = !item.done;
        // Done items sink to the bottom; reopened ones go to the end of the open list.
        _items.remove(item);
        _items.insert(item.done ? _items.length : _openCount, item);
      });

  void _toggleChecklist() => _change(() {
        if (_checklist) {
          _content.text = _items.map((i) => i.controller.text).where((t) => t.trim().isNotEmpty).join('\n');
          for (final i in _items) {
            i.dispose();
          }
          _items.clear();
        } else {
          for (final line in _content.text.split('\n')) {
            if (line.trim().isEmpty) continue;
            _items.add(_Item(AppProvider.newId(), line.trim(), false)..controller.addListener(_markDirty));
          }
          _content.clear();
          if (_items.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _addItem());
        }
        _checklist = !_checklist;
      });

  // ------------------------------------------------------------ color, tag

  Future<void> _colorSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Renk', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (var i = 0; i < NotePalette.length; i++)
                      Tooltip(
                        message: NotePalette.name(i),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            _change(() => _color = i);
                            setSheet(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: NotePalette.dot(i),
                              border: Border.all(
                                color: i == _color ? Theme.of(c).colorScheme.primary : Theme.of(c).colorScheme.outlineVariant,
                                width: i == _color ? 3 : 1,
                              ),
                            ),
                            child: i == 0
                                ? Icon(Icons.format_color_reset_outlined, color: Colors.grey.shade600, size: 20)
                                : (i == _color ? const Icon(Icons.check_rounded, color: Colors.white) : null),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _lessonSheet() async {
    final byLesson = _app.topicsByLesson;
    final picked = await showModalBottomSheet<({String lesson, String? topicId})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => _LessonPicker(byLesson: byLesson, lesson: _lesson, topicId: _topicId),
    );
    if (picked != null) {
      _change(() {
        _lesson = picked.lesson;
        _topicId = picked.topicId;
      });
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = NotePalette.background(context, _color) ?? theme.scaffoldBackgroundColor;
    final status = _status;
    final topic = _topicId == null ? null : _app.topicById(_topicId!);
    final open = _items.where((i) => !i.done).toList();
    final done = _items.where((i) => i.done).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: 'Geri',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _close,
            ),
            actions: [
              if (status == NoteStatus.active)
                IconButton(
                  tooltip: _pinned ? 'Sabitlemeyi kaldır' : 'Sabitle',
                  icon: Icon(_pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
                  onPressed: () => _change(() => _pinned = !_pinned),
                ),
              if (status == NoteStatus.active)
                IconButton(
                  tooltip: 'Arşivle',
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: () => _setStatus(NoteStatus.archived, NoteEditorExit.archived),
                ),
              if (status == NoteStatus.archived)
                IconButton(
                  tooltip: 'Arşivden çıkar',
                  icon: const Icon(Icons.unarchive_outlined),
                  onPressed: () => _setStatus(NoteStatus.active, NoteEditorExit.unarchived),
                ),
              IconButton(
                tooltip: 'Çöp kutusuna taşı',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _setStatus(NoteStatus.trashed, NoteEditorExit.trashed),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              TextField(
                controller: _title,
                focusNode: _titleFocus,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _checklist ? _addItem(at: 0) : _contentFocus.requestFocus(),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  hintText: 'Başlık',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isCollapsed: true,
                ),
              ),
              const SizedBox(height: 12),
              if (!_checklist)
                TextField(
                  controller: _content,
                  focusNode: _contentFocus,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  minLines: 8,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Not al…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                  ),
                )
              else ...[
                for (final i in open) _itemRow(i),
                TextButton.icon(
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 4)),
                  onPressed: () => _addItem(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Madde ekle'),
                ),
                if (done.isNotEmpty) ...[
                  const Divider(height: 20),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _showDone = !_showDone),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(_showDone ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              color: theme.colorScheme.outline),
                          const SizedBox(width: 6),
                          Text('${done.length} tamamlanan madde', style: TextStyle(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                  ),
                  if (_showDone) for (final i in done) _itemRow(i),
                ],
              ],
              if (_lesson != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LessonTag(
                    lessonName: topic == null ? _lesson! : '$_lesson • ${topic.topicName}',
                    onTap: _lessonSheet,
                    onDeleted: () => _change(() {
                      _lesson = null;
                      _topicId = null;
                    }),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: _BottomTools(
            checklist: _checklist,
            updatedAt: _stored ? _updatedAt : null,
            onChecklist: _toggleChecklist,
            onColor: _colorSheet,
            onLesson: _lessonSheet,
          ),
        ),
    );
  }

  Widget _itemRow(_Item item) {
    final theme = Theme.of(context);
    return Row(
      key: ValueKey(item.id),
      children: [
        Checkbox(value: item.done, onChanged: (_) => _toggleItem(item)),
        Expanded(
          child: TextField(
            controller: item.controller,
            focusNode: item.focus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _addItem(at: item.done ? null : _items.indexOf(item) + 1),
            style: theme.textTheme.bodyLarge?.copyWith(
              decoration: item.done ? TextDecoration.lineThrough : null,
              color: item.done ? theme.colorScheme.outline : null,
            ),
            decoration: const InputDecoration(
              hintText: 'Madde',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Maddeyi sil',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.outline),
          onPressed: () => _removeItem(item),
        ),
      ],
    );
  }
}

class _BottomTools extends StatelessWidget {
  const _BottomTools({
    required this.checklist,
    required this.updatedAt,
    required this.onChecklist,
    required this.onColor,
    required this.onLesson,
  });

  final bool checklist;
  final DateTime? updatedAt;
  final VoidCallback onChecklist;
  final VoidCallback onColor;
  final VoidCallback onLesson;

  String _edited(DateTime t) {
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return 'Düzenlendi ${DateFormat(sameDay ? 'HH:mm' : 'd MMM', 'tr_TR').format(t)}';
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 6),
              IconButton(
                tooltip: checklist ? 'Düz metne çevir' : 'Yapılacaklar listesi',
                icon: Icon(checklist ? Icons.notes_rounded : Icons.checklist_rounded),
                onPressed: onChecklist,
              ),
              IconButton(tooltip: 'Renk', icon: const Icon(Icons.palette_outlined), onPressed: onColor),
              IconButton(tooltip: 'Ders etiketi', icon: const Icon(Icons.school_outlined), onPressed: onLesson),
              const Spacer(),
              if (updatedAt != null)
                Text(_edited(updatedAt!), style: TextStyle(fontSize: 12, color: outline)),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lesson (and optional topic) picker sheet.
class _LessonPicker extends StatefulWidget {
  const _LessonPicker({required this.byLesson, required this.lesson, required this.topicId});

  final Map<String, List<TopicModel>> byLesson;
  final String? lesson;
  final String? topicId;

  @override
  State<_LessonPicker> createState() => _LessonPickerState();
}

class _LessonPickerState extends State<_LessonPicker> {
  late String? _lesson = widget.lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics = widget.byLesson[_lesson] ?? const <TopicModel>[];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(_lesson == null ? 'Ders seç' : 'Konu seç (isteğe bağlı)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_lesson == null)
            for (final l in widget.byLesson.keys)
              ListTile(
                leading: Icon(LessonStyle.of(l).icon, color: LessonStyle.of(l).color),
                title: Text(l),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => setState(() => _lesson = l),
              )
          else ...[
            ListTile(
              leading: const Icon(Icons.arrow_back_rounded),
              title: Text(_lesson!, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => setState(() => _lesson = null),
            ),
            ListTile(
              leading: const Icon(Icons.label_outline_rounded),
              title: const Text('Yalnızca ders (konu yok)'),
              onTap: () => Navigator.pop(context, (lesson: _lesson!, topicId: null)),
            ),
            for (final t in topics)
              ListTile(
                leading: Icon(
                  t.id == widget.topicId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(t.topicName),
                onTap: () => Navigator.pop(context, (lesson: _lesson!, topicId: t.id)),
              ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/decor.dart';
import '../../models/agenda_model.dart';
import '../../providers/app_provider.dart';
import 'widgets/agenda_item_dialog.dart';

class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  void _report(String? warning) {
    if (warning == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(warning)));
  }

  Future<void> _edit([AgendaModel? item]) async {
    final provider = context.read<AppProvider>();
    final result = await showAgendaItemDialog(
      context,
      item: item,
      day: _selected,
      canUseCalendar: provider.canUseCalendar,
    );
    if (result != null) _report(await provider.saveAgenda(result));
  }

  Future<void> _delete(AgendaModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text(
          item.googleEventId == null
              ? '"${item.title}" ajandadan silinecek.'
              : '"${item.title}" ajandadan ve Google Takvim\'den silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _report(await context.read<AppProvider>().deleteAgenda(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final items = p.agendaOn(_selected);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'agenda_fab',
        tooltip: 'Ajandaya ekle',
        onPressed: _edit,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SoftShadow(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: TableCalendar<AgendaModel>(
                    locale: 'tr_TR',
                    firstDay: DateTime(2020),
                    lastDay: DateTime(DateTime.now().year + 5, 12, 31),
                    focusedDay: _focused,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarFormat: _format,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Ay',
                      CalendarFormat.twoWeeks: '2 Hafta',
                      CalendarFormat.week: 'Hafta',
                    },
                    selectedDayPredicate: (d) => isSameDay(d, _selected),
                    eventLoader: p.agendaOn,
                    onDaySelected: (selected, focused) => setState(() {
                      _selected = selected;
                      _focused = focused;
                    }),
                    onFormatChanged: (f) => setState(() => _format = f),
                    onPageChanged: (f) => _focused = f,
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      formatButtonDecoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      formatButtonTextStyle: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekendStyle: TextStyle(
                        color: theme.colorScheme.error.withValues(alpha: 0.8),
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      weekendTextStyle: TextStyle(
                        color: theme.colorScheme.error.withValues(alpha: 0.8),
                      ),
                      markersMaxCount: 3,
                      markerDecoration: const BoxDecoration(
                        color: Color(0xFFFF7A59),
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      selectedDecoration: const BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionTitle(
              DateFormat('d MMMM, EEEE', 'tr_TR').format(_selected),
              trailing: items.isEmpty
                  ? null
                  : Text(
                      '${items.where((a) => a.isCompleted).length}/${items.length} tamamlandı',
                      style: theme.textTheme.bodySmall,
                    ),
            ),
          ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: items.where((a) => a.isCompleted).length / items.length),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 6),
                ),
              ),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EmptyStateCard(
                icon: Icons.event_available_rounded,
                title: 'Bu gün için plan yok',
                message: 'Çalışma, deneme veya tekrar planlarını ekle; istersen Google Takvim\'ine de gönder.',
                actionLabel: 'Plan ekle',
                onAction: _edit,
              ),
            ),
          for (var i = 0; i < items.length; i++)
            _agendaTile(context, p, theme, items[i], i),
        ],
      ),
    );
  }

  Widget _agendaTile(
    BuildContext context,
    AppProvider p,
    ThemeData theme,
    AgendaModel item,
    int index,
  ) {
    return FadeSlideIn(
      key: ValueKey(item.id),
      index: index,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SoftShadow(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: item.isCompleted
                        ? const Color(0xFF3FC380)
                        : theme.colorScheme.primary,
                    width: 5,
                  ),
                ),
              ),
              child: ListTile(
                leading: Checkbox(
                  value: item.isCompleted,
                  onChanged: (_) => p.toggleAgendaCompleted(item.id),
                ),
                title: Text(
                  item.title,
                  style: item.isCompleted
                      ? TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.outline,
                        )
                      : null,
                ),
                subtitle: Text(
                  item.startTime == null
                      ? 'Tüm gün'
                      : '${item.startTime}${item.endTime == null ? '' : ' – ${item.endTime}'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.googleEventId != null)
                      const Tooltip(
                        message: 'Google Takvim ile senkronize',
                        child: Icon(Icons.event_available, size: 18),
                      ),
                    IconButton(
                      tooltip: 'Sil',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(item),
                    ),
                  ],
                ),
                onTap: () => _edit(item),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

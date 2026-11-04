import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/agenda_model.dart';
import '../../../providers/app_provider.dart';

/// Add/edit an agenda item. Returns the item to save, or null if cancelled.
Future<AgendaModel?> showAgendaItemDialog(
  BuildContext context, {
  AgendaModel? item,
  required DateTime day,
  required bool canUseCalendar,
}) =>
    showDialog<AgendaModel>(
      context: context,
      builder: (_) => _AgendaItemDialog(item: item, day: day, canUseCalendar: canUseCalendar),
    );

class _AgendaItemDialog extends StatefulWidget {
  const _AgendaItemDialog({required this.item, required this.day, required this.canUseCalendar});

  final AgendaModel? item;
  final DateTime day;
  final bool canUseCalendar;

  @override
  State<_AgendaItemDialog> createState() => _AgendaItemDialogState();
}

class _AgendaItemDialogState extends State<_AgendaItemDialog> {
  late final TextEditingController _title;
  late DateTime _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  late bool _sync;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _date = item?.date ?? widget.day;
    _start = _parse(item?.startTime);
    _end = _parse(item?.endTime);
    _sync = item?.syncToGoogleCalendar ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  static TimeOfDay? _parse(String? hhmm) {
    final parts = hhmm?.split(':');
    if (parts == null || parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  static String? _format(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (start ? _start : _end ?? _start) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Başlık boş olamaz.');
      return;
    }
    if (_start != null && _end != null && _minutes(_end!) <= _minutes(_start!)) {
      setState(() => _error = 'Bitiş saati başlangıçtan sonra olmalı.');
      return;
    }
    final item = widget.item;
    Navigator.pop(
      context,
      AgendaModel(
        id: item?.id ?? AppProvider.newId(),
        title: title,
        date: DateTime(_date.year, _date.month, _date.day),
        startTime: _format(_start),
        endTime: _start == null ? null : _format(_end),
        isCompleted: item?.isCompleted ?? false,
        syncToGoogleCalendar: _sync,
        googleEventId: item?.googleEventId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDay = _start == null;
    return AlertDialog(
      title: Text(widget.item == null ? 'Ajandaya Ekle' : 'Planı Düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.item == null,
              decoration: InputDecoration(labelText: 'Başlık', errorText: _error),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat('d MMMM y', 'tr_TR').format(_date)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tüm gün'),
              value: allDay,
              onChanged: (v) => setState(() {
                _start = v ? null : const TimeOfDay(hour: 9, minute: 0);
                _end = v ? null : const TimeOfDay(hour: 10, minute: 0);
              }),
            ),
            if (!allDay)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(start: true),
                      child: Text('Başlangıç ${_format(_start)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(start: false),
                      child: Text('Bitiş ${_format(_end) ?? '—'}'),
                    ),
                  ),
                ],
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Google Takvim\'e ekle'),
              subtitle: widget.canUseCalendar ? null : const Text('Önce Panel\'den Google ile giriş yapın.'),
              value: _sync,
              // Allow turning OFF even when signed out (so the flag can be cleared).
              onChanged: widget.canUseCalendar || _sync ? (v) => setState(() => _sync = v) : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: _submit, child: const Text('Kaydet')),
      ],
    );
  }
}

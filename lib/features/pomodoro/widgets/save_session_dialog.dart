import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format.dart';
import '../../../models/study_session_model.dart';

/// Result of [showSaveSessionDialog]: `save == false` means discard.
typedef SaveSessionResult = ({bool save, StudyActivity activity, int solvedQuestions});

/// Asks whether the user solved questions or studied the topic (and, for
/// questions, how many), then whether to save the session.
/// Returns null when the user cancels (only possible if [allowCancel]).
Future<SaveSessionResult?> showSaveSessionDialog(
  BuildContext context, {
  required int minutes,
  required String subject,
  bool allowCancel = true,
  bool celebrate = false,
}) {
  return showDialog<SaveSessionResult>(
    context: context,
    barrierDismissible: allowCancel,
    builder: (_) =>
        _SaveSessionDialog(minutes: minutes, subject: subject, allowCancel: allowCancel, celebrate: celebrate),
  );
}

class _SaveSessionDialog extends StatefulWidget {
  const _SaveSessionDialog({
    required this.minutes,
    required this.subject,
    required this.allowCancel,
    required this.celebrate,
  });

  final int minutes;
  final String subject;
  final bool allowCancel;
  final bool celebrate;

  @override
  State<_SaveSessionDialog> createState() => _SaveSessionDialogState();
}

class _SaveSessionDialogState extends State<_SaveSessionDialog> {
  final _questions = TextEditingController();
  StudyActivity? _activity;

  @override
  void dispose() {
    _questions.dispose();
    super.dispose();
  }

  void _close(bool save) => Navigator.pop<SaveSessionResult>(context, (
    save: save,
    activity: _activity ?? StudyActivity.topic,
    solvedQuestions: _activity == StudyActivity.questions ? int.tryParse(_questions.text) ?? 0 : 0,
  ));

  Widget _option(StudyActivity value, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _activity == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _activity = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? scheme.primary : scheme.outline, size: 30),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Back must not discard an auto-finished pomodoro (only "Kaydetme" does).
    return PopScope(
      canPop: widget.allowCancel,
      child: AlertDialog(
        title: Text(widget.celebrate ? 'Pomodoro tamamlandı 🎉' : 'Oturumu Kaydet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.subject, style: theme.textTheme.titleSmall),
              Text('Süre: ${formatMinutes(widget.minutes)}'),
              const SizedBox(height: 16),
              const Text('Bu oturumda ne yaptın?'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _option(StudyActivity.questions, Icons.edit_note_rounded, 'Soru çözdüm'),
                  const SizedBox(width: 10),
                  _option(StudyActivity.topic, Icons.menu_book_rounded, 'Konu çalıştım'),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _activity != StudyActivity.questions
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: TextField(
                          controller: _questions,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Kaç soru çözdün?',
                            hintText: '0',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _close(true),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.allowCancel) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          TextButton(onPressed: () => _close(false), child: const Text('Kaydetme')),
          FilledButton(onPressed: _activity == null ? null : () => _close(true), child: const Text('Kaydet')),
        ],
      ),
    );
  }
}

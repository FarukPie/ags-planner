import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/ags_curriculum_data.dart';
import '../../core/format.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/branch_picker_page.dart';
import '../../core/widgets/decor.dart';
import '../../models/user_profile.dart';
import '../../providers/app_provider.dart';

/// Required profile after sign-in (setup), also used to edit the profile.
/// Setup mode = there is no profile yet; then it is a full screen with no back.
class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key, this.initialName});

  final String? initialName;

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  static const _goalOptions = [60, 90, 120, 180, 240, 300];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _university;
  late final TextEditingController _target;
  late final bool _isSetup;
  String? _branchKey;
  CandidateStatus? _status;
  late int _goal;
  late DateTime _examDate;
  bool _showErrors = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    final p = app.profile;
    _isSetup = p == null;
    _name = TextEditingController(text: p?.fullName ?? widget.initialName ?? '');
    _university = TextEditingController(text: p?.university ?? '');
    _target = TextEditingController(text: p?.targetScore == null ? '' : _fmtScore(p!.targetScore!));
    _branchKey = _isSetup ? null : app.branchKey; // setup: user must choose explicitly
    _status = p?.status;
    _goal = p?.dailyGoalMinutes ?? 120;
    _examDate = app.examDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _university.dispose();
    _target.dispose();
    super.dispose();
  }

  static String _fmtScore(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _chooseBranch() async {
    final key = await pickBranch(context, current: _branchKey);
    if (key != null) setState(() => _branchKey = key);
  }

  Future<void> _chooseExamDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _examDate.isBefore(now) ? now : _examDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      helpText: 'Hedef sınav tarihi',
    );
    if (d != null) setState(() => _examDate = DateTime(d.year, d.month, d.day, _examDate.hour, _examDate.minute));
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _branchKey == null || _status == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen zorunlu alanları doldur.')),
      );
      return;
    }
    setState(() => _saving = true);
    final app = context.read<AppProvider>();
    await app.saveProfile(
      UserProfile(
        fullName: _name.text.trim(),
        status: _status!,
        dailyGoalMinutes: _goal,
        university: _university.text.trim().isEmpty ? null : _university.text.trim(),
        targetScore: double.tryParse(_target.text.replaceAll(',', '.')),
        createdAt: app.profile?.createdAt ?? DateTime.now(),
      ),
      branchKey: _branchKey!,
      examDate: _examDate,
    );
    // Setup mode: the AuthGate swaps to the app. Edit mode: go back.
    if (mounted && !_isSetup) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final branch = AgsCurriculum.tryBranch(_branchKey);
    final photo = auth.user?.photoURL;

    Widget requiredLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: ' *', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w800)),
          ])),
        );

    Widget errorText(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(text, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
        );

    final sections = <Widget>[
      GradientCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              backgroundImage: photo == null ? null : NetworkImage(photo),
              child: photo == null ? const Icon(Icons.person_rounded, color: Colors.white, size: 30) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSetup ? 'Hoş geldin! 👋' : 'Profilini düzenle',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSetup
                        ? 'Planını sana göre hazırlayabilmemiz için seni biraz tanıyalım.'
                        : 'Bilgilerin tüm cihazlarında güncellenir.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('Kişisel Bilgiler'),
      SoftShadow(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                requiredLabel('Ad Soyad'),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(60)],
                  decoration: const InputDecoration(hintText: 'Adın ve soyadın', prefixIcon: Icon(Icons.badge_rounded)),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Ad soyad zorunludur.';
                    if (t.length < 3) return 'En az 3 karakter olmalı.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                requiredLabel('Şu anki durumun'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in CandidateStatus.values)
                      ChoiceChip(
                        label: Text(s.label),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                  ],
                ),
                if (_showErrors && _status == null) errorText('Durumunu seç.'),
                const SizedBox(height: 14),
                const Text('Üniversite / Bölüm (isteğe bağlı)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _university,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  decoration: const InputDecoration(
                    hintText: 'ör. Ankara Üniversitesi - Sınıf Öğretmenliği',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SectionTitle('Sınav Hedefin'),
      SoftShadow(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                requiredLabel('Öğretmenlik alanı'),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _chooseBranch,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: (branch?.color ?? theme.colorScheme.primary).withValues(alpha: 0.1),
                      border: Border.all(
                        color: _showErrors && branch == null
                            ? theme.colorScheme.error
                            : (branch?.color ?? theme.colorScheme.primary).withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconBadge(
                          icon: branch?.icon ?? Icons.school_rounded,
                          color: branch?.color ?? theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                branch?.name ?? 'Alanını seç',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                branch?.examInfo ?? '17 ÖABT alanı, 11 yabancı dil ve diğer alanlar',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
                if (_showErrors && branch == null) errorText('Öğretmenlik alanını seç.'),
                const SizedBox(height: 14),
                requiredLabel('Günlük çalışma hedefi'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in _goalOptions)
                      ChoiceChip(
                        label: Text(formatMinutes(m)),
                        selected: _goal == m,
                        onSelected: (_) => setState(() => _goal = m),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Sınav tarihi', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _chooseExamDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.event_rounded)),
                    child: Text(DateFormat('d MMMM y, EEEE', 'tr_TR').format(_examDate)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Hedef AGS puanı (isteğe bağlı)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(hintText: 'ör. 75', prefixIcon: Icon(Icons.flag_rounded)),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    final n = double.tryParse(t.replaceAll(',', '.'));
                    if (n == null || n < 0 || n > 100) return '0 ile 100 arasında bir puan gir.';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: GradientCard(
          padding: const EdgeInsets.symmetric(vertical: 16),
          onTap: _saving ? null : _save,
          child: Center(
            child: _saving
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(
                    _isSetup ? 'Başlayalım 🚀' : 'Kaydet',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
      if (_isSetup && auth.user != null)
        Center(
          child: TextButton(
            onPressed: _saving ? null : () => context.read<AuthService>().signOut(),
            child: Text('${auth.user!.email ?? 'Bu hesap'} değil misin? Farklı hesapla giriş yap'),
          ),
        ),
    ];

    return Scaffold(
      appBar: _isSetup ? null : AppBar(title: const Text('Profili Düzenle')),
      body: SafeArea(
        top: _isSetup,
        child: Form(
          key: _formKey,
          autovalidateMode: _showErrors ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [for (var i = 0; i < sections.length; i++) FadeSlideIn(index: i, child: sections[i])],
          ),
        ),
      ),
    );
  }
}

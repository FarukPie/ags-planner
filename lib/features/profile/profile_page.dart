import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/branch_picker_page.dart';
import '../../core/widgets/decor.dart';
import '../../providers/app_provider.dart';
import '../onboarding/profile_form_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final app = context.read<AppProvider>();
    final auth = context.read<AuthService>();
    setState(() => _signingOut = true);
    try {
      final flushed = await app.flushCloudWrites();
      if (!mounted) return;
      if (!flushed) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.cloud_off_rounded),
            title: const Text('Gönderilmemiş değişiklikler var'),
            content: const Text(
              'Bazı değişikliklerin henüz buluta ulaşmadı (internet yok gibi görünüyor). '
              'Şimdi çıkış yaparsan bu değişiklikler kaybolabilir. İnternete bağlanıp tekrar denemeni öneririz.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yine de çıkış yap')),
            ],
          ),
        );
        if (proceed != true) return;
      } else {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Çıkış yapılsın mı?'),
            content: const Text('Verilerin hesabında güvende. Tekrar giriş yaptığında hepsi geri gelir.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Çıkış Yap')),
            ],
          ),
        );
        if (ok != true) return;
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      await auth.signOut();
      await app.clearUserData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Çıkış yapılamadı: $e')));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final auth = context.watch<AuthService>();
    final theme = Theme.of(context);
    final profile = app.profile;
    final branch = app.branch;
    final user = auth.user;
    final photo = user?.photoURL;

    Widget infoRow(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: theme.colorScheme.outline)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    Widget stat(String value, String label, IconData icon, Color color) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
            ],
          ),
        );

    final sections = <Widget>[
      GradientCard(
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              backgroundImage: photo == null ? null : NetworkImage(photo),
              child: photo == null
                  ? Text(profile?.initials ?? '?',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              profile?.fullName ?? 'Profil',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(branch.name, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
            const SizedBox(height: 16),
            Row(
              children: [
                stat(formatMinutes(app.totalStudyMinutes), 'çalışma', Icons.schedule_rounded, Colors.white),
                stat('${app.completedTopicCount}', 'biten konu', Icons.task_alt_rounded, Colors.white),
                stat('${app.exams.length}', 'deneme', Icons.insights_rounded, Colors.white),
                stat('${app.studyStreak()} gün', 'seri', Icons.local_fire_department_rounded, Colors.white),
              ],
            ),
          ],
        ),
      ),
      SectionTitle(
        'Profil Bilgileri',
        trailing: TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProfileFormPage())),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Düzenle'),
        ),
      ),
      SoftShadow(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                if (profile != null) ...[
                  infoRow(Icons.person_rounded, 'Durum', profile.status.label),
                  infoRow(Icons.flag_circle_rounded, 'Günlük hedef', formatMinutes(profile.dailyGoalMinutes)),
                  if (profile.targetScore != null)
                    infoRow(Icons.emoji_events_rounded, 'Hedef puan', profile.targetScore!.toStringAsFixed(1)),
                  if (profile.university != null) infoRow(Icons.apartment_rounded, 'Üniversite', profile.university!),
                ],
                infoRow(Icons.event_rounded, 'Sınav tarihi', DateFormat('d MMMM y', 'tr_TR').format(app.examDate)),
              ],
            ),
          ),
        ),
      ),
      const SectionTitle('Öğretmenlik Alanı'),
      SoftShadow(
        child: Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            leading: IconBadge(icon: branch.icon, color: branch.color),
            title: Text(branch.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(branch.examInfo),
            trailing: const Icon(Icons.swap_horiz_rounded),
            onTap: () async {
              final key = await pickBranch(context, current: app.branchKey);
              if (key != null) await app.setBranch(key);
            },
          ),
        ),
      ),
      const SectionTitle('Görünüm'),
      SoftShadow(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Sistem')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Açık')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Koyu')),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (s) => app.setThemeMode(s.first),
            ),
          ),
        ),
      ),
      const SectionTitle('Hesap ve Senkronizasyon'),
      SoftShadow(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                if (user == null)
                  const ListTile(
                    leading: Icon(Icons.cloud_off_rounded),
                    title: Text('Yerel mod'),
                    subtitle: Text('Bu kurulumda Google ile giriş kullanılamıyor; verilerin bu cihazda saklanıyor.'),
                  )
                else ...[
                  ListTile(
                    leading: const Icon(Icons.alternate_email_rounded),
                    title: Text(user.email ?? 'Google hesabı'),
                    subtitle: const Text('Google ile giriş yapıldı'),
                  ),
                  ListTile(
                    leading: app.isSyncing
                        ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Icon(
                            app.syncError == null ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
                            color: app.syncError == null ? const Color(0xFF3FC380) : theme.colorScheme.error,
                          ),
                    title: Text(app.isSyncing
                        ? 'Senkronize ediliyor…'
                        : app.lastSyncedAt == null
                            ? 'Senkronize edilmeyi bekliyor'
                            : 'Son senkronizasyon: ${DateFormat('d MMM HH:mm', 'tr_TR').format(app.lastSyncedAt!)}'),
                    subtitle: app.syncError == null
                        ? null
                        : Text(app.syncError!, style: TextStyle(color: theme.colorScheme.error)),
                    trailing: IconButton(
                      tooltip: 'Şimdi senkronize et',
                      onPressed: app.isSyncing ? null : app.syncNow,
                      icon: const Icon(Icons.sync_rounded),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      if (user != null) ...[
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
          ),
          onPressed: _signingOut ? null : _signOut,
          icon: _signingOut
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.logout_rounded),
          label: const Text('Çıkış Yap'),
        ),
      ],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [for (var i = 0; i < sections.length; i++) FadeSlideIn(index: i, child: sections[i])],
      ),
    );
  }
}

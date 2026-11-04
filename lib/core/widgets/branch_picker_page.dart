import 'package:flutter/material.dart';

import '../ags_curriculum_data.dart';
import '../app_theme.dart';
import 'animations.dart';
import 'decor.dart';

/// Opens the full-screen teaching-field picker; returns the chosen key.
Future<String?> pickBranch(BuildContext context, {String? current}) => Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => BranchPickerPage(current: current)),
    );

class BranchPickerPage extends StatefulWidget {
  const BranchPickerPage({super.key, this.current});

  final String? current;

  @override
  State<BranchPickerPage> createState() => _BranchPickerPageState();
}

class _BranchPickerPageState extends State<BranchPickerPage> {
  final _search = TextEditingController();
  BranchCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Turkish-aware, accent-insensitive normalization for search.
  static String _norm(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _norm(_search.text.trim());
    final visible = AgsCurriculum.fieldBranches
        .where((b) => _category == null || b.category == _category)
        .where((b) => q.isEmpty || _norm(b.name).contains(q))
        .toList();
    final current = AgsCurriculum.tryBranch(widget.current);

    final children = <Widget>[
      if (current != null && q.isEmpty)
        GradientCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(current.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Şu anki alanın', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                    Text(current.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(current.examInfo, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      for (final category in BranchCategory.values)
        if (visible.where((b) => b.category == category).toList() case final group when group.isNotEmpty) ...[
          SectionTitle(
            category.title,
            trailing: Text(category.assessment, style: theme.textTheme.bodySmall),
          ),
          for (final b in group)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BranchTile(
                branch: b,
                selected: b.key == widget.current,
                onTap: () => Navigator.pop(context, b.key),
              ),
            ),
        ],
      if (visible.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              const Text('Bu aramaya uyan alan yok.'),
              Text('"Diğer / Listede Olmayan Alan" seçeneğini kullanabilirsin.', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Öğretmenlik Alanı')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Alan ara (ör. Fizik, İngilizce, Müzik)',
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
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in <BranchCategory?>[null, ...BranchCategory.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c == null
                          ? 'Tümü (${AgsCurriculum.fieldBranches.length})'
                          : '${c.title} (${AgsCurriculum.fieldBranches.where((b) => b.category == c).length})'),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                for (var i = 0; i < children.length; i++)
                  FadeSlideIn(key: ValueKey('${_category}_${q}_$i'), index: i, child: children[i]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({required this.branch, required this.selected, required this.onTap});

  final FieldBranch branch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftShadow(
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: selected ? BorderSide(color: branch.color, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                IconBadge(icon: branch.icon, color: branch.color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(branch.examInfo, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: selected
                      ? Icon(Icons.check_circle_rounded, key: const ValueKey(true), color: branch.color)
                      : Icon(Icons.chevron_right_rounded, key: const ValueKey(false), color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

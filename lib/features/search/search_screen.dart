import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import 'search_logic.dart';

final _allCardsProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(repositoryProvider).watchAllCards(),
);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.focusNode});

  /// Lets the shell move the cursor here (Ctrl+K).
  final FocusNode? focusNode;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  SearchFilter _filter = const SearchFilter();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(SearchFilter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cards = ref.watch(_allCardsProvider);
    final labelsByCard = ref.watch(labelsByCardProvider);
    final allLabels = ref.watch(allLabelsProvider).value ?? const <Label>[];
    final labelNames = {for (final l in allLabels) l.name.toLowerCase(): l.name}
        .values
        .toList()
      ..sort();

    final hits = cards.hasValue
        ? filterCards(cards.value!, labelsByCard, _filter)
        : const <SearchHit>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Cari')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              key: const Key('search-field'),
              controller: _controller,
              focusNode: widget.focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari judul, deskripsi, board…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('search-clear'),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _set(_filter.copyWith(query: ''));
                        },
                      ),
              ),
              onChanged: (v) => _set(_filter.copyWith(query: v)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 0,
              children: [
                _chip(
                  'filter-pinned',
                  'Ter-pin',
                  _filter.pinnedOnly,
                  (v) => _set(_filter.copyWith(pinnedOnly: v)),
                ),
                _chip(
                  'filter-overdue',
                  'Terlewat',
                  _filter.due == DueFilter.overdue,
                  (v) => _set(_filter.copyWith(due: v ? DueFilter.overdue : DueFilter.any)),
                ),
                _chip(
                  'filter-today',
                  'Hari ini',
                  _filter.due == DueFilter.today,
                  (v) => _set(_filter.copyWith(due: v ? DueFilter.today : DueFilter.any)),
                ),
                _chip(
                  'filter-hasdue',
                  'Ada tenggat',
                  _filter.due == DueFilter.hasDue,
                  (v) => _set(_filter.copyWith(due: v ? DueFilter.hasDue : DueFilter.any)),
                ),
                _chip(
                  'filter-done',
                  'Termasuk selesai',
                  _filter.showDone,
                  (v) => _set(_filter.copyWith(showDone: v)),
                ),
                for (final name in labelNames)
                  _chip(
                    'filter-label-$name',
                    name,
                    _filter.labelName?.toLowerCase() == name.toLowerCase(),
                    (v) => _set(_filter.copyWith(labelName: () => v ? name : null)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !cards.hasValue
                ? const Center(child: CircularProgressIndicator())
                : hits.isEmpty
                    ? Center(
                        key: const Key('search-empty'),
                        child: Text(
                          _filter.isEmpty
                              ? 'Belum ada kartu.'
                              : 'Tidak ada kartu yang cocok.',
                          style: TextStyle(color: t.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: hits.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) => _HitTile(hit: hits[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String key, String label, bool selected, void Function(bool) on) =>
      FilterChip(
        key: Key(key),
        label: Text(label),
        selected: selected,
        onSelected: on,
      );
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});
  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = hit.card;
    final done = c.completedAt != null;
    final status = dueStatus(c.dueAt, completed: done);
    return Material(
      color: t.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/card/${c.id}'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (c.pinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin, size: 14, color: t.accent),
                    ),
                  Expanded(
                    child: Text(
                      c.title,
                      style: TextStyle(
                        fontSize: 15,
                        color: done ? t.textSecondary : t.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${hit.open.boardTitle} › ${hit.open.listTitle}',
                style: TextStyle(fontSize: 13, color: t.textSecondary),
              ),
              if (hit.labels.isNotEmpty || c.dueAt != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final l in hit.labels)
                      Chip(
                        label: Text(l.name, style: const TextStyle(fontSize: 12)),
                        avatar: CircleAvatar(
                          backgroundColor: Color(l.color),
                          radius: 5,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    if (c.dueAt != null)
                      Text(
                        formatDue(c.dueAt!),
                        style: TextStyle(
                          fontSize: 13,
                          color: status == DueStatus.overdue
                              ? t.danger
                              : status == DueStatus.today
                                  ? t.warning
                                  : t.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

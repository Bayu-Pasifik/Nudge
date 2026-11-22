import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/db/repository.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../boards/boards_screen.dart' show confirmDialog;
import 'checklist_section.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({super.key, required this.cardId});
  final String cardId;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();
  late final Repository _repo = ref.read(repositoryProvider);
  bool _loaded = false;
  String _savedTitle = '';
  String _savedDesc = '';

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _saveTitle();
    });
    _descFocus.addListener(() {
      if (!_descFocus.hasFocus) _saveDesc();
    });
  }

  @override
  void dispose() {
    _saveTitle();
    _saveDesc();
    _title.dispose();
    _desc.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  void _saveTitle() {
    final v = _title.text.trim();
    if (!_loaded || v.isEmpty || v == _savedTitle) return;
    _savedTitle = v;
    _repo.updateCard(widget.cardId, title: v);
  }

  void _saveDesc() {
    final v = _desc.text;
    if (!_loaded || v == _savedDesc) return;
    _savedDesc = v;
    _repo.updateCard(widget.cardId, description: v);
  }

  Future<void> _pickDue(TodoCard card) async {
    final initial = card.dueAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: card.dueAt != null && (card.dueAt!.hour != 0 || card.dueAt!.minute != 0)
          ? TimeOfDay.fromDateTime(card.dueAt!)
          : const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Jam (batal = tanpa jam)',
    );
    final due = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    await _repo.updateCard(card.id, dueAt: Value(due));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cardAsync = ref.watch(cardProvider(widget.cardId));
    final card = cardAsync.value;

    if (card != null && !_loaded) {
      _title.text = card.title;
      _desc.text = card.description;
      _savedTitle = card.title;
      _savedDesc = card.description;
      _loaded = true;
    }

    if (card == null || card.deletedAt != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: cardAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('Kartu tidak ditemukan'),
        ),
      );
    }

    final done = card.completedAt != null;
    final status = dueStatus(card.dueAt, completed: done);

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            key: const Key('card-menu'),
            onSelected: (v) async {
              if (v == 'archive') {
                await _repo.archiveCard(card.id);
                if (context.mounted) context.pop();
              } else if (v == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'Hapus kartu?',
                  message: 'Kartu "${card.title}" akan dihapus.',
                  confirmLabel: 'Hapus',
                  destructive: true,
                );
                if (ok) {
                  await _repo.deleteCard(card.id);
                  if (context.mounted) context.pop();
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
              PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: const Key('detail-complete'),
                value: done,
                shape: const CircleBorder(),
                activeColor: t.success,
                onChanged: (v) => _repo.setCardCompleted(card.id, v ?? false),
              ),
              Expanded(
                child: TextField(
                  key: const Key('detail-title'),
                  controller: _title,
                  focusNode: _titleFocus,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: 'Judul',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            icon: Icons.event,
            title: 'Jatuh tempo',
            child: Row(
              children: [
                OutlinedButton(
                  key: const Key('pick-due'),
                  onPressed: () => _pickDue(card),
                  child: Text(
                    card.dueAt == null ? 'Atur tanggal' : formatDue(card.dueAt!),
                    style: TextStyle(
                      color: switch (status) {
                        DueStatus.overdue => t.danger,
                        DueStatus.today => t.warning,
                        _ => t.textPrimary,
                      },
                    ),
                  ),
                ),
                if (card.dueAt != null)
                  IconButton(
                    key: const Key('clear-due'),
                    tooltip: 'Hapus tanggal',
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        _repo.updateCard(card.id, dueAt: const Value(null)),
                  ),
              ],
            ),
          ),
          _Section(
            icon: Icons.notes,
            title: 'Deskripsi',
            child: TextField(
              key: const Key('detail-desc'),
              controller: _desc,
              focusNode: _descFocus,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Tambahkan detail'),
            ),
          ),
          _Section(
            icon: Icons.checklist,
            title: 'Checklist',
            child: ChecklistSection(card: card),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: t.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

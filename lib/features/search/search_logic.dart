import '../../core/db/database.dart';
import '../../core/db/repository.dart';
import '../../core/util/format.dart';

enum DueFilter { any, overdue, today, hasDue }

class SearchFilter {
  const SearchFilter({
    this.query = '',
    this.showDone = false,
    this.pinnedOnly = false,
    this.due = DueFilter.any,
    this.labelName,
  });

  final String query;

  /// Include finished cards.
  final bool showDone;
  final bool pinnedOnly;
  final DueFilter due;

  /// Case-insensitive label name; labels are per board, so the same name on
  /// two boards counts as one filter.
  final String? labelName;

  SearchFilter copyWith({
    String? query,
    bool? showDone,
    bool? pinnedOnly,
    DueFilter? due,
    String? Function()? labelName,
  }) =>
      SearchFilter(
        query: query ?? this.query,
        showDone: showDone ?? this.showDone,
        pinnedOnly: pinnedOnly ?? this.pinnedOnly,
        due: due ?? this.due,
        labelName: labelName == null ? this.labelName : labelName(),
      );

  bool get isEmpty =>
      query.trim().isEmpty &&
      !showDone &&
      !pinnedOnly &&
      due == DueFilter.any &&
      labelName == null;
}

class SearchHit {
  const SearchHit(this.open, this.labels);
  final OpenCard open;
  final List<Label> labels;
  TodoCard get card => open.card;
}

/// Pure filtering for the search screen. Every whitespace-separated word of
/// the query must appear in the title, description, board or list name.
/// Cards whose *title* matches come first; otherwise order is kept.
List<SearchHit> filterCards(
  List<OpenCard> cards,
  Map<String, List<Label>> labelsByCard,
  SearchFilter f, {
  DateTime? now,
}) {
  final words = f.query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final wantLabel = f.labelName?.toLowerCase();

  final hits = <SearchHit>[];
  for (final o in cards) {
    final c = o.card;
    final done = c.completedAt != null;
    if (done && !f.showDone) continue;
    if (f.pinnedOnly && !c.pinned) continue;

    final status = dueStatus(c.dueAt, completed: done, now: now);
    switch (f.due) {
      case DueFilter.any:
        break;
      case DueFilter.overdue:
        if (status != DueStatus.overdue) continue;
      case DueFilter.today:
        if (status != DueStatus.today && status != DueStatus.overdue) continue;
      case DueFilter.hasDue:
        if (c.dueAt == null) continue;
    }

    final labels = labelsByCard[c.id] ?? const <Label>[];
    if (wantLabel != null &&
        !labels.any((l) => l.name.toLowerCase() == wantLabel)) {
      continue;
    }

    if (words.isNotEmpty) {
      final hay = '${c.title} ${c.description} ${o.boardTitle} ${o.listTitle}'
          .toLowerCase();
      if (!words.every(hay.contains)) continue;
    }
    hits.add(SearchHit(o, labels));
  }

  if (words.isNotEmpty) {
    final inTitle = <SearchHit>[];
    final rest = <SearchHit>[];
    for (final h in hits) {
      final t = h.card.title.toLowerCase();
      (words.every(t.contains) ? inTitle : rest).add(h);
    }
    return [...inTitle, ...rest];
  }
  return hits;
}

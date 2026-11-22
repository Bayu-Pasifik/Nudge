import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/features/search/search_logic.dart';

void main() {
  final now = DateTime(2026, 11, 22, 10);
  final stamp = DateTime(2026, 1, 1);

  OpenCard card(
    String id,
    String title, {
    String desc = '',
    DateTime? due,
    bool pinned = false,
    bool done = false,
    String board = 'Rumah',
    String list = 'Todo',
  }) =>
      OpenCard(
        card: TodoCard(
          id: id,
          createdAt: stamp,
          updatedAt: stamp,
          dirty: false,
          listId: 'l',
          boardId: 'b',
          title: title,
          description: desc,
          dueAt: due,
          position: 0,
          completedAt: done ? stamp : null,
          pinned: pinned,
          stickyColor: 'yellow',
          autoCompleteOnChecklist: false,
        ),
        listTitle: list,
        boardTitle: board,
      );

  Label label(String name) => Label(
        id: 'lab-$name',
        createdAt: stamp,
        updatedAt: stamp,
        dirty: false,
        boardId: 'b',
        name: name,
        color: 0xFF000000,
      );

  List<String> ids(List<SearchHit> h) => h.map((x) => x.card.id).toList();

  final cards = [
    card('a', 'Bayar listrik', desc: 'Token PLN bulanan'),
    card('b', 'Beli susu', board: 'Belanja', list: 'Mingguan'),
    card('c', 'Telepon bank', due: DateTime(2026, 11, 20), pinned: true),
    card('d', 'Kirim laporan', due: DateTime(2026, 11, 22, 18)),
    card('e', 'Sudah beres', done: true),
  ];

  test('empty filter lists open cards only', () {
    final r = filterCards(cards, {}, const SearchFilter(), now: now);
    expect(ids(r), ['a', 'b', 'c', 'd']);
    expect(const SearchFilter().isEmpty, isTrue);
  });

  test('query matches title, description, board and list; all words needed', () {
    expect(ids(filterCards(cards, {}, const SearchFilter(query: 'listrik'), now: now)), ['a']);
    expect(ids(filterCards(cards, {}, const SearchFilter(query: 'pln'), now: now)), ['a']);
    expect(ids(filterCards(cards, {}, const SearchFilter(query: 'belanja'), now: now)), ['b']);
    expect(ids(filterCards(cards, {}, const SearchFilter(query: 'mingguan susu'), now: now)), ['b']);
    expect(ids(filterCards(cards, {}, const SearchFilter(query: 'susu bank'), now: now)), isEmpty);
    expect(ids(filterCards(cards, {}, const SearchFilter(query: '  LISTRIK  '), now: now)), ['a']);
  });

  test('title matches rank before description matches', () {
    final list = [
      card('x', 'Catatan', desc: 'ada kata bank di sini'),
      card('y', 'Bank sampah'),
    ];
    expect(ids(filterCards(list, {}, const SearchFilter(query: 'bank'), now: now)), ['y', 'x']);
  });

  test('showDone includes finished cards', () {
    final r = filterCards(cards, {}, const SearchFilter(showDone: true), now: now);
    expect(ids(r), contains('e'));
  });

  test('pinned only', () {
    expect(ids(filterCards(cards, {}, const SearchFilter(pinnedOnly: true), now: now)), ['c']);
  });

  test('due filters', () {
    expect(ids(filterCards(cards, {}, const SearchFilter(due: DueFilter.overdue), now: now)), ['c']);
    expect(ids(filterCards(cards, {}, const SearchFilter(due: DueFilter.today), now: now)), ['c', 'd']);
    expect(ids(filterCards(cards, {}, const SearchFilter(due: DueFilter.hasDue), now: now)), ['c', 'd']);
  });

  test('label filter is case-insensitive and combines with the query', () {
    final labels = {
      'a': [label('Penting')],
      'b': [label('penting'), label('Dapur')],
    };
    expect(ids(filterCards(cards, labels, const SearchFilter(labelName: 'PENTING'), now: now)), ['a', 'b']);
    expect(ids(filterCards(cards, labels, const SearchFilter(labelName: 'dapur'), now: now)), ['b']);
    expect(ids(filterCards(cards, labels, const SearchFilter(labelName: 'penting', query: 'susu'), now: now)), ['b']);
    expect(ids(filterCards(cards, labels, const SearchFilter(labelName: 'tidak ada'), now: now)), isEmpty);
  });

  test('copyWith can clear the label', () {
    const f = SearchFilter(labelName: 'x');
    expect(f.copyWith(labelName: () => null).labelName, isNull);
    expect(f.copyWith(query: 'a').labelName, 'x');
  });
}

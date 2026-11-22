import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';
import 'package:nudge/core/nag/nag_scheduler.dart';
import 'package:nudge/core/theme/tokens.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryNotificationGateway gateway;

  Future<(AppDatabase, Repository, String)> openCard(WidgetTester tester) async {
    gateway = InMemoryNotificationGateway();
    final db = await pumpNudge(tester, gateway: gateway);
    final repo = Repository(db);
    final board = await repo.createBoard('Rumah');
    final list = await repo.createList(board, 'Todo');
    final card = await repo.createCard(list, 'Beli susu');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beli susu'));
    await tester.pumpAndSettle();
    return (db, repo, card);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('pin a card: a sticky notification appears, unpin removes it',
      (tester) async {
    final (db, _, cardId) = await openCard(tester);
    expect(gateway.stickies, isEmpty);

    await tester.tap(find.byKey(const Key('pin-toggle')));
    await tester.pumpAndSettle();
    await settle(tester);

    final card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.pinned, isTrue);
    expect(gateway.stickies.length, 1);
    expect(gateway.stickies.single.title, 'Beli susu');
    expect(gateway.stickies.single.body, 'Rumah › Todo');

    await tester.tap(find.byKey(const Key('pin-toggle')));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(gateway.stickies, isEmpty);
  });

  testWidgets('sticky color can be changed and is used by the tile',
      (tester) async {
    final (db, _, cardId) = await openCard(tester);
    await tester.tap(find.byKey(const Key('pin-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sticky-mint')));
    await tester.pumpAndSettle();
    final card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.stickyColor, 'mint');

    await tester.pageBack();
    await tester.pumpAndSettle();
    final tile = tester.widget<Material>(find
        .ancestor(of: find.text('Beli susu'), matching: find.byType(Material))
        .first);
    expect(tile.color, StickyColors.byName('mint').fill);
  });

  testWidgets('checklist progress shows on the sticky note', (tester) async {
    final (_, repo, cardId) = await openCard(tester);
    await repo.addChecklistItem(cardId, 'Susu');
    final b = await repo.addChecklistItem(cardId, 'Roti');
    await repo.updateCard(cardId, pinned: true);
    await settle(tester);
    expect(gateway.stickies.single.body, '0/2 selesai · Rumah › Todo');

    await repo.setChecklistItemDone(b, true);
    await settle(tester);
    expect(gateway.stickies.single.body, '1/2 selesai · Rumah › Todo');
  });

  testWidgets('completing a pinned card removes its sticky note',
      (tester) async {
    final (_, repo, cardId) = await openCard(tester);
    await repo.updateCard(cardId, pinned: true);
    await settle(tester);
    expect(gateway.stickies.length, 1);

    await repo.setCardCompleted(cardId, true);
    await settle(tester);
    expect(gateway.stickies, isEmpty);
  });

  testWidgets('at most 6 sticky notes are shown', (tester) async {
    final (_, repo, _) = await openCard(tester);
    final boards = await repo.watchBoards().first;
    final lists = await repo.watchLists(boards.single.id).first;
    for (var i = 0; i < 8; i++) {
      final id = await repo.createCard(lists.single.id, 'Catatan $i');
      await repo.updateCard(id, pinned: true);
    }
    await NagScheduler(repo, gateway).rescheduleAll();
    expect(gateway.stickies.length, NagScheduler.maxSticky);
  });
}

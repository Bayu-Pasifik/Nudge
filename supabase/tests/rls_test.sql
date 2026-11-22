-- pgTAP tests for row level security. Run with `supabase test db`.
-- NOTE: written alongside the migration but not executed in the original
-- development environment (no Docker / Supabase CLI available there).
begin;
select plan(9);

-- Two users.
insert into auth.users (id, instance_id, aud, role, email)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'a@example.com'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'b@example.com');

-- User A creates a board, list and card.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

insert into public.boards (id, title, created_at, updated_at)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'A board', now(), now());
insert into public.lists (id, board_id, title, created_at, updated_at)
values ('aaaaaaaa-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'A list', now(), now());
insert into public.cards (id, list_id, board_id, title, created_at, updated_at)
values ('aaaaaaaa-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'A card', now(), now());

select is((select count(*)::int from public.cards), 1, 'owner sees own card');

-- User B sees nothing of A.
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is((select count(*)::int from public.boards), 0, 'other user sees no boards');
select is((select count(*)::int from public.cards), 0, 'other user sees no cards');

-- B cannot update or delete A's rows (they are invisible).
update public.cards set title = 'hacked' where id = 'aaaaaaaa-0000-0000-0000-000000000003';
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select is((select title from public.cards where id = 'aaaaaaaa-0000-0000-0000-000000000003'), 'A card', 'other user cannot update');

-- B cannot attach a list to A's board even with the right UUID.
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select throws_ok(
  $$insert into public.lists (id, board_id, title, created_at, updated_at)
    values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'sneaky', now(), now())$$,
  '42501',
  null,
  'cannot attach a list to another user''s board'
);

-- B cannot write a row owned by A.
select throws_ok(
  $$insert into public.boards (id, user_id, title, created_at, updated_at)
    values ('bbbbbbbb-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'spoof', now(), now())$$,
  '42501',
  null,
  'cannot insert a row for another user'
);

-- Completing a card settles its reminders (trigger).
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
insert into public.reminders (id, card_id, remind_at, created_at, updated_at)
values ('aaaaaaaa-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000003', now(), now(), now());
update public.cards set completed_at = now(), updated_at = now()
 where id = 'aaaaaaaa-0000-0000-0000-000000000003';
select is(
  (select state from public.reminders where id = 'aaaaaaaa-0000-0000-0000-000000000004'),
  'done',
  'completing the card settles its reminders'
);

-- server_updated_at is stamped by the server and moves forward on update.
select ok(
  (select server_updated_at >= created_at from public.cards where id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  'server_updated_at is stamped'
);

-- A stale write (older client updated_at) must not overwrite a newer row.
update public.cards set title = 'stale', updated_at = now() - interval '1 day'
 where id = 'aaaaaaaa-0000-0000-0000-000000000003';
select isnt(
  (select title from public.cards where id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  'stale',
  'stale writes are ignored (last-write-wins)'
);

select * from finish();
rollback;

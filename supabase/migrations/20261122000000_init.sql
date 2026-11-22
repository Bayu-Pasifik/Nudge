-- Nudge: initial schema.
-- Mirrors the local (drift) schema. Every table carries user_id so row level
-- security stays a single cheap equality check and Realtime can filter on it.
--
-- Sync model: clients are the source of truth for their own writes
-- (last-write-wins on `updated_at`, which clients set). `server_updated_at` is
-- stamped by the server on every write and is the cursor clients pull with.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------- helpers

-- Last-write-wins guard + pull cursor:
--  * a write whose client `updated_at` is older than the stored row is a stale
--    write from a device that was offline; it is ignored (the row is returned
--    unchanged and the device picks up the winner on its next pull);
--  * otherwise `server_updated_at` is stamped so clients can pull "everything
--    since X".
create or replace function public.stamp_server_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    return old;
  end if;
  new.server_updated_at = now();
  return new;
end;
$$;

-- ----------------------------------------------------------------- tables

create table public.boards (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  title text not null,
  color bigint not null default 4282400731,
  "position" double precision not null default 0,
  archived_at timestamptz,
  last_opened_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.lists (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  board_id uuid not null references public.boards (id) on delete cascade,
  title text not null,
  "position" double precision not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.cards (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  list_id uuid not null references public.lists (id) on delete cascade,
  board_id uuid not null references public.boards (id) on delete cascade,
  title text not null,
  description text not null default '',
  due_at timestamptz,
  "position" double precision not null default 0,
  completed_at timestamptz,
  archived_at timestamptz,
  pinned boolean not null default false,
  sticky_color text not null default 'yellow',
  auto_complete_on_checklist boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.checklist_items (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  card_id uuid not null references public.cards (id) on delete cascade,
  text text not null,
  done boolean not null default false,
  done_at timestamptz,
  "position" double precision not null default 0,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.labels (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  board_id uuid not null references public.boards (id) on delete cascade,
  name text not null,
  color bigint not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.card_labels (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  card_id uuid not null references public.cards (id) on delete cascade,
  label_id uuid not null references public.labels (id) on delete cascade,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.reminders (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  card_id uuid not null references public.cards (id) on delete cascade,
  remind_at timestamptz not null,
  repeat_rule text check (repeat_rule in ('daily', 'weekly', 'monthly')),
  nag_enabled boolean not null default true,
  nag_interval_minutes integer not null default 10 check (nag_interval_minutes between 1 and 1440),
  nag_max_count integer check (nag_max_count is null or nag_max_count > 0),
  escalation text,
  quiet_start_minute integer check (quiet_start_minute between 0 and 1439),
  quiet_end_minute integer check (quiet_end_minute between 0 and 1439),
  snoozed_until timestamptz,
  nag_count integer not null default 0,
  last_nag_at timestamptz,
  state text not null default 'scheduled'
    check (state in ('scheduled', 'nagging', 'done', 'missed')),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

-- One row per user; created lazily by the client.
create table public.user_settings (
  user_id uuid primary key references auth.users (id) on delete cascade default auth.uid(),
  default_nag_interval integer not null default 10,
  default_escalation text,
  quiet_start_minute integer,
  quiet_end_minute integer,
  timezone text,
  theme text not null default 'system',
  locale text not null default 'id',
  updated_at timestamptz not null default now(),
  server_updated_at timestamptz not null default now()
);

-- Push tokens, one per installed app instance (used by the nag dispatcher).
create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  platform text not null check (platform in ('android', 'ios', 'windows', 'macos', 'linux')),
  push_token text not null,
  last_seen_at timestamptz not null default now(),
  unique (user_id, push_token)
);

-- ---------------------------------------------------------------- indexes

create index boards_user_cursor on public.boards (user_id, server_updated_at);
create index lists_user_cursor on public.lists (user_id, server_updated_at);
create index cards_user_cursor on public.cards (user_id, server_updated_at);
create index checklist_items_user_cursor on public.checklist_items (user_id, server_updated_at);
create index labels_user_cursor on public.labels (user_id, server_updated_at);
create index card_labels_user_cursor on public.card_labels (user_id, server_updated_at);
create index reminders_user_cursor on public.reminders (user_id, server_updated_at);
create index cards_list on public.cards (list_id, "position");
create index lists_board on public.lists (board_id, "position");
create index reminders_card on public.reminders (card_id);
create index reminders_due on public.reminders (remind_at) where deleted_at is null and state <> 'done';

-- ---------------------------------------------------------------- triggers

do $$
declare t text;
begin
  foreach t in array array[
    'boards', 'lists', 'cards', 'checklist_items', 'labels', 'card_labels',
    'reminders', 'user_settings'
  ] loop
    execute format(
      'create trigger %I_stamp before insert or update on public.%I
         for each row execute function public.stamp_server_updated_at()',
      t, t
    );
  end loop;
end $$;

-- Completing a card settles its reminders so nagging stops on every device
-- even if the completing client never got to write the reminder rows.
create or replace function public.settle_reminders_on_complete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.completed_at is not null and old.completed_at is null then
    update public.reminders
       set state = 'done', updated_at = greatest(updated_at, new.updated_at)
     where card_id = new.id and deleted_at is null and state <> 'done';
  end if;
  return new;
end;
$$;

create trigger cards_settle_reminders
  after update of completed_at on public.cards
  for each row execute function public.settle_reminders_on_complete();

-- --------------------------------------------------- row level security

do $$
declare t text;
begin
  foreach t in array array[
    'boards', 'lists', 'cards', 'checklist_items', 'labels', 'card_labels',
    'reminders', 'user_settings', 'devices'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I on public.%I for all to authenticated
         using (user_id = (select auth.uid()))
         with check (user_id = (select auth.uid()))',
      t || '_owner', t
    );
  end loop;
end $$;

-- A foreign key check bypasses RLS, so without this a client could attach its
-- rows to another user's board/list/card just by knowing the UUID. Restrictive
-- policies are AND-ed with the owner policy above.
create policy lists_parent on public.lists as restrictive for all to authenticated
  using (true)
  with check (exists (
    select 1 from public.boards b
     where b.id = board_id and b.user_id = (select auth.uid())));

create policy cards_parent on public.cards as restrictive for all to authenticated
  using (true)
  with check (exists (
    select 1 from public.lists l
     where l.id = list_id and l.user_id = (select auth.uid())));

create policy checklist_items_parent on public.checklist_items as restrictive for all to authenticated
  using (true)
  with check (exists (
    select 1 from public.cards c
     where c.id = card_id and c.user_id = (select auth.uid())));

create policy labels_parent on public.labels as restrictive for all to authenticated
  using (true)
  with check (exists (
    select 1 from public.boards b
     where b.id = board_id and b.user_id = (select auth.uid())));

create policy card_labels_parent on public.card_labels as restrictive for all to authenticated
  using (true)
  with check (
    exists (select 1 from public.cards c
             where c.id = card_id and c.user_id = (select auth.uid()))
    and exists (select 1 from public.labels l
             where l.id = label_id and l.user_id = (select auth.uid())));

create policy reminders_parent on public.reminders as restrictive for all to authenticated
  using (true)
  with check (exists (
    select 1 from public.cards c
     where c.id = card_id and c.user_id = (select auth.uid())));

-- ---------------------------------------------------------------- realtime

alter publication supabase_realtime add table
  public.boards, public.lists, public.cards, public.checklist_items,
  public.labels, public.card_labels, public.reminders;

-- ------------------------------------------------------------- privileges

grant usage on schema public to authenticated;

grant select, insert, update, delete on
  public.boards, public.lists, public.cards, public.checklist_items,
  public.labels, public.card_labels, public.reminders,
  public.user_settings, public.devices
to authenticated;

-- Signed-out (anon) clients get nothing: every table is private.
revoke all on
  public.boards, public.lists, public.cards, public.checklist_items,
  public.labels, public.card_labels, public.reminders,
  public.user_settings, public.devices
from anon;

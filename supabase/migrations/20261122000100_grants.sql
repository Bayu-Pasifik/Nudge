-- Table privileges for signed-in users.
--
-- RLS decides *which rows* a user may touch, but Postgres still needs the
-- table-level privilege first. Newer Supabase projects no longer grant these
-- automatically, which shows up as "permission denied for table ...".
-- Safe to run more than once.

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

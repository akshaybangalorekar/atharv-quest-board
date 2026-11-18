-- ============================================================================
-- 065_account_events.sql
-- A quiet record of account changes, so a password set by a parent is visible
-- rather than invisible.
-- Run after 064. Safe to re-run.
-- ============================================================================

create table if not exists account_events (
  id bigserial primary key,
  student_id uuid references auth.users(id) on delete cascade,
  by_user uuid references auth.users(id) on delete set null,
  what text not null,
  at timestamptz default now()
);
alter table account_events enable row level security;
drop policy if exists "own account events" on account_events;
create policy "own account events" on account_events for select to authenticated
  using (student_id = (select auth.uid()) or is_guardian(student_id));

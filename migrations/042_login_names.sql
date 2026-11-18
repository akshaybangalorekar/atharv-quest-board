-- ============================================================================
-- 042_login_names.sql
-- A name for everyone who signs in, parents included — the child has a profile,
-- the parents are guardians, so the names live in one small table keyed to the
-- auth user rather than to a profile row.
-- Run after 041. Safe to re-run.
-- ============================================================================

create table if not exists login_names (
  name text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now()
);
alter table login_names enable row level security;
-- nobody reads this from the browser; the login function uses the service role

insert into login_names (name, user_id)
select lower(p.username), p.student_id from profiles p where p.username is not null
on conflict (name) do nothing;

insert into login_names (name, user_id)
select 'pooja', u.id from auth.users u where lower(u.email) like 'pooja%'
on conflict (name) do nothing;

insert into login_names (name, user_id)
select 'akshay', u.id from auth.users u where lower(u.email) like 'akshay%'
on conflict (name) do nothing;

create or replace function username_email(p_name text)
returns text
language sql security definer set search_path = public as $$
  select u.email::text
  from login_names n
  join auth.users u on u.id = n.user_id
  where n.name = lower(trim(p_name))
  limit 1;
$$;
revoke all on function username_email(text) from public, anon, authenticated;

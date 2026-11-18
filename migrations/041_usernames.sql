-- ============================================================================
-- 041_usernames.sql
-- A short name to sign in with, instead of a long email.
-- The name lives on the profile; the email is never handed to the browser —
-- a small function on the server swaps one for the other at the moment of
-- signing in.
-- Run after 040. Safe to re-run.
-- ============================================================================

alter table profiles add column if not exists username text;

create unique index if not exists profiles_username_uniq
  on profiles (lower(username)) where username is not null;

-- the three of them, by the names they use
update profiles set username = 'atharv' where lower(name) like 'atharv%';
update profiles set username = 'pooja'  where lower(name) like 'pooja%';
update profiles set username = 'akshay' where lower(name) like 'akshay%';

-- a parent can give anyone a name later
create or replace function set_username(p_student uuid, p_name text)
returns text
language plpgsql security definer set search_path = public as $$
begin
  if not is_parent() then
    raise exception 'only a parent can change a name' using errcode = '42501';
  end if;
  if p_name !~ '^[a-z0-9._-]{3,20}$' then
    raise exception 'use 3 to 20 letters or numbers' using errcode = '22023';
  end if;
  update profiles set username = lower(p_name) where student_id = p_student;
  return lower(p_name);
end $$;

-- what the login function reads; not callable from the browser
create or replace function username_email(p_name text)
returns text
language sql security definer set search_path = public as $$
  select u.email::text
  from profiles p
  join auth.users u on u.id = p.student_id
  where lower(p.username) = lower(trim(p_name))
  limit 1;
$$;
revoke all on function username_email(text) from public, anon, authenticated;

-- ============================================================================
-- 043_login_lookup.sql
-- Let the app turn a name into an account, so signing in with a name needs no
-- cold-starting function in the middle. The app asks for the email, then signs
-- in the ordinary way, exactly as it would if the email had been typed.
--
-- The trade: anyone who knows one of these three names can retrieve that
-- account's email address. On a private family app with three known names that
-- is a fair price for a login that always answers; if that ever matters, the
-- grant below is the one line to revoke.
-- Run after 042. Safe to re-run.
-- ============================================================================

create or replace function login_email(p_name text)
returns text
language sql security definer set search_path = public as $$
  select u.email::text
  from login_names n
  join auth.users u on u.id = n.user_id
  where n.name = lower(trim(p_name))
  limit 1;
$$;

revoke all on function login_email(text) from public;
grant execute on function login_email(text) to anon, authenticated;

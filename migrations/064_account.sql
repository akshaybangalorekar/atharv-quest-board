-- ============================================================================
-- 064_account.sql
-- A person can change their own sign-in name, and their own password. The name
-- is what they type instead of a long email; the password is handled by the
-- auth service itself.
-- Run after 063. Safe to re-run.
-- ============================================================================

create or replace function set_username(p_name text)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_name text := lower(btrim(coalesce(p_name,'')));
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if v_name !~ '^[a-z0-9][a-z0-9._-]{2,19}$' then
    raise exception 'A name is 3 to 20 characters: letters, numbers, dots, dashes.' using errcode = '22023';
  end if;
  if exists (select 1 from login_names where name = v_name and user_id <> v) then
    raise exception 'That name is already taken.' using errcode = '23505';
  end if;

  delete from login_names where user_id = v and name <> v_name;
  insert into login_names (name, user_id) values (v_name, v)
    on conflict (name) do update set user_id = excluded.user_id;

  update profiles set username = v_name where student_id = v;

  return json_build_object('name', v_name);
end $$;

grant execute on function set_username(text) to authenticated;

create or replace function my_account()
returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'name', (select name from login_names where user_id = auth.uid() limit 1),
    'email', (select email from auth.users where id = auth.uid())
  );
$$;

grant execute on function my_account() to authenticated;

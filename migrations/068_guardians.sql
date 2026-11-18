-- ============================================================================
-- 068_guardians.sql
-- Which adults can see this child, and a way to remove one of them.
-- Run after 067. Safe to re-run.
-- ============================================================================

create or replace function list_guardians()
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
    'parent_id', g.parent_id,
    'name', (select name from login_names where user_id = g.parent_id limit 1),
    'email', (select email from auth.users where id = g.parent_id)
  ) order by g.created_at), '[]'::json)
  from guardians g
  where g.student_id = coalesce(viewing_student(), auth.uid())
    and is_guardian(g.student_id);
$$;

grant execute on function list_guardians() to authenticated;

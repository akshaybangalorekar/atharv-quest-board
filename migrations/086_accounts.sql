-- ============================================================================
-- 086_accounts.sql
-- One list of everyone who can sign in: every parent, every child, who you are,
-- and how much work sits behind each child. Used by the parent screen so an
-- account can be removed without guessing what is inside it.
-- Run after 085. Safe to re-run.
-- ============================================================================

create or replace function list_accounts()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_child uuid := viewing_student();
  v_out json;
begin
  if not is_parent() then
    raise exception 'only a parent can see this' using errcode = '42501';
  end if;

  select coalesce(json_agg(row_to_json(t) order by t.role, t.name), '[]'::json) into v_out
  from (
    select
      u.id as user_id,
      coalesce((select name from login_names where user_id = u.id limit 1), split_part(u.email,'@',1)) as name,
      u.email,
      case when exists (select 1 from guardians g2 where g2.parent_id = u.id) then 'parent' else 'child' end as role,
      (u.id = v_me) as is_you,
      (u.id = v_child) as is_child,
      (u.id = v_me or exists (select 1 from guardians g where g.parent_id = u.id and g.student_id = v_child)) as sees_child,
      (select count(*) from attempts a where a.student_id = u.id) as questions_answered,
      (select count(*) from chapter_progress cp where cp.student_id = u.id and coalesce(cp.quiz_best,0) >= 80) as chapters_mastered,
      (select count(*) from sessions s where s.student_id = u.id) as sessions,
      (select coalesce(max(created_at)::date, null) from attempts a where a.student_id = u.id) as last_active
    from auth.users u
    where exists (select 1 from guardians g3 where g3.parent_id = u.id)
       or u.id = v_child
       or u.id = v_me
  ) t;

  return json_build_object('accounts', v_out);
end $$;

grant execute on function list_accounts() to authenticated;

-- what a child has behind them, in plain words
create or replace function child_work_status(p_child uuid default null)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_child uuid := coalesce(p_child, viewing_student());
  v_out json;
begin
  if not (is_guardian(v_child) or v_child = auth.uid()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  select json_build_object(
    'name', (select name from profiles where student_id = v_child),
    'questions_answered', (select count(*) from attempts where student_id = v_child),
    'right', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                       from attempts where student_id = v_child), 0),
    'chapters_mastered', (select count(*) from chapter_progress
                          where student_id = v_child and coalesce(quiz_best,0) >= 80),
    'chapters_started', (select count(*) from chapter_progress where student_id = v_child),
    'sessions', (select count(*) from sessions where student_id = v_child),
    'tests', (select count(*) from exam_mocks where student_id = v_child),
    'journal', (select count(*) from session_notes where student_id = v_child),
    'first_day', (select min(created_at)::date from attempts where student_id = v_child),
    'last_day', (select max(created_at)::date from attempts where student_id = v_child)
  ) into v_out;

  return v_out;
end $$;

grant execute on function child_work_status(uuid) to authenticated;

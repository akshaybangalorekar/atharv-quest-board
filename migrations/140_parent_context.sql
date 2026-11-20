-- 140_parent_context.sql — parent_context had drifted and was throwing on json || json,
-- so every parent turn reached the coach with an empty record and she denied having any material.
create or replace function parent_context()
returns json language plpgsql security definer set search_path = public as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;
  return (truth()::jsonb || jsonb_build_object(
    'student_id', v,
    'student', (select name from profiles where student_id = v),
    'xp', coalesce((select xp from profiles where student_id = v), 0),
    'streak', coalesce((select streak_days from profiles where student_id = v), 0),
    'attempts_total', (select count(*) from attempts where student_id = v),
    'attempts_7d', (select count(*) from attempts where student_id = v and created_at > now() - interval '7 days'),
    'accuracy_7d', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                     from attempts where student_id = v and created_at > now() - interval '7 days'), 0),
    'sessions_7d', (select count(*) from sessions where student_id = v and created_at > now() - interval '7 days'),
    'readiness', readiness_by_school(),
    'banks', (truth()->'content'->'banks'),
    'weak', (truth()->'weak'),
    'recent_tests', (truth()->'tests'->'last'),
    'tough', (truth()->'tough_topics')))::json;
end $$;
grant execute on function parent_context() to authenticated;

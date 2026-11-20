
create or replace function truth_families(v uuid)
returns json
language sql security definer set search_path = public as $$
  with today as (select (now() at time zone 'Australia/Melbourne')::date as d),
  base as (
    select s.family, s.exam as label, s.schools, s.items, s.practised, s.verdict, s.message
    from v_exam_readiness s
  ),
  dates as (
    select b.*,
           (select min(c.sits_on) from exam_calendar c, today
             where c.student_id = v and c.sits_on >= today.d
               and (lower(c.exam) like '%' || lower(b.label) || '%'
                    or (b.family = 'edutest' and lower(c.exam) like '%elms%'))) as exam_on
    from base b
  ),
  tr as (   -- one topic_readiness call per family
    select d.*, topic_readiness(d.family) as topics from dates d
  ),
  tm as (   -- one timetable call for the whole set
    select json_agg(x) as j from json_array_elements(timetable()) x
  )
  select coalesce(json_agg(row_to_json(f) order by f.days_left nulls last), '[]'::json)
  from (
    select t.family, t.label, t.schools, t.items, t.practised, t.verdict, t.message, t.exam_on,
           t.exam_on - (select d from today) as days_left,
           (select count(*) from json_array_elements(t.topics) k) as topics_all,
           (select count(*) from json_array_elements(t.topics) k where (k->>'preparedness')::int >= 60) as topics_done,
           (select count(*) from json_array_elements(t.topics) k where (k->>'preparedness')::int > 0) as topics_started,
           (select x->'rows' from json_array_elements((select j from tm)) x
             where lower(x->>'label') = lower(t.label)) as rows,
           (select (x->>'behind')::int from json_array_elements((select j from tm)) x
             where lower(x->>'label') = lower(t.label)) as behind,
           (select (x->>'due_by_now')::int from json_array_elements((select j from tm)) x
             where lower(x->>'label') = lower(t.label)) as due_by_now,
           (select coalesce(json_agg(row_to_json(sc)), '[]'::json) from (
              select y->>'school' as school, y->>'calendar_name' as calendar_name,
                     y->>'sits_on' as sits_on, (y->>'sits_minutes')::int as sits_minutes,
                     (y->>'measured_minutes')::int as measured_minutes,
                     y->>'headline' as headline, y->'sections' as sections
              from json_array_elements((select j from tm)) x,
                   json_array_elements(x->'schools') y
              where lower(x->>'label') = lower(t.label)) sc) as schools_list
    from tr t
  ) f;
$$;

grant execute on function truth_families(uuid) to authenticated;


grant execute on function truth() to authenticated;

-- the parent's context is the truth, plus the few things only a parent screen needs
create or replace function parent_context()
returns json
language plpgsql security definer set search_path = public as $$
declare v uuid := coalesce(viewing_student(), auth.uid());
begin
  return truth() || json_build_object(
    'student_id', v,
    'student', (select name from profiles where student_id = v),
    'xp', coalesce((select xp from profiles where student_id = v), 0),
    'streak', coalesce((select streak_days from profiles where student_id = v), 0),
    'attempts_total', (select count(*) from attempts where student_id = v),
    'attempts_7d', (select count(*) from attempts where student_id = v
                     and created_at > now() - interval '7 days'),
    'accuracy_7d', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                     from attempts where student_id = v and created_at > now() - interval '7 days'), 0),
    'sessions_7d', (select count(*) from sessions where student_id = v
                     and created_at > now() - interval '7 days'),
    'readiness', readiness_by_school(),
    'banks', (truth()->'content'->'banks'),
    'weak', (truth()->'weak'),
    'recent_tests', (truth()->'tests'->'last'),
    'tough', (truth()->'tough_topics')
  );
end $$;
grant execute on function parent_context() to authenticated;

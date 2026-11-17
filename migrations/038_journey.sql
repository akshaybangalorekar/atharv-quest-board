-- ============================================================================
-- 038_journey.sql
-- The flight plan: where he is in the season, what is coming, how far off it is.
-- One call, everything the chart needs, so the picture is drawn from data and
-- never from guesswork.
-- Run after 037. Safe to re-run.
-- ============================================================================

create or replace function journey()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_start date;
  v_end date;
  v_ms json;
  v_mastered int;
  v_started int;
  v_total int;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  select coalesce(start_date, v_today) into v_start from profiles where student_id = v;
  v_start := coalesce(v_start, v_today);

  -- the season runs from the start date to the last date on the calendar
  select max(sits_on) into v_end from exam_calendar where student_id = v and sits_on >= v_start;
  v_end := coalesce(v_end, v_start + 300);

  select count(*) filter (where coalesce(quiz_best,0) >= 80), count(*) into v_mastered, v_started
  from chapter_progress where student_id = v;
  select count(*) into v_total from chapters where source = 'book';

  -- the stations: every dated thing, plus the two things that have no date
  select coalesce(json_agg(m order by m->>'on'), '[]'::json) into v_ms
  from (
    select json_build_object('name', exam, 'on', sits_on, 'kind', 'exam',
                             'status', date_status) as m
    from exam_calendar where student_id = v and sits_on >= v_start
    union all
    select json_build_object('name', 'Portion complete', 'on', null, 'kind', 'portion', 'status', 'goal')
    union all
    select json_build_object('name', 'Next paper', 'on', null, 'kind', 'mock',
                             'status', case when (mock_due()->>'due') = 'true' then 'due' else 'later' end)
  ) t;

  return json_build_object(
    'today', v_today,
    'start', v_start,
    'end', v_end,
    'day', (v_today - v_start) + 1,
    'days_total', (v_end - v_start) + 1,
    'days_left', greatest(v_end - v_today, 0),
    'portion_pct', case when v_total = 0 then 0 else round(100.0 * v_mastered / v_total) end,
    'chapters_mastered', v_mastered,
    'chapters_total', v_total,
    'chapters_started', v_started,
    'questions', (select count(*) from attempts where student_id = v),
    'accuracy', coalesce((select round(100.0*count(*) filter (where ok)/greatest(count(*),1))
                          from attempts where student_id = v),0),
    'streak', coalesce((select streak_days from profiles where student_id = v),0),
    'next_paper', mock_due(),
    'milestones', v_ms
  );
end $$;

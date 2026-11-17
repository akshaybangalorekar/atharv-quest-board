-- ============================================================================
-- 034_mock_due.sql
-- When a paper is actually worth sitting. The app shows the Mock button only
-- when this says so, so a test is an event rather than a menu item.
-- Run after 033. Safe to re-run.
-- ============================================================================

create or replace function mock_due(p_student uuid default null)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := coalesce(p_student, auth.uid());
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_last date;
  v_since int;
  v_next_exam date;
  v_next_name text;
  v_days_to int;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  select max(taken_at::date) into v_last from exam_mocks
   where student_id = v and kind in ('mock', 'quiz', 'boss', 'gauntlet', 'placement');

  select count(*) into v_since from attempts
   where student_id = v and (v_last is null or created_at::date > v_last);

  select c.sits_on, c.exam into v_next_exam, v_next_name
  from exam_calendar c
  where c.student_id = v and c.sits_on >= v_today
  order by c.sits_on limit 1;

  v_days_to := case when v_next_exam is null then null else v_next_exam - v_today end;

  -- a paper is due when he has done enough since the last one, or when a real
  -- exam is close enough that the rehearsal matters
  if v_last is null and v_since = 0 then
    return json_build_object('due', false, 'why', 'nothing done yet — start with a session, not a test');
  elsif v_days_to is not null and v_days_to <= 21 then
    return json_build_object('due', true, 'why',
      v_next_name || ' is ' || v_days_to || ' days away — time for a full paper');
  elsif v_last is null and v_since >= 12 then
    return json_build_object('due', true, 'why', 'twelve questions in and no test yet — let us see where you stand');
  elsif v_last is not null and v_since >= 16 then
    return json_build_object('due', true, 'why', v_since || ' questions since the last paper');
  else
    return json_build_object('due', false, 'why', 'not yet — keep working, and the paper will come');
  end if;
end $$;

-- the coach knows whether a paper is due, and can say so
create or replace function coach_context()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_chapter int;
  v_out json;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  select chapter into v_chapter from plan_days
   where student_id = v and day = v_today and lane = 'Q' and chapter is not null
   order by seq limit 1;

  select json_build_object(
    'today', v_today,
    'name', (select name from profiles where student_id = v),
    'xp', coalesce((select xp from profiles where student_id = v),0),
    'streak', coalesce((select streak_days from profiles where student_id = v),0),
    'started_on', (select start_date from profiles where student_id = v),
    'days_in', (v_today - coalesce((select start_date from profiles where student_id = v), v_today)) + 1,
    'is_first_day', not exists (select 1 from attempts where student_id = v),
    'sessions_7d', (select count(*) from sessions where student_id = v and day > v_today - 7),
    'days_since_last', (v_today - coalesce((select max(day) from sessions where student_id = v), v_today)),
    'accuracy_7d', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                      from attempts where student_id = v and created_at > now() - interval '7 days'), 0),
    'avg_seconds', coalesce((select round(avg(seconds)) from attempts
                      where student_id = v and seconds is not null and created_at > now() - interval '14 days'), 0),
    'plan', coalesce((select json_agg(json_build_object('lane',lane,'chapter',chapter,
                       'questions',target_questions,'minutes',minutes,'note',note) order by seq)
                      from plan_days where student_id = v and day = v_today), '[]'::json),
    'chapter', v_chapter,
    'chapter_title', (select title from chapters where n = v_chapter),
    'chapter_notes', coalesce((select json_build_object('ideas',ideas) from chapter_notes where chapter = v_chapter), '{}'::json),
    'weak', coalesce((select json_agg(json_build_object('technique',technique,'items',open_items))
                      from v_weak_techniques where student_id = v limit 3), '[]'::json),
    'today_attempts', coalesce((select json_agg(json_build_object('chapter',chapter,'idx',idx,'ok',ok) order by created_at desc)
                      from attempts where student_id = v and created_at >= v_today limit 20), '[]'::json),
    'self_reports', coalesce((select json_agg(json_build_object('day',day,'chapter',chapter,'minutes',minutes,'note',note,'confidence',confidence) order by day desc)
                      from (select * from self_reports where student_id = v order by day desc limit 5) t), '[]'::json),
    'recent_chat', coalesce((select json_agg(json_build_object('role',role,'body',body) order by created_at)
                      from (select * from chat_messages where student_id = v order by created_at desc limit 6) t), '[]'::json),
    'recent_tests', coalesce((select json_agg(json_build_object('kind',kind,'pct',pct,'taken_at',taken_at) order by taken_at desc)
                      from exam_mocks where student_id = v limit 3), '[]'::json),
    'readiness', coalesce((select json_agg(json_build_object('exam',exam,'verdict',verdict,'message',message))
                      from v_exam_readiness), '[]'::json),
    'mock', mock_due(v)
  ) into v_out;
  return v_out;
end $$;

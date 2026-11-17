-- ============================================================================
-- 022_memory.sql
-- What the coach remembers, including the work done away from the app.
-- Run after 021. Safe to re-run.
-- ============================================================================

create table if not exists self_reports (
  id bigserial primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  chapter int,
  from_idx int,
  to_idx int,
  minutes int default 0,
  note text,
  created_at timestamptz default now()
);
alter table self_reports enable row level security;
drop policy if exists "own rows" on self_reports;
create policy "own rows" on self_reports for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "guardian read" on self_reports;
create policy "guardian read" on self_reports for select to authenticated using (is_guardian(student_id));

-- he did some work on paper, without the app: say so, and the coach knows
create or replace function log_self_study(
  p_chapter int default null,
  p_minutes int default 0,
  p_from int default null,
  p_to int default null,
  p_note text default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_day date := (now() at time zone 'Australia/Melbourne')::date;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  insert into self_reports (student_id, day, chapter, from_idx, to_idx, minutes, note)
  values (v, v_day, p_chapter, p_from, p_to, coalesce(p_minutes,0), p_note);

  insert into sessions (student_id, day, lane, minutes, status, note)
  values (v, v_day, 'S', coalesce(p_minutes,0), 'done',
          coalesce('own study' || coalesce(' · ch ' || p_chapter, ''), 'own study'));

  return json_build_object('day', v_day, 'chapter', p_chapter, 'minutes', coalesce(p_minutes,0));
end $$;

-- ---- the coach's memory, rebuilt ----------------------------------------
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
    'last_session', (select last_session_date from profiles where student_id = v),
    'is_first_day', not exists (select 1 from attempts where student_id = v),

    -- how regular he has been
    'sessions_7d', (select count(*) from sessions where student_id = v and day > v_today - 7),
    'sessions_14d', (select count(*) from sessions where student_id = v and day > v_today - 14),
    'days_since_last', (v_today - coalesce((select max(day) from sessions where student_id = v), v_today)),

    -- how fast he is
    'attempts_7d', (select count(*) from attempts where student_id = v and created_at > now() - interval '7 days'),
    'accuracy_7d', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                      from attempts where student_id = v and created_at > now() - interval '7 days'), 0),
    'avg_seconds', coalesce((select round(avg(seconds)) from attempts
                      where student_id = v and seconds is not null and created_at > now() - interval '14 days'), 0),
    'slowest', coalesce((select json_agg(json_build_object('chapter',chapter,'idx',idx,'seconds',seconds) order by seconds desc)
                      from (select chapter, idx, seconds from attempts
                            where student_id = v and seconds is not null order by seconds desc limit 3) t), '[]'::json),

    'plan', coalesce((select json_agg(json_build_object('lane',lane,'chapter',chapter,
                       'questions',target_questions,'minutes',minutes,'note',note) order by seq)
                      from plan_days where student_id = v and day = v_today), '[]'::json),
    'next_session', coalesce((select json_build_object('day',min(day),'note',min(note))
                      from plan_days where student_id = v and day > v_today and lane <> 'R'), '{}'::json),
    'chapter', v_chapter,
    'chapter_title', (select title from chapters where n = v_chapter),
    'chapter_notes', coalesce((select json_build_object('ideas',ideas,'summary',summary)
                      from chapter_notes where chapter = v_chapter), '{}'::json),
    'chapter_status', coalesce((select json_agg(json_build_object('chapter',chapter,'quiz_best',quiz_best,'weak',weak))
                      from chapter_progress where student_id = v), '[]'::json),
    'weak', coalesce((select json_agg(json_build_object('technique',technique,'items',open_items,'misses',misses))
                      from v_weak_techniques where student_id = v limit 3), '[]'::json),

    -- what actually happened, and what he said he did
    'today_attempts', coalesce((select json_agg(json_build_object('chapter',chapter,'idx',idx,'ok',ok) order by created_at desc)
                      from attempts where student_id = v and created_at >= v_today limit 20), '[]'::json),
    'last_attempts', coalesce((select json_agg(json_build_object('chapter',chapter,'idx',idx,'ok',ok,'seconds',seconds) order by created_at desc)
                      from (select * from attempts where student_id = v order by created_at desc limit 8) t), '[]'::json),
    'self_reports', coalesce((select json_agg(json_build_object('day',day,'chapter',chapter,'from',from_idx,'to',to_idx,'minutes',minutes,'note',note) order by day desc)
                      from (select * from self_reports where student_id = v order by day desc limit 5) t), '[]'::json),
    'recent_chat', coalesce((select json_agg(json_build_object('role',role,'body',body) order by created_at)
                      from (select * from chat_messages where student_id = v order by created_at desc limit 6) t), '[]'::json),

    'recent_tests', coalesce((select json_agg(json_build_object('kind',kind,'pct',pct,'taken_at',taken_at) order by taken_at desc)
                      from exam_mocks where student_id = v limit 3), '[]'::json),
    'readiness', coalesce((select json_agg(json_build_object('exam',exam,'verdict',verdict,'message',message))
                      from v_exam_readiness), '[]'::json)
  ) into v_out;
  return v_out;
end $$;

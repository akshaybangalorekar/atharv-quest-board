-- ============================================================================
-- 036_coach_brief.sql
-- The coach's standing memory.
--
-- A hosted model cannot be retrained from an app, and it does not need to be:
-- what it needs is to be told, every single time it speaks, the rules and the
-- boy's current standing. So once a night a job assembles a brief — where he is
-- in the programme, what he has mastered, what is weak, what is next, what is
-- on his board — and every message he gets from then on is written with that
-- brief in front of the model. The model still forgets; the brief does not.
--
-- Run after 035. Safe to re-run.
-- ============================================================================

create table if not exists coach_brief (
  student_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  brief jsonb not null,
  built_at timestamptz default now(),
  primary key (student_id, day)
);
alter table coach_brief enable row level security;
drop policy if exists "own brief" on coach_brief;
create policy "own brief" on coach_brief for select to authenticated
  using (student_id = (select auth.uid()) or is_guardian(student_id));

-- the same list, for a named student, so the nightly job can build anyone's brief
create or replace function board_pending_for(p_student uuid)
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object('chapter', chapter, 'technique', technique) order by chapter), '[]'::json)
  from (
    select c.n as chapter, trim(both '"' from idea::text) as technique
    from chapters c
    join chapter_notes n on n.chapter = c.n
    cross join lateral jsonb_array_elements(n.ideas) idea
    where c.n between 1 and 24
      and exists (select 1 from attempts a where a.student_id = p_student and a.chapter = c.n)
      and not exists (select 1 from formula_board f
                      where f.student_id = p_student and f.chapter = c.n
                        and f.technique = trim(both '"' from idea::text))
  ) t;
$$;

create or replace function build_coach_brief(p_student uuid default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v uuid := coalesce(p_student, auth.uid());
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_out jsonb;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  select jsonb_build_object(
    'built_for', v_today,
    'name', (select name from profiles where student_id = v),
    'day_of_programme', (v_today - coalesce((select start_date from profiles where student_id = v), v_today)) + 1,
    'is_first_day', not exists (select 1 from attempts where student_id = v),
    'placed', not placement_due(v),

    -- what he has actually done
    'questions_answered', (select count(*) from attempts where student_id = v),
    'accuracy_all', coalesce((select round(100.0*count(*) filter (where ok)/greatest(count(*),1)) from attempts where student_id = v),0),
    'accuracy_7d', coalesce((select round(100.0*count(*) filter (where ok)/greatest(count(*),1))
                        from attempts where student_id = v and created_at > now() - interval '7 days'),0),
    'questions_7d', (select count(*) from attempts where student_id = v and created_at > now() - interval '7 days'),
    'avg_seconds', coalesce((select round(avg(seconds)) from attempts where student_id = v and seconds is not null),0),
    'sessions_7d', (select count(*) from sessions where student_id = v and day > v_today - 7),
    'days_since_last_session', (v_today - coalesce((select max(day) from sessions where student_id = v), v_today)),

    -- the book
    'chapters_started', (select count(*) from chapter_progress where student_id = v),
    'chapters_mastered', coalesce((select count(*) from chapter_progress where student_id = v and coalesce(quiz_best,0) >= 80),0),
    'chapter_now', (select chapter from plan_days where student_id = v and day = v_today and chapter is not null order by seq limit 1),
    'next_chapter', (select min(chapter) from chapter_progress where student_id = v and coalesce(quiz_best,0) < 80),

    -- what to work on
    'weak_techniques', coalesce((select jsonb_agg(jsonb_build_object('technique', technique, 'open', open_items))
                                 from (select * from v_weak_techniques where student_id = v order by open_items desc limit 5) t), '[]'::jsonb),
    'board_pending', board_pending_for(v),
    'tests', coalesce((select jsonb_agg(jsonb_build_object('kind',kind,'pct',pct,'on',taken_at::date) order by taken_at desc)
                       from (select * from exam_mocks where student_id = v order by taken_at desc limit 5) t), '[]'::jsonb),
    'mock_due', mock_due(v),
    'next_exam', (select jsonb_build_object('exam',exam,'on',sits_on,'days',sits_on - v_today)
                  from exam_calendar where student_id = v and sits_on >= v_today order by sits_on limit 1),
    'last_note', (select jsonb_build_object('day',day,'title',title) from session_notes
                  where student_id = v order by day desc, created_at desc limit 1)
  ) into v_out;

  return v_out;
end $$;

-- write tonight's brief for every student
create or replace function refresh_coach_briefs()
returns int
language plpgsql security definer set search_path = public as $$
declare n int := 0; r record;
begin
  for r in select student_id from profiles loop
    insert into coach_brief (student_id, day, brief)
    values (r.student_id, (now() at time zone 'Australia/Melbourne')::date, build_coach_brief(r.student_id))
    on conflict (student_id, day) do update set brief = excluded.brief, built_at = now();
    n := n + 1;
  end loop;
  return n;
end $$;

-- and tonight's brief is there the moment he opens the app, before any job runs
create or replace function current_coach_brief()
returns jsonb
language sql security definer set search_path = public as $$
  select coalesce(
    (select brief from coach_brief
      where student_id = auth.uid()
      order by day desc limit 1),
    build_coach_brief());
$$;

-- midnight in Melbourne: pg_cron runs in UTC, so 13:05 UTC is just after
-- midnight in Melbourne during daylight saving, and 14:05 outside it. The brief
-- stamps the Melbourne date itself, so an hour either way changes nothing.
select cron.unschedule('coach-brief-nightly')
 where exists (select 1 from cron.job where jobname = 'coach-brief-nightly');
select cron.schedule('coach-brief-nightly', '5 13 * * *', $$select refresh_coach_briefs();$$);

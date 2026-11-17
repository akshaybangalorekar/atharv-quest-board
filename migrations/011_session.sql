-- ============================================================================
-- 011_session.sql
-- What the app needs to actually run a session: hand out the next questions,
-- start a test, and nothing else.
-- Run after 010. Safe to re-run.
-- ============================================================================

-- ---- the next questions in a chapter --------------------------------------
-- Skips anything he has already answered correctly; wrong answers come back.
create or replace function next_in_chapter(p_chapter int, p_count int default 4)
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(row_to_json(t) order by t.idx), '[]'::json)
  from (
    select p.chapter, p.idx, p.prompt, p.difficulty
    from problems p
    where p.chapter = p_chapter
      and not exists (
        select 1 from attempts a
        where a.student_id = auth.uid()
          and a.chapter = p.chapter and a.idx = p.idx and a.ok
      )
    order by p.idx
    limit greatest(1, coalesce(p_count, 4))
  ) t;
$$;

-- ---- the questions due for review today -----------------------------------
create or replace function due_reviews(p_count int default 5)
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  from (
    select p.chapter, p.idx, p.prompt, p.difficulty
    from weak_queue w
    join problems p on p.chapter = w.chapter and p.idx = w.idx
    where w.student_id = auth.uid()
      and coalesce(w.next_review, current_date) <= current_date
    order by w.next_review nulls first
    limit greatest(1, coalesce(p_count, 5))
  ) t;
$$;

-- ---- start a test ---------------------------------------------------------
-- Creates the test row and hands back its questions. Answers are not in the
-- payload: the client only ever sees prompts, and marking happens server-side.
create or replace function start_exam(
  p_kind text default 'mock',
  p_chapters int[] default null,
  p_count int default 10,
  p_minutes int default 40,
  p_pass int default 70
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
  v_id uuid;
  v_items json;
begin
  if v_student is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  insert into exam_mocks (student_id, kind, scope, total, pass_bar, started_at)
  values (v_student, coalesce(p_kind,'mock'),
          case when p_chapters is null then 'all' else array_to_string(p_chapters, ',') end,
          coalesce(p_count,10), coalesce(p_pass,70), now())
  returning id into v_id;

  select coalesce(json_agg(row_to_json(t) order by t.ord), '[]'::json) into v_items
  from (
    select p.chapter, p.idx, p.prompt, p.difficulty, row_number() over () as ord
    from problems p
    where (p_chapters is null or p.chapter = any(p_chapters))
    order by random()
    limit greatest(1, coalesce(p_count,10))
  ) t;

  update exam_mocks set total = json_array_length(v_items) where id = v_id;

  return json_build_object(
    'exam_id', v_id,
    'minutes', coalesce(p_minutes,40),
    'pass_bar', coalesce(p_pass,70),
    'items', v_items
  );
end $$;

-- ---- what he has done today ----------------------------------------------
create or replace function today_progress()
returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'answered', count(*),
    'correct', count(*) filter (where ok),
    'xp', coalesce(sum(xp),0)
  )
  from attempts
  where student_id = auth.uid()
    and created_at >= (now() at time zone 'Australia/Melbourne')::date;
$$;

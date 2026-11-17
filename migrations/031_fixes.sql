-- ============================================================================
-- 031_fixes.sql
-- Two things the walk-through turned up.
--   1. A chapter he works on never appeared in chapter_progress unless he missed
--      the same question three times, so the map and the dashboard stayed empty.
--   2. A test's total counted only the questions he answered, so a 3-question
--      quiz showed "0 out of 2".
-- Run after 030. Safe to re-run.
-- ============================================================================

create or replace function touch_chapter(p_student uuid, p_chapter int)
returns void
language sql security definer set search_path = public as $$
  insert into chapter_progress (student_id, chapter)
  values (p_student, p_chapter)
  on conflict (student_id, chapter) do nothing;
$$;

create or replace function finish_exam(p_exam_id uuid)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
  v_row exam_mocks;
  v_score int;
  v_total int;
  v_pct int;
  v_items json;
begin
  if v_student is null then raise exception 'not signed in' using errcode = '28000'; end if;

  select * into v_row from exam_mocks where id = p_exam_id and student_id = v_student;
  if not found then raise exception 'no such test for this student'; end if;

  -- the paper's size is how many questions were set, not how many he answered
  select count(*) filter (where ok) into v_score from exam_items where exam_id = p_exam_id;
  select count(*) into v_total from exam_items where exam_id = p_exam_id;
  if coalesce(v_total, 0) = 0 then v_total := coalesce(v_row.total, 0); end if;

  v_pct := case when coalesce(v_total,0) = 0 then 0 else round(100.0 * v_score / v_total) end;

  update exam_mocks
     set score = coalesce(v_score,0),
         total = coalesce(v_total,0),
         pct = v_pct,
         marks = coalesce(v_score,0),
         marks_total = coalesce(v_total,0),
         passed = v_pct >= coalesce(pass_bar, 60),
         submitted_at = coalesce(submitted_at, now())
   where id = p_exam_id;

  select coalesce(json_agg(json_build_object(
           'chapter', i.chapter, 'idx', i.idx, 'ok', i.ok,
           'given', i.answer_given, 'answer', a.answer_key, 'method', a.method) order by i.idx), '[]'::json)
    into v_items
  from exam_items i
  left join problem_answers a on a.chapter = i.chapter and a.idx = i.idx
  where i.exam_id = p_exam_id;

  return json_build_object('score', coalesce(v_score,0), 'total', coalesce(v_total,0),
                           'pct', v_pct, 'passed', v_pct >= coalesce(v_row.pass_bar,60),
                           'items', v_items);
end $$;

-- every attempt now registers the chapter, so the map and dashboard move
create or replace function submit_answer(
  p_chapter int, p_idx int, p_answer text, p_hints int default 0,
  p_working boolean default false, p_mode text default 'quest',
  p_seconds int default null, p_exam_id uuid default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
  v_key text; v_method text; v_correct boolean; v_xp int := 0; v_tier int;
  v_reveal boolean; v_streak int; v_misses int; v_attempt_id bigint;
begin
  if v_student is null then raise exception 'not signed in' using errcode = '28000'; end if;

  select case when coalesce(a.mark_mode,'auto') = 'manual' then null else a.answer_key end,
         a.method, coalesce(c.tier,1)
    into v_key, v_method, v_tier
  from problem_answers a
  join problems p on p.chapter = a.chapter and p.idx = a.idx
  join chapters c on c.n = a.chapter
  where a.chapter = p_chapter and a.idx = p_idx;

  if v_key is not null then
    v_correct := normalize_answer(p_answer) = normalize_answer(v_key);
  end if;

  v_xp := case when v_correct is true then xp_for(v_tier, p_hints, p_working, p_mode) else 0 end;

  insert into attempts (student_id, chapter, idx, ok, hints, working, xp, mode, answer_given, seconds, exam_id)
  values (v_student, p_chapter, p_idx, v_correct, coalesce(p_hints,0), coalesce(p_working,false),
          v_xp, coalesce(p_mode,'quest'), p_answer, p_seconds, p_exam_id)
  returning id into v_attempt_id;

  -- the chapter is now in play
  perform touch_chapter(v_student, p_chapter);

  if v_correct is false then
    insert into weak_queue (student_id, chapter, idx, misses, next_review, correct_streak, technique, last_seen)
    values (v_student, p_chapter, p_idx, 1, current_date + 1, 0,
            (select technique_tags[1] from problems where chapter = p_chapter and idx = p_idx), current_date)
    on conflict (student_id, chapter, idx) do update
      set misses = weak_queue.misses + 1,
          correct_streak = 0,
          last_seen = current_date,
          next_review = current_date + (case when weak_queue.misses + 1 >= 3 then 7
                                             when weak_queue.misses + 1 = 2 then 3 else 1 end);

    select misses into v_misses from weak_queue
      where student_id = v_student and chapter = p_chapter and idx = p_idx;
    if v_misses >= 3 then
      insert into chapter_progress (student_id, chapter, weak) values (v_student, p_chapter, true)
      on conflict (student_id, chapter) do update set weak = true;
    end if;
  elsif v_correct is true then
    select correct_streak into v_streak from weak_queue
      where student_id = v_student and chapter = p_chapter and idx = p_idx;
    if v_streak is not null then
      if v_streak + 1 >= 2 then
        delete from weak_queue where student_id = v_student and chapter = p_chapter and idx = p_idx;
      else
        update weak_queue set correct_streak = v_streak + 1, next_review = current_date + 7
         where student_id = v_student and chapter = p_chapter and idx = p_idx;
      end if;
    end if;
  end if;

  update profiles set xp = coalesce(xp,0) + v_xp, level = 1 + (coalesce(xp,0) + v_xp)/300
   where student_id = v_student;

  v_reveal := (p_exam_id is null)
              or exists (select 1 from exam_mocks e where e.id = p_exam_id and e.submitted_at is not null);

  return json_build_object(
    'attempt_id', v_attempt_id,
    'revealed', v_reveal,
    'correct',   case when v_reveal then v_correct end,
    'needs_manual_mark', case when v_reveal then v_key is null end,
    'xp',        case when v_reveal then v_xp else 0 end,
    'method',    case when v_reveal then v_method end
  );
end $$;

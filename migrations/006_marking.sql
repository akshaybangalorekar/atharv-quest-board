-- ============================================================================
-- 006_marking.sql
-- Marking honours the hand-set keys and the manual-by-design ones.
-- Run after 005. Safe to re-run.
-- ============================================================================

-- ignore punctuation and the words children actually write
create or replace function normalize_answer(t text)
returns text language sql immutable as $$
  select regexp_replace(
           regexp_replace(lower(coalesce(t,'')), '(row|column|col|and|answer|is)', '', 'g'),
           '[^0-9a-z/.]', '', 'g');
$$;

create or replace function submit_answer(
  p_chapter int,
  p_idx int,
  p_answer text,
  p_hints int default 0,
  p_working boolean default false,
  p_mode text default 'quest',
  p_seconds int default null,
  p_exam_id uuid default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
  v_key text;
  v_method text;
  v_tier int;
  v_correct boolean;
  v_xp int := 0;
  v_misses int;
  v_streak int;
  v_reveal boolean;
begin
  if v_student is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  select case when coalesce(a.mark_mode,'auto') = 'manual' then null else a.answer_key end,
         a.method, coalesce(c.tier,1)
    into v_key, v_method, v_tier
  from problem_answers a
  join problems p on p.chapter = a.chapter and p.idx = a.idx
  join chapters c on c.n = p.chapter
  where a.chapter = p_chapter and a.idx = p_idx;

  if not found then
    raise exception 'no such question % %', p_chapter, p_idx;
  end if;

  if v_key is null then
    v_correct := null;                                   -- manual marking
  else
    v_correct := normalize_answer(p_answer) = normalize_answer(v_key);
  end if;

  if v_correct is true then
    v_xp := xp_for(v_tier, p_hints, p_working, p_mode);
  end if;

  insert into attempts (student_id, chapter, idx, ok, hints, working, xp, mode,
                        answer_given, seconds, exam_id, updated_at)
  values (v_student, p_chapter, p_idx, v_correct, coalesce(p_hints,0),
          coalesce(p_working,false), v_xp, coalesce(p_mode,'quest'), p_answer,
          p_seconds, p_exam_id, now());

  if p_exam_id is not null then
    insert into exam_items (exam_id, chapter, idx, answer_given, ok, marks_awarded)
    values (p_exam_id, p_chapter, p_idx, p_answer, v_correct, 0)
    on conflict (exam_id, chapter, idx) do update
      set answer_given = excluded.answer_given, ok = excluded.ok;
  end if;

  if v_correct is false then
    insert into weak_queue (student_id, chapter, idx, misses, next_review, last_seen, technique)
    values (v_student, p_chapter, p_idx, 1, current_date + 1, current_date,
            (select technique_tags[1] from problems where chapter = p_chapter and idx = p_idx))
    on conflict (student_id, chapter, idx) do update
      set misses = weak_queue.misses + 1,
          correct_streak = 0,
          last_seen = current_date,
          next_review = current_date + (case when weak_queue.misses + 1 >= 3 then 7
                                             when weak_queue.misses + 1 = 2 then 3 else 1 end);

    select misses into v_misses from weak_queue
      where student_id = v_student and chapter = p_chapter and idx = p_idx;
    if v_misses >= 3 then
      insert into chapter_progress (student_id, chapter, weak)
      values (v_student, p_chapter, true)
      on conflict (student_id, chapter) do update set weak = true;
    end if;
  elsif v_correct is true then
    select correct_streak into v_streak from weak_queue
      where student_id = v_student and chapter = p_chapter and idx = p_idx;
    if v_streak is not null then
      if v_streak + 1 >= 2 then
        delete from weak_queue where student_id = v_student and chapter = p_chapter and idx = p_idx;
      else
        update weak_queue set correct_streak = v_streak + 1, last_seen = current_date,
                           next_review = current_date + 7
          where student_id = v_student and chapter = p_chapter and idx = p_idx;
      end if;
    end if;
  end if;

  if v_xp > 0 then
    update profiles set xp = coalesce(xp,0) + v_xp, level = 1 + (coalesce(xp,0) + v_xp) / 300
      where student_id = v_student;
  end if;

  -- D7: in a test, nothing is revealed until the test is submitted.
  v_reveal := (p_exam_id is null)
              or exists (select 1 from exam_mocks e
                         where e.id = p_exam_id and e.submitted_at is not null);

  return json_build_object(
    'recorded', true,
    'revealed', v_reveal,
    'correct',   case when v_reveal then v_correct end,
    'needs_manual_mark', case when v_reveal then v_key is null end,
    'xp',        case when v_reveal then v_xp else 0 end,
    'method',    case when v_reveal then v_method end
  );
end $$;

-- Mark one attempt by eye: the 13 manual questions, and any disputed mark.
create or replace function mark_attempt(p_attempt_id bigint, p_ok boolean)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
  v_attempt attempts;
  v_tier int;
  v_xp int;
begin
  select * into v_attempt from attempts where id = p_attempt_id;
  if not found then
    raise exception 'no such attempt';
  end if;
  -- the student, a guardian, or the service role may mark it
  if not (v_attempt.student_id = v_student or is_guardian(v_attempt.student_id) or v_student is null) then
    raise exception 'not your attempt' using errcode = '42501';
  end if;

  select coalesce(tier,1) into v_tier from chapters where n = v_attempt.chapter;
  v_xp := case when p_ok then xp_for(v_tier, v_attempt.hints, v_attempt.working, v_attempt.mode) else 0 end;

  update attempts set ok = p_ok, xp = v_xp where id = p_attempt_id;

  if p_ok then
    delete from weak_queue
     where student_id = v_attempt.student_id and chapter = v_attempt.chapter and idx = v_attempt.idx;
    update profiles set xp = coalesce(xp,0) + v_xp,
                        level = 1 + (coalesce(xp,0) + v_xp) / 300
     where student_id = v_attempt.student_id;
  else
    insert into weak_queue (student_id, chapter, idx, misses, next_review, last_seen)
    values (v_attempt.student_id, v_attempt.chapter, v_attempt.idx, 1, current_date + 1, current_date)
    on conflict (student_id, chapter, idx) do update
      set misses = weak_queue.misses + 1, correct_streak = 0, last_seen = current_date;
  end if;

  return json_build_object('attempt_id', p_attempt_id, 'ok', p_ok, 'xp', v_xp);
end $$;
